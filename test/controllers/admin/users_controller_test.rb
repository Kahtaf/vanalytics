require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:sure_support_staff)
  end

  test "index shows users" do
    get admin_users_url

    assert_response :success
  end

  test "index shows n/a when trial end date is unavailable" do
    get admin_users_url

    assert_response :success
    assert_match(/n\/a/, response.body, "Page should show n/a for users without trial end date")
  end
end
