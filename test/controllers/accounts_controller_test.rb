require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:crypto)
  end

  test "should get index" do
    get accounts_url
    assert_response :success
  end

  test "should get show" do
    get account_url(@account)
    assert_response :success
  end

  test "should sync account" do
    post sync_account_url(@account)
    assert_redirected_to account_url(@account)
  end

  test "should get sparkline" do
    get sparkline_account_url(@account)
    assert_response :success
  end

  test "destroys account" do
    delete account_url(@account)
    assert_redirected_to accounts_path
    assert_enqueued_with job: DestroyJob
    assert_equal "Crypto account scheduled for deletion", flash[:notice]
  end

  test "syncing unlinked account calls account sync_later" do
    Account.any_instance.expects(:syncing?).returns(false)
    Account.any_instance.expects(:sync_later).once

    post sync_account_url(@account)
    assert_redirected_to account_url(@account)
  end

  test "disabling an account keeps it visible on index" do
    @account.disable!

    get accounts_path

    assert_response :success
    assert_includes @response.body, @account.name
    assert_includes @response.body, "account_#{@account.id}_active"
  end

  test "toggle_active disables and re-enables an account" do
    patch toggle_active_account_url(@account)
    assert_redirected_to accounts_path
    @account.reload
    assert @account.disabled?

    patch toggle_active_account_url(@account)
    assert_redirected_to accounts_path
    @account.reload
    assert @account.active?
  end

end
