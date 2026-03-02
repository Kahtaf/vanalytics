require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include SyncableInterfaceTest, EntriesTestHelper, ActiveJob::TestHelper

  setup do
    @account = @syncable = accounts(:crypto)
    @family = families(:dylan_family)
  end

  test "can destroy" do
    assert_difference "Account.count", -1 do
      @account.destroy
    end
  end

  test "create_and_sync calls sync_later by default" do
    Account.any_instance.expects(:sync_later).once

    account = Account.create_and_sync({
      family: @family,
      name: "Test Account",
      balance: 100,
      currency: "USD",
      accountable_type: "Crypto",
      accountable_attributes: {}
    })

    assert account.persisted?
    assert_equal "USD", account.currency
    assert_equal 100, account.balance
  end

  test "create_and_sync skips sync_later when skip_initial_sync is true" do
    Account.any_instance.expects(:sync_later).never

    account = Account.create_and_sync(
      {
        family: @family,
        name: "Linked Account",
        balance: 500,
        currency: "EUR",
        accountable_type: "Crypto",
        accountable_attributes: {}
      },
      skip_initial_sync: true
    )

    assert account.persisted?
    assert_equal "EUR", account.currency
    assert_equal 500, account.balance
  end

  test "create_and_sync creates opening anchor with correct currency" do
    Account.any_instance.stubs(:sync_later)

    account = Account.create_and_sync(
      {
        family: @family,
        name: "Test Account",
        balance: 1000,
        currency: "GBP",
        accountable_type: "Crypto",
        accountable_attributes: {}
      },
      skip_initial_sync: true
    )

    opening_anchor = account.valuations.opening_anchor.first
    assert_not_nil opening_anchor
    assert_equal "GBP", opening_anchor.entry.currency
    assert_equal 1000, opening_anchor.entry.amount
  end

  test "gets short/long subtype label" do
    crypto = Crypto.new(subtype: "wallet")
    account = @family.accounts.create!(
      name: "Test Wallet",
      balance: 1000,
      currency: "USD",
      accountable: crypto
    )

    assert_equal "Wallet", account.short_subtype_label
    assert_equal "Crypto Wallet", account.long_subtype_label

    # Test with nil subtype
    account.accountable.update!(subtype: nil)
    assert_equal "Crypto", account.short_subtype_label
    assert_equal "Crypto", account.long_subtype_label
  end

  # Tax treatment tests (TaxTreatable concern)

  test "tax_treatment delegates to accountable for Crypto" do
    crypto = Crypto.new(tax_treatment: :tax_deferred)
    account = @family.accounts.create!(
      name: "Test Tax Deferred Crypto",
      balance: 500,
      currency: "USD",
      accountable: crypto
    )

    assert_equal :tax_deferred, account.tax_treatment
    assert_equal I18n.t("accounts.tax_treatments.tax_deferred"), account.tax_treatment_label
  end

  test "tax_treatment defaults to taxable for Crypto" do
    crypto = Crypto.new(tax_treatment: :taxable)
    account = @family.accounts.create!(
      name: "Test Taxable Crypto",
      balance: 500,
      currency: "USD",
      accountable: crypto
    )

    assert_equal :taxable, account.tax_treatment
    assert_equal I18n.t("accounts.tax_treatments.taxable"), account.tax_treatment_label
  end

  test "tax_advantaged? returns true for tax-advantaged crypto accounts" do
    crypto = Crypto.new(tax_treatment: :tax_exempt)
    account = @family.accounts.create!(
      name: "Test Tax Exempt",
      balance: 1000,
      currency: "USD",
      accountable: crypto
    )

    assert account.tax_advantaged?
    assert_not account.taxable?
  end

  test "tax_advantaged? returns false for taxable crypto accounts" do
    crypto = Crypto.new(tax_treatment: :taxable)
    account = @family.accounts.create!(
      name: "Test Taxable",
      balance: 1000,
      currency: "USD",
      accountable: crypto
    )

    assert_not account.tax_advantaged?
    assert account.taxable?
  end

  test "destroying account purges attached logo" do
    @account.logo.attach(
      io: StringIO.new("fake-logo-content"),
      filename: "logo.png",
      content_type: "image/png"
    )

    attachment_id = @account.logo.id
    assert ActiveStorage::Attachment.exists?(attachment_id)

    perform_enqueued_jobs do
      @account.destroy!
    end

    assert_not ActiveStorage::Attachment.exists?(attachment_id)
  end
end
