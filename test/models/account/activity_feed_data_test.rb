require "test_helper"

class Account::ActivityFeedDataTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:empty)
    @checking = @family.accounts.create!(name: "Test Checking", accountable: Crypto.new, currency: "USD", balance: 0)
    @investment = @family.accounts.create!(name: "Test Investment", accountable: Crypto.new, currency: "USD", balance: 0)

    @test_period_start = Date.current - 4.days

    setup_test_data
  end

  test "returns balance for date with complete balance history" do
    entries = @checking.entries.includes(:entryable).to_a
    feed_data = Account::ActivityFeedData.new(@checking, entries)

    activities = feed_data.entries_by_date

    # Day 1 has the valuation
    day1_activity = find_activity_for_date(activities, @test_period_start)

    assert_not_nil day1_activity
    assert_not_nil day1_activity.balance
    assert_equal 1000, day1_activity.balance.end_balance
  end

  test "returns nil balance when no balance exists for date" do
    @checking.balances.destroy_all

    entries = @checking.entries.includes(:entryable).to_a
    feed_data = Account::ActivityFeedData.new(@checking, entries)

    activities = feed_data.entries_by_date
    day1_activity = find_activity_for_date(activities, @test_period_start)

    assert_not_nil day1_activity
    assert_nil day1_activity.balance
  end

  test "returns cash and holdings data for investment accounts" do
    entries = @investment.entries.includes(:entryable).to_a
    feed_data = Account::ActivityFeedData.new(@investment, entries)

    activities = feed_data.entries_by_date
    day3_activity = find_activity_for_date(activities, @test_period_start + 2.days)

    assert_not_nil day3_activity
    assert_not_nil day3_activity.balance

    # Balance should have the new schema fields
    assert_equal 400, day3_activity.balance.end_cash_balance
    assert_equal 1500, day3_activity.balance.end_non_cash_balance
    assert_equal 1900, day3_activity.balance.end_balance
  end

  test "returns complete ActivityDateData objects with all required fields" do
    entries = @investment.entries.includes(:entryable).to_a
    feed_data = Account::ActivityFeedData.new(@investment, entries)

    activities = feed_data.entries_by_date

    assert activities.all? { |a| a.is_a?(Account::ActivityFeedData::ActivityDateData) }

    activities.each do |activity|
      assert_respond_to activity, :date
      assert_respond_to activity, :entries
      assert_respond_to activity, :balance
    end
  end

  test "handles valuations correctly with new balance schema" do
    account = @family.accounts.create!(name: "Test Investment", accountable: Crypto.new, currency: "USD", balance: 0)

    account.balances.create!(
      date: @test_period_start,
      balance: 7321.56,
      cash_balance: 1000,
      start_cash_balance: 0,
      start_non_cash_balance: 0,
      cash_inflows: 1000,
      cash_outflows: 0,
      non_cash_inflows: 6321.56,
      non_cash_outflows: 0,
      net_market_flows: 0,
      cash_adjustments: 0,
      non_cash_adjustments: 0,
      currency: "USD"
    )

    account.balances.create!(
      date: @test_period_start + 1.day,
      balance: 8500,
      cash_balance: 1070,
      start_cash_balance: 1000,
      start_non_cash_balance: 6321.56,
      cash_inflows: 70,
      cash_outflows: 0,
      non_cash_inflows: 750,
      non_cash_outflows: 0,
      net_market_flows: 0,
      cash_adjustments: 0,
      non_cash_adjustments: 358.44,
      currency: "USD"
    )

    # Create a trade
    create_trade(
      securities(:aapl),
      account: account,
      qty: 5,
      date: @test_period_start + 1.day,
      price: 150
    )

    # Create valuation
    create_valuation(
      account: account,
      date: @test_period_start + 1.day,
      amount: 8500
    )

    entries = account.entries.includes(:entryable).to_a
    feed_data = Account::ActivityFeedData.new(account, entries)

    activities = feed_data.entries_by_date
    day2_activity = find_activity_for_date(activities, @test_period_start + 1.day)

    assert_not_nil day2_activity
    assert_not_nil day2_activity.balance

    assert_equal 1070, day2_activity.balance.end_cash_balance
    assert_equal 7430, day2_activity.balance.end_non_cash_balance
    assert_equal 8500, day2_activity.balance.end_balance
  end

  private
    def find_activity_for_date(activities, date)
      activities.find { |a| a.date == date }
    end

    def setup_test_data
      # Create daily balances for checking account
      5.times do |i|
        date = @test_period_start + i.days
        prev_balance = i > 0 ? 1000 + ((i - 1) * 100) : 0

        @checking.balances.create!(
          date: date,
          balance: 1000 + (i * 100),
          cash_balance: 1000 + (i * 100),
          start_balance: prev_balance,
          start_cash_balance: prev_balance,
          start_non_cash_balance: 0,
          cash_inflows: i == 0 ? 1000 : 100,
          cash_outflows: 0,
          non_cash_inflows: 0,
          non_cash_outflows: 0,
          net_market_flows: 0,
          cash_adjustments: 0,
          non_cash_adjustments: 0,
          currency: "USD"
        )
      end

      # Create daily balances for investment account
      @investment.balances.create!(
        date: @test_period_start,
        balance: 500,
        cash_balance: 500,
        start_balance: 0,
        start_cash_balance: 0,
        start_non_cash_balance: 0,
        cash_inflows: 500,
        cash_outflows: 0,
        non_cash_inflows: 0,
        non_cash_outflows: 0,
        net_market_flows: 0,
        cash_adjustments: 0,
        non_cash_adjustments: 0,
        currency: "USD"
      )
      @investment.balances.create!(
        date: @test_period_start + 1.day,
        balance: 500,
        cash_balance: 500,
        start_balance: 500,
        start_cash_balance: 500,
        start_non_cash_balance: 0,
        cash_inflows: 0,
        cash_outflows: 0,
        non_cash_inflows: 0,
        non_cash_outflows: 0,
        net_market_flows: 0,
        cash_adjustments: 0,
        non_cash_adjustments: 0,
        currency: "USD"
      )
      @investment.balances.create!(
        date: @test_period_start + 2.days,
        balance: 1900,
        cash_balance: 400,
        start_balance: 500,
        start_cash_balance: 500,
        start_non_cash_balance: 0,
        cash_inflows: 0,
        cash_outflows: 100,
        non_cash_inflows: 1500,
        non_cash_outflows: 0,
        net_market_flows: 0,
        cash_adjustments: 0,
        non_cash_adjustments: 0,
        currency: "USD"
      )

      # Day 1: Valuation for checking account
      create_valuation(
        account: @checking,
        date: @test_period_start,
        amount: 1000
      )

      # Day 3: Trade in investment account
      create_trade(
        securities(:aapl),
        account: @investment,
        qty: 10,
        date: @test_period_start + 2.days,
        price: 150
      )

      # Day 4: Valuation
      create_valuation(
        account: @investment,
        date: @test_period_start + 3.days,
        amount: 25
      )
    end
end
