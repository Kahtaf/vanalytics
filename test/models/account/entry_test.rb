require "test_helper"

class EntryTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @entry = entries :trade
  end

  test "entry cannot be older than 10 years ago" do
    assert_raises ActiveRecord::RecordInvalid do
      @entry.update! date: 50.years.ago.to_date
    end
  end

  test "valuations cannot have more than one entry per day" do
    existing_valuation = entries :valuation

    new_valuation = Entry.new \
      entryable: Valuation.new(kind: "reconciliation"),
      account: existing_valuation.account,
      date: existing_valuation.date, # invalid
      currency: existing_valuation.currency,
      amount: existing_valuation.amount

    assert new_valuation.invalid?
  end

  test "triggers sync with correct start date when entry is set to prior date" do
    prior_date = @entry.date - 1
    @entry.update! date: prior_date

    @entry.account.expects(:sync_later).with(window_start_date: prior_date)
    @entry.sync_account_later
  end

  test "triggers sync with correct start date when entry is set to future date" do
    prior_date = @entry.date
    @entry.update! date: @entry.date + 1

    @entry.account.expects(:sync_later).with(window_start_date: prior_date)
    @entry.sync_account_later
  end

  test "triggers sync with correct start date when entry deleted" do
    @entry.destroy!

    @entry.account.expects(:sync_later).with(window_start_date: nil)
    @entry.sync_account_later
  end

  test "can search entries" do
    family = families(:empty)
    account = family.accounts.create! name: "Test", balance: 0, currency: "USD", accountable: Crypto.new

    create_valuation(account: account, amount: 100, date: 3.days.ago.to_date)
    create_valuation(account: account, amount: 200, date: 2.days.ago.to_date)

    params = { search: "Valuation" }
    assert_equal 2, family.entries.search(params).size

    params = { search: "%" }
    assert_equal 0, family.entries.search(params).size
  end

  test "visible scope only returns entries from visible accounts" do
    visible_entry = create_valuation(account: accounts(:crypto), amount: 100, date: 5.days.ago.to_date)

    visible_entries = Entry.visible
    assert_includes visible_entries, visible_entry
  end
end
