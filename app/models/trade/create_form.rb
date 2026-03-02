class Trade::CreateForm
  include ActiveModel::Model

  attr_accessor :account, :date, :amount, :currency, :qty,
                :price, :ticker, :manual_ticker, :type

  def create
    case type
    when "buy", "sell"
      create_trade
    end
  end

  private
    def security
      ticker_symbol, exchange_operating_mic = ticker.present? ? ticker.split("|") : [ manual_ticker, nil ]

      Security::Resolver.new(
        ticker_symbol,
        exchange_operating_mic: exchange_operating_mic
      ).resolve
    end

    def create_trade
      signed_qty = type == "sell" ? -qty.to_d : qty.to_d
      signed_amount = signed_qty * price.to_d

      trade_entry = account.entries.new(
        name: Trade.build_name(type, qty, security.ticker),
        date: date,
        amount: signed_amount,
        currency: currency,
        entryable: Trade.new(
          qty: signed_qty,
          price: price,
          currency: currency,
          security: security,
          investment_activity_label: type.capitalize
        )
      )

      if trade_entry.save
        trade_entry.lock_saved_attributes!
        account.sync_later
      end

      trade_entry
    end
end
