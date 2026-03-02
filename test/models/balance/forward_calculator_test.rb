require "test_helper"

# The "forward calculator" is used for all **manual** accounts where balance tracking is done through entries and NOT from an external data provider.
class Balance::ForwardCalculatorTest < ActiveSupport::TestCase
  include LedgerTestingHelper

  # ------------------------------------------------------------------------------------------------
  # General tests for all account types
  # ------------------------------------------------------------------------------------------------

  # When syncing forwards, we don't care about the account balance.  We generate everything based on entries, starting from 0.
  test "no entries sync" do
    account = create_account_with_ledger(
      account: { type: Crypto, currency: "USD" },
      entries: []
    )

    assert_equal 0, account.balances.count

    calculated = Balance::ForwardCalculator.new(account).calculate

    assert_calculated_ledger_balances(
      calculated_data: calculated,
      expected_data: [
        {
          date: Date.current,
          legacy_balances: { balance: 0, cash_balance: 0 },
          balances: { start: 0, start_cash: 0, start_non_cash: 0, end_cash: 0, end_non_cash: 0, end: 0 },
          flows: 0,
          adjustments: 0
        }
      ]
    )
  end

  test "cash-only accounts use valuations where cash balance equals total balance" do
    [ Crypto, Crypto ].each do |account_type|
      account = create_account_with_ledger(
        account: { type: account_type, currency: "USD" },
        entries: [
          { type: "opening_anchor", date: 3.days.ago.to_date, balance: 17000 },
          { type: "reconciliation", date: 2.days.ago.to_date, balance: 18000 }
        ]
      )

      calculated = Balance::ForwardCalculator.new(account).calculate

      assert_calculated_ledger_balances(
        calculated_data: calculated,
        expected_data: [
          {
            date: 3.days.ago.to_date,
            legacy_balances: { balance: 17000, cash_balance: 17000 },
            balances: { start: 17000, start_cash: 17000, start_non_cash: 0, end_cash: 17000, end_non_cash: 0, end: 17000 },
            flows: 0,
            adjustments: 0
          },
          {
            date: 2.days.ago.to_date,
            legacy_balances: { balance: 18000, cash_balance: 18000 },
            balances: { start: 17000, start_cash: 17000, start_non_cash: 0, end_cash: 18000, end_non_cash: 0, end: 18000 },
            flows: 0,
            adjustments: { cash_adjustments: 1000, non_cash_adjustments: 0 }
          }
        ]
      )
    end
  end

  test "non-cash accounts use valuations where cash balance is always zero" do
    [ Crypto, Crypto ].each do |account_type|
      account = create_account_with_ledger(
        account: { type: account_type, currency: "USD" },
        entries: [
          { type: "opening_anchor", date: 3.days.ago.to_date, balance: 17000 },
          { type: "reconciliation", date: 2.days.ago.to_date, balance: 18000 }
        ]
      )

      calculated = Balance::ForwardCalculator.new(account).calculate

      assert_calculated_ledger_balances(
        calculated_data: calculated,
        expected_data: [
          {
            date: 3.days.ago.to_date,
            legacy_balances: { balance: 17000, cash_balance: 0.0 },
            balances: { start: 17000, start_cash: 0, start_non_cash: 17000, end_cash: 0, end_non_cash: 17000, end: 17000 },
            flows: 0,
            adjustments: 0
          },
          {
            date: 2.days.ago.to_date,
            legacy_balances: { balance: 18000, cash_balance: 0.0 },
            balances: { start: 17000, start_cash: 0, start_non_cash: 17000, end_cash: 0, end_non_cash: 18000, end: 18000 },
            flows: 0,
            adjustments: { cash_adjustments: 0, non_cash_adjustments: 1000 }
          }
        ]
      )
    end
  end

  test "mixed accounts use valuations where cash balance is total minus holdings" do
    account = create_account_with_ledger(
      account: { type: Crypto, currency: "USD" },
      entries: [
        { type: "opening_anchor", date: 3.days.ago.to_date, balance: 17000 },
        { type: "reconciliation", date: 2.days.ago.to_date, balance: 18000 }
      ]
    )

    # Without holdings, cash balance equals total balance
    calculated = Balance::ForwardCalculator.new(account).calculate

    assert_calculated_ledger_balances(
      calculated_data: calculated,
      expected_data: [
        {
          date: 3.days.ago.to_date,
          legacy_balances: { balance: 17000, cash_balance: 17000 },
          balances: { start: 17000, start_cash: 17000, start_non_cash: 0, end_cash: 17000, end_non_cash: 0, end: 17000 },
          flows: { market_flows: 0 },
          adjustments: 0
        },
        {
          date: 2.days.ago.to_date,
          legacy_balances: { balance: 18000, cash_balance: 18000 },
          balances: { start: 17000, start_cash: 17000, start_non_cash: 0, end_cash: 18000, end_non_cash: 0, end: 18000 },
          flows: { market_flows: 0 },
          adjustments: { cash_adjustments: 1000, non_cash_adjustments: 0 } # Since no holdings present, adjustment is all cash
        }
      ]
    )
  end

  # ------------------------------------------------------------------------------------------------
  # Hybrid accounts (Crypto) - these have both cash and non-cash balance components
  # ------------------------------------------------------------------------------------------------

  test "investment account calculates balance from trades and treats holdings as non-cash, additive to balance" do
    account = create_account_with_ledger(
      account: { type: Crypto, currency: "USD" },
      entries: [
        # Account starts with brokerage cash of $5000 and no holdings
        { type: "opening_anchor", date: 3.days.ago.to_date, balance: 5000 },
        # Share purchase reduces cash balance by $1000, but keeps overall balance same
        { type: "trade", date: 1.day.ago.to_date, ticker: "AAPL", qty: 10, price: 100 }
      ],
      holdings: [
        # Holdings calculator will calculate $1000 worth of holdings
        { date: 1.day.ago.to_date, ticker: "AAPL", qty: 10, price: 100, amount: 1000 },
        { date: Date.current, ticker: "AAPL", qty: 10, price: 110, amount: 1100 } # Price increased by 10%, so holdings value goes up by $100 without a trade
      ]
    )

    # Given constant prices, overall balance (account value) should be constant
    # (the single trade doesn't affect balance; it just alters cash vs. holdings composition)
    calculated = Balance::ForwardCalculator.new(account).calculate

    assert_calculated_ledger_balances(
      calculated_data: calculated,
      expected_data: [
        {
          date: 3.days.ago.to_date,
          legacy_balances: { balance: 5000, cash_balance: 5000 },
          balances: { start: 5000, start_cash: 5000, start_non_cash: 0, end_cash: 5000, end_non_cash: 0, end: 5000 },
          flows: 0,
          adjustments: 0
        },
        {
          date: 2.days.ago.to_date,
          legacy_balances: { balance: 5000, cash_balance: 5000 },
          balances: { start: 5000, start_cash: 5000, start_non_cash: 0, end_cash: 5000, end_non_cash: 0, end: 5000 },
          flows: 0,
          adjustments: 0
        },
        {
          date: 1.day.ago.to_date,
          legacy_balances: { balance: 5000, cash_balance: 4000 },
          balances: { start: 5000, start_cash: 5000, start_non_cash: 0, end_cash: 4000, end_non_cash: 1000, end: 5000 },
          flows: { cash_inflows: 0, cash_outflows: 1000, non_cash_inflows: 1000, non_cash_outflows: 0, net_market_flows: 0 }, # Decrease cash by 1000, increase holdings by 1000 (i.e. "buy" of $1000 worth of AAPL)
          adjustments: 0
        },
        {
          date: Date.current,
          legacy_balances: { balance: 5100, cash_balance: 4000 },
          balances: { start: 5000, start_cash: 4000, start_non_cash: 1000, end_cash: 4000, end_non_cash: 1100, end: 5100 },
          flows: { net_market_flows: 100 }, # Holdings value increased by 100, despite no change in portfolio quantities
          adjustments: 0
        }
      ]
    )
  end

  test "investment account can have valuations that override balance" do
    account = create_account_with_ledger(
      account: { type: Crypto, currency: "USD" },
      entries: [
        { type: "opening_anchor", date: 2.days.ago.to_date, balance: 5000 },
        { type: "reconciliation", date: 1.day.ago.to_date, balance: 10000 }
      ],
      holdings: [
        { date: 3.days.ago.to_date, ticker: "AAPL", qty: 10, price: 100, amount: 1000 },
        { date: 2.days.ago.to_date, ticker: "AAPL", qty: 10, price: 100, amount: 1000 },
        { date: 1.day.ago.to_date, ticker: "AAPL", qty: 10, price: 110, amount: 1100 },
        { date: Date.current, ticker: "AAPL", qty: 10, price: 120, amount: 1200 }
      ]
    )

    calculated = Balance::ForwardCalculator.new(account).calculate

    assert_calculated_ledger_balances(
      calculated_data: calculated,
      expected_data: [
        {
          date: 2.days.ago.to_date,
          legacy_balances: { balance: 5000, cash_balance: 4000 },
          balances: { start: 5000, start_cash: 4000, start_non_cash: 1000, end_cash: 4000, end_non_cash: 1000, end: 5000 },
          flows: 0,
          adjustments: 0
        },
        {
          date: 1.day.ago.to_date,
          legacy_balances: { balance: 10000, cash_balance: 8900 },
          balances: { start: 5000, start_cash: 4000, start_non_cash: 1000, end_cash: 8900, end_non_cash: 1100, end: 10000 },
          flows: { net_market_flows: 100 },
          adjustments: { cash_adjustments: 4900, non_cash_adjustments: 0 }
        },
        {
          date: Date.current,
          legacy_balances: { balance: 10100, cash_balance: 8900 },
          balances: { start: 10000, start_cash: 8900, start_non_cash: 1100, end_cash: 8900, end_non_cash: 1200, end: 10100 },
          flows: { net_market_flows: 100 },
          adjustments: 0
        }
      ]
    )
  end

  private
    def assert_balances(calculated_data:, expected_balances:)
      # Sort calculated data by date to ensure consistent ordering
      sorted_data = calculated_data.sort_by(&:date)

      # Extract actual values as [date, { balance:, cash_balance: }]
      actual_balances = sorted_data.map do |b|
        [ b.date, { balance: b.balance, cash_balance: b.cash_balance } ]
      end

      assert_equal expected_balances, actual_balances
    end
end
