class Entry < ApplicationRecord
  include Monetizable, Enrichable

  monetize :amount

  belongs_to :account

  delegated_type :entryable, types: Entryable::TYPES, dependent: :destroy
  accepts_nested_attributes_for :entryable

  validates :date, :name, :amount, :currency, presence: true
  validates :date, uniqueness: { scope: [ :account_id, :entryable_type ] }, if: -> { valuation? }
  validates :date, comparison: { greater_than: -> { min_supported_date } }
  validates :external_id, uniqueness: { scope: [ :account_id, :source ] }, if: -> { external_id.present? && source.present? }

  scope :visible, -> {
    joins(:account).where(accounts: { status: [ "draft", "active" ] })
  }

  scope :chronological, -> {
    order(
      date: :asc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Valuation' THEN 1 ELSE 0 END") => :asc,
      created_at: :asc
    )
  }

  scope :reverse_chronological, -> {
    order(
      date: :desc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Valuation' THEN 1 ELSE 0 END") => :desc,
      created_at: :desc
    )
  }

  # Family-scoped query for Enrichable#clear_ai_cache
  def self.family_scope(family)
    joins(:account).where(accounts: { family_id: family.id })
  end

  def classification
    amount.negative? ? "income" : "expense"
  end

  def lock_saved_attributes!
    super
    entryable.lock_saved_attributes!
  end

  def sync_account_later
    sync_start_date = [ date_previously_was, date ].compact.min unless destroyed?
    account.sync_later(window_start_date: sync_start_date)
  end

  def entryable_name_short
    entryable_type.demodulize.underscore
  end

  def balance_trend(entries, balances)
    Balance::TrendCalculator.new(self, entries, balances).trend
  end

  def linked?
    external_id.present?
  end

  def protected_from_sync?
    excluded? || user_modified?
  end

  def mark_user_modified!
    return true if user_modified?
    update!(user_modified: true)
  end

  def protection_reason
    return :excluded if excluded?
    return :user_modified if user_modified?
    nil
  end

  def locked_field_names
    entry_keys = locked_attributes&.keys || []
    entryable_keys = entryable&.locked_attributes&.keys || []
    (entry_keys + entryable_keys).uniq
  end

  def locked_fields_with_timestamps
    combined = (locked_attributes || {}).merge(entryable&.locked_attributes || {})
    combined.transform_values do |timestamp|
      Time.zone.parse(timestamp.to_s) rescue timestamp
    end
  end

  def unlock_for_sync!
    self.class.transaction do
      update!(user_modified: false, locked_attributes: {})
      entryable&.update!(locked_attributes: {})
    end
  end

  class << self
    def search(params)
      query = all.joins(:account)
      query = apply_search_filter(query, params[:search])
      query = apply_date_filters(query, params[:start_date], params[:end_date])
      query = apply_amount_filter(query, params[:amount], params[:amount_operator])
      query = apply_accounts_filter(query, params[:accounts], params[:account_ids])
      query
    end

    # arbitrary cutoff date to avoid expensive sync operations
    def min_supported_date
      30.years.ago.to_date
    end

    def bulk_update!(bulk_update_params, update_tags: false)
      bulk_attributes = {
        date: bulk_update_params[:date],
        notes: bulk_update_params[:notes]
      }.compact_blank

      return 0 unless bulk_attributes.present?

      transaction do
        all.each do |entry|
          entry.update! bulk_attributes
          entry.lock_saved_attributes!
          entry.mark_user_modified!
        end
      end

      all.size
    end

    private

    def apply_search_filter(scope, search)
      return scope if search.blank?

      scope.where("entries.name ILIKE :search OR entries.notes ILIKE :search",
        search: "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
      )
    end

    def apply_date_filters(scope, start_date, end_date)
      return scope if start_date.blank? && end_date.blank?

      scope = scope.where("entries.date >= ?", start_date) if start_date.present?
      scope = scope.where("entries.date <= ?", end_date) if end_date.present?
      scope
    end

    def apply_amount_filter(scope, amount, amount_operator)
      return scope if amount.blank? || amount_operator.blank?

      case amount_operator
      when "equal"
        scope.where("ABS(ABS(entries.amount) - ?) <= 0.01", amount.to_f.abs)
      when "less"
        scope.where("ABS(entries.amount) < ?", amount.to_f.abs)
      when "greater"
        scope.where("ABS(entries.amount) > ?", amount.to_f.abs)
      else
        scope
      end
    end

    def apply_accounts_filter(scope, accounts, account_ids)
      return scope if accounts.blank? && account_ids.blank?

      scope = scope.where(accounts: { name: accounts }) if accounts.present?
      scope = scope.where(accounts: { id: account_ids }) if account_ids.present?
      scope
    end
  end
end
