module EntriesTestHelper
  def create_valuation(attributes = {})
    entry_attributes = attributes.except(:kind)
    valuation_attributes = attributes.slice(:kind)

    account = attributes[:account] || accounts(:crypto)
    amount = attributes[:amount] || 5000

    entry_defaults = {
      account: account,
      name: "Valuation",
      date: 1.day.ago.to_date,
      currency: "USD",
      amount: amount,
      entryable: Valuation.new({ kind: "reconciliation" }.merge(valuation_attributes))
    }

    Entry.create! entry_defaults.merge(entry_attributes)
  end

  def create_trade(security, account:, qty:, date:, price: nil, currency: "USD")
    trade_price = price || Security::Price.find_by!(security: security, date: date).price

    trade = Trade.new \
      qty: qty,
      security: security,
      price: trade_price,
      currency: currency,
      investment_activity_label: qty > 0 ? "Buy" : "Sell"

    account.entries.create! \
      name: "Trade",
      date: date,
      amount: qty * trade_price,
      currency: currency,
      entryable: trade
  end
end
