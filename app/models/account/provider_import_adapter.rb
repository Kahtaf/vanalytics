class Account::ProviderImportAdapter
  attr_reader :account, :skipped_entries

  def initialize(account)
    @account = account
    @skipped_entries = []
  end

  def reset_skipped_entries!
    @skipped_entries = []
  end

  def update_balance(balance:, cash_balance: nil, source: nil)
    account.update!(
      balance: balance,
      cash_balance: cash_balance || balance
    )
  end

  def import_holding(security:, quantity:, amount:, currency:, date:, price: nil, cost_basis: nil, external_id: nil, source:, account_provider_id: nil, delete_future_holdings: false)
    raise ArgumentError, "security is required" if security.nil?
    raise ArgumentError, "source is required" if source.blank?

    Account.transaction do
      holding = nil

      if external_id.present?
        holding = account.holdings.find_by(external_id: external_id)

        unless holding
          fallback_1a_attrs = {
            provider_security: security,
            date: date,
            currency: currency
          }
          fallback_1a_attrs[:account_provider_id] = account_provider_id if account_provider_id.present?
          holding = account.holdings.find_by(fallback_1a_attrs)

          unless holding || security.ticker.blank?
            scope = account.holdings
              .joins("INNER JOIN securities AS ps ON ps.id = holdings.provider_security_id")
              .where(date: date, currency: currency)
              .where("ps.ticker = ?", security.ticker)
            scope = scope.where(account_provider_id: account_provider_id) if account_provider_id.present?
            holding = scope.first
          end

          unless holding
            find_by_attrs = {
              security: security,
              date: date,
              currency: currency
            }
            if account_provider_id.present?
              find_by_attrs[:account_provider_id] = account_provider_id
            end

            holding = account.holdings.find_by(find_by_attrs)
          end
        end

        holding ||= account.holdings.new(
          security: security,
          date: date,
          currency: currency,
          account_provider_id: account_provider_id
        )
      else
        holding = account.holdings.find_or_initialize_by(
          security: security,
          date: date,
          currency: currency
        )
      end

      if external_id.present?
        existing_composite = account.holdings.find_by(
          security: security,
          date: date,
          currency: currency
        )

        if existing_composite &&
           account_provider_id.present? &&
           existing_composite.account_provider_id.present? &&
           existing_composite.account_provider_id != account_provider_id
          Rails.logger.warn(
            "ProviderImportAdapter: cross-provider holding collision for account=#{account.id} security=#{security.id} date=#{date} currency=#{currency}; returning existing id=#{existing_composite.id}"
          )
          return existing_composite
        end
      end

      reconciled = Holding::CostBasisReconciler.reconcile(
        existing_holding: holding.persisted? ? holding : nil,
        incoming_cost_basis: cost_basis,
        incoming_source: "provider"
      )

      attributes = {
        date: date,
        currency: currency,
        qty: quantity,
        price: price,
        amount: amount,
        account_provider_id: account_provider_id,
        external_id: external_id
      }

      if holding.new_record? || holding.security_replaceable_by_provider?
        attributes[:security] = security
        attributes[:provider_security_id] = security.id if holding.provider_security_id.blank?
      end

      if reconciled[:should_update]
        attributes[:cost_basis] = reconciled[:cost_basis]
        attributes[:cost_basis_source] = reconciled[:cost_basis_source]
      end

      holding.assign_attributes(attributes)

      begin
        Holding.transaction(requires_new: true) do
          holding.save!
        end
      rescue ActiveRecord::RecordNotUnique => e
        existing = account.holdings.find_by(
          security: security,
          date: date,
          currency: currency
        )

        if existing
          if account_provider_id.present? && existing.account_provider_id.present? && existing.account_provider_id != account_provider_id
            Rails.logger.warn(
              "ProviderImportAdapter: cross-provider holding collision for account=#{account.id} security=#{security.id} date=#{date} currency=#{currency}; returning existing id=#{existing.id}"
            )
            holding = existing
          else
            updates = {
              qty: quantity,
              price: price,
              amount: amount
            }

            collision_reconciled = Holding::CostBasisReconciler.reconcile(
              existing_holding: existing,
              incoming_cost_basis: cost_basis,
              incoming_source: "provider"
            )

            if collision_reconciled[:should_update]
              updates[:cost_basis] = collision_reconciled[:cost_basis]
              updates[:cost_basis_source] = collision_reconciled[:cost_basis_source]
            end

            if account_provider_id.present? && existing.account_provider_id.nil?
              updates[:account_provider_id] = account_provider_id
            end

            if external_id.present? && existing.external_id.blank?
              updates[:external_id] = external_id
            end

            begin
              existing.update_columns(updates.compact)
            rescue => _
            end

            holding = existing
          end
        else
          raise e
        end
      end

      if delete_future_holdings
        unless account.can_delete_holdings?
          Rails.logger.warn(
            "Skipping future holdings deletion for account #{account.id} " \
            "because not all providers allow deletion"
          )
          return holding
        end

        future_holdings_query = account.holdings
          .where(security: security)
          .where("date > ?", date)

        if account_provider_id.present?
          future_holdings_query = future_holdings_query.where(account_provider_id: account_provider_id)
        end

        future_holdings_query.destroy_all
      end

      holding
    end
  end

  def import_trade(security:, quantity:, price:, amount:, currency:, date:, name: nil, external_id: nil, source:, activity_label: nil)
    raise ArgumentError, "security is required" if security.nil?
    raise ArgumentError, "source is required" if source.blank?

    Account.transaction do
      trade_name = if name.present?
        name
      else
        trade_type = quantity.negative? ? "sell" : "buy"
        Trade.build_name(trade_type, quantity, security.ticker)
      end

      entry = if external_id.present?
        account.entries.find_or_initialize_by(external_id: external_id, source: source) do |e|
          e.entryable = Trade.new
        end
      else
        account.entries.new(
          entryable: Trade.new,
          source: source
        )
      end

      if entry.persisted? && !entry.entryable.is_a?(Trade)
        raise ArgumentError, "Entry with external_id '#{external_id}' already exists with different entryable type: #{entry.entryable_type}"
      end

      entry.entryable.assign_attributes(
        security: security,
        qty: quantity,
        price: price,
        currency: currency,
        investment_activity_label: activity_label || (quantity > 0 ? "Buy" : "Sell")
      )

      entry.assign_attributes(
        date: date,
        amount: amount,
        currency: currency,
        name: trade_name
      )

      entry.save!
      entry
    end
  end

  def update_accountable_attributes(attributes:, source:)
    return false unless account.accountable.present?
    return false if attributes.blank?

    valid_attributes = attributes.compact.select do |key, _|
      account.accountable.respond_to?("#{key}=")
    end

    return false if valid_attributes.empty?

    account.accountable.update!(valid_attributes)
    true
  rescue => e
    Rails.logger.error("Failed to update #{account.accountable_type} attributes from #{source}: #{e.message}")
    false
  end

  def determine_skip_reason(entry)
    return "excluded" if entry.excluded?
    return "user_modified" if entry.user_modified?
    nil
  end

  def record_skip(entry, reason)
    @skipped_entries << {
      id: entry.id,
      name: entry.name,
      reason: reason,
      external_id: entry.external_id,
      account_name: entry.account.name
    }
  end
end
