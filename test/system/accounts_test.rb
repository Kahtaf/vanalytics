require "application_system_test_case"

class AccountsTest < ApplicationSystemTestCase
  setup do
    sign_in @user = users(:family_admin)

    Family.any_instance.stubs(:get_link_token).returns("test-link-token")

    visit root_url
    open_new_account_modal
  end

  test "can create crypto account" do
    assert_account_created("Crypto")
  end

  private

    def open_new_account_modal
      within "[data-controller='DS--tabs']" do
        click_button "All"
        click_link "New account"
      end
    end

    def assert_account_created(accountable_type, &block)
      click_link Accountable.from_type(accountable_type).display_name.singularize
      click_link "Enter account balance" if accountable_type == "Crypto"

      account_name = "[system test] #{accountable_type} Account"
      institution_name = "[system test] Institution"
      institution_domain = "example.com"
      notes = "Test notes for #{accountable_type}"

      fill_in "Account name*", with: account_name
      fill_in "account[balance]", with: 100.99
      find("summary", text: "Additional details").click
      fill_in "Institution name", with: institution_name
      fill_in "Institution domain", with: institution_domain
      fill_in "Notes", with: notes

      yield if block_given?

      click_button "Create Account"

      within_testid("account-sidebar-tabs") do
        click_on "All"
        find("details", text: Accountable.from_type(accountable_type).display_name).click
        assert_text account_name
      end

      visit accounts_url
      assert_text account_name

      created_account = Account.order(:created_at).last
      assert_equal institution_name, created_account[:institution_name]
      assert_equal institution_domain, created_account[:institution_domain]
      assert_equal notes, created_account[:notes]

      visit account_url(created_account)

      within_testid("account-menu") do
        find("button").click
        click_on "Edit"
      end

      updated_institution_name = "[system test] Updated Institution"
      updated_institution_domain = "updated.example.com"
      updated_notes = "Updated notes for #{accountable_type}"

      fill_in "Account name", with: "Updated account name"
      find("summary", text: "Additional details").click
      fill_in "Institution name", with: updated_institution_name
      fill_in "Institution domain", with: updated_institution_domain
      fill_in "Notes", with: updated_notes
      click_button "Update Account"
      assert_selector "h2", text: "Updated account name"

      created_account.reload
      assert_equal updated_institution_name, created_account[:institution_name]
      assert_equal updated_institution_domain, created_account[:institution_domain]
      assert_equal updated_notes, created_account[:notes]
    end

    def humanized_accountable(accountable_type)
      Accountable.from_type(accountable_type).display_name.singularize
    end
end
