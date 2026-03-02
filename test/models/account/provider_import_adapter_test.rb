require "test_helper"

class Account::ProviderImportAdapterTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:crypto)
    @adapter = Account::ProviderImportAdapter.new(@account)
    @family = families(:dylan_family)
  end

  test "updates account balance" do
    @adapter.update_balance(
      balance: 5000.00,
      cash_balance: 4500.00,
      source: "plaid"
    )

    @account.reload
    assert_equal 5000.00, @account.balance
    assert_equal 4500.00, @account.cash_balance
  end

  test "updates account balance without cash_balance" do
    @adapter.update_balance(
      balance: 3000.00,
      source: "simplefin"
    )

    @account.reload
    assert_equal 3000.00, @account.balance
    assert_equal 3000.00, @account.cash_balance
  end

  test "imports holding with all parameters" do
    investment_account = accounts(:crypto)
    adapter = Account::ProviderImportAdapter.new(investment_account)
    security = securities(:aapl)

    holding_date = Date.today - 2.days

    assert_difference "investment_account.holdings.count", 1 do
      holding = adapter.import_holding(
        security: security,
        quantity: 10.5,
        amount: 1575.00,
        currency: "USD",
        date: holding_date,
        price: 150.00,
        source: "plaid"
      )

      assert_equal security.id, holding.security_id
      assert_equal 10.5, holding.qty
      assert_equal 1575.00, holding.amount
      assert_equal 150.00, holding.price
      assert_equal holding_date, holding.date
    end
  end

  test "raises error when security is missing for holding import" do
    exception = assert_raises(ArgumentError) do
      @adapter.import_holding(
        security: nil,
        quantity: 10,
        amount: 1000,
        currency: "USD",
        date: Date.today,
        source: "plaid"
      )
    end

    assert_equal "security is required", exception.message
  end

  test "imports trade with all parameters" do
    investment_account = accounts(:crypto)
    adapter = Account::ProviderImportAdapter.new(investment_account)
    security = securities(:aapl)

    assert_difference "investment_account.entries.count", 1 do
      entry = adapter.import_trade(
        security: security,
        quantity: 5,
        price: 150.00,
        amount: 750.00,
        currency: "USD",
        date: Date.today,
        source: "plaid"
      )

      assert_kind_of Trade, entry.entryable
      assert_equal 5, entry.entryable.qty
      assert_equal 150.00, entry.entryable.price
      assert_equal 750.00, entry.amount
      assert_match(/Buy.*5.*shares/i, entry.name)
    end
  end

  test "raises error when security is missing for trade import" do
    exception = assert_raises(ArgumentError) do
      @adapter.import_trade(
        security: nil,
        quantity: 5,
        price: 100,
        amount: 500,
        currency: "USD",
        date: Date.today,
        source: "plaid"
      )
    end

    assert_equal "security is required", exception.message
  end

  test "stores account_provider_id when importing holding" do
    investment_account = accounts(:crypto)
    adapter = Account::ProviderImportAdapter.new(investment_account)
    security = securities(:aapl)
    account_provider = AccountProvider.create!(
      account: investment_account,
      provider: plaid_accounts(:one)
    )

    holding = adapter.import_holding(
      security: security,
      quantity: 10,
      amount: 1500,
      currency: "USD",
      date: Date.today - 10.days,
      price: 150,
      source: "plaid",
      account_provider_id: account_provider.id
    )

    assert_equal account_provider.id, holding.account_provider_id
  end

  test "does not delete future holdings when can_delete_holdings? returns false" do
    investment_account = accounts(:crypto)
    adapter = Account::ProviderImportAdapter.new(investment_account)
    security = securities(:aapl)

    future_holding = investment_account.holdings.create!(
      security: security,
      qty: 5,
      amount: 750,
      currency: "USD",
      date: Date.today + 30.days,
      price: 150
    )

    investment_account.expects(:can_delete_holdings?).returns(false)

    adapter.import_holding(
      security: security,
      quantity: 10,
      amount: 1500,
      currency: "USD",
      date: Date.today,
      price: 150,
      source: "plaid",
      delete_future_holdings: true
    )

    assert Holding.exists?(future_holding.id)
  end

  test "deletes all future holdings when account_provider_id is not provided and can_delete_holdings? returns true" do
    investment_account = accounts(:crypto)
    adapter = Account::ProviderImportAdapter.new(investment_account)
    security = securities(:aapl)

    future_holding_1 = investment_account.holdings.create!(
      security: security,
      qty: 5,
      amount: 750,
      currency: "USD",
      date: Date.today + 121.days,
      price: 150
    )

    future_holding_2 = investment_account.holdings.create!(
      security: security,
      qty: 3,
      amount: 450,
      currency: "USD",
      date: Date.today + 2.days,
      price: 150
    )

    investment_account.expects(:can_delete_holdings?).returns(true)

    adapter.import_holding(
      security: security,
      quantity: 10,
      amount: 1500,
      currency: "USD",
      date: Date.today,
      price: 150,
      source: "plaid",
      delete_future_holdings: true
    )

    assert_not Holding.exists?(future_holding_1.id)
    assert_not Holding.exists?(future_holding_2.id)
  end

  test "updates existing trade attributes instead of keeping stale data" do
    investment_account = accounts(:crypto)
    adapter = Account::ProviderImportAdapter.new(investment_account)
    aapl = securities(:aapl)
    msft = securities(:msft)

    entry = adapter.import_trade(
      external_id: "plaid_trade_123",
      security: aapl,
      quantity: 5,
      price: 150.00,
      amount: 750.00,
      currency: "USD",
      date: Date.today,
      source: "plaid"
    )

    assert_no_difference "investment_account.entries.count" do
      updated_entry = adapter.import_trade(
        external_id: "plaid_trade_123",
        security: msft,
        quantity: 10,
        price: 200.00,
        amount: 2000.00,
        currency: "USD",
        date: Date.today,
        source: "plaid"
      )

      assert_equal entry.id, updated_entry.id
      assert_equal msft.id, updated_entry.entryable.security_id
      assert_equal 10, updated_entry.entryable.qty
      assert_equal 200.00, updated_entry.entryable.price
      assert_equal "USD", updated_entry.entryable.currency
      assert_equal 2000.00, updated_entry.amount
    end
  end
end
