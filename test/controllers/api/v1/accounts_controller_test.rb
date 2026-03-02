# frozen_string_literal: true

require "test_helper"

class Api::V1::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @other_family_user = users(:family_member)
    @other_family_user.update!(family: families(:empty))

    @user.api_keys.destroy_all
    @plain_api_key = "accounts_test_#{SecureRandom.hex(8)}"
    @api_key = ApiKey.create!(
      user: @user,
      name: "Test API Key",
      display_key: @plain_api_key,
      scopes: [ "read" ]
    )
  end

  test "should require authentication" do
    get "/api/v1/accounts"
    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
  end

  test "should return user's family accounts successfully" do
    get "/api/v1/accounts", headers: api_headers

    assert_response :success
    response_body = JSON.parse(response.body)

    assert response_body.key?("accounts")
    assert response_body["accounts"].is_a?(Array)

    assert response_body.key?("pagination")
    assert response_body["pagination"].key?("page")
    assert response_body["pagination"].key?("per_page")
    assert response_body["pagination"].key?("total_count")
    assert response_body["pagination"].key?("total_pages")

    response_body["accounts"].each do |account|
      family_account_names = @user.family.accounts.pluck(:name)
      assert_includes family_account_names, account["name"]
    end
  end

  test "should only return active accounts" do
    inactive_account = accounts(:crypto)
    inactive_account.disable!

    get "/api/v1/accounts", headers: api_headers

    assert_response :success
    response_body = JSON.parse(response.body)

    account_names = response_body["accounts"].map { |a| a["name"] }
    assert_not_includes account_names, inactive_account.name
  end

  test "should not return other family's accounts" do
    other_api_key = ApiKey.create!(
      user: @other_family_user,
      name: "Other User API Key",
      display_key: "other_acct_#{SecureRandom.hex(8)}",
      scopes: [ "read" ]
    )

    get "/api/v1/accounts", headers: { "X-Api-Key" => other_api_key.display_key }

    assert_response :success
    response_body = JSON.parse(response.body)

    assert_equal [], response_body["accounts"]
    assert_equal 0, response_body["pagination"]["total_count"]
  end

  test "should handle pagination parameters" do
    get "/api/v1/accounts", params: { page: 1, per_page: 2 }, headers: api_headers

    assert_response :success
    response_body = JSON.parse(response.body)

    assert response_body["accounts"].length <= 2
    assert_equal 1, response_body["pagination"]["page"]
    assert_equal 2, response_body["pagination"]["per_page"]
  end

  test "should return proper account data structure" do
    get "/api/v1/accounts", headers: api_headers

    assert_response :success
    response_body = JSON.parse(response.body)

    assert response_body["accounts"].length > 0

    account = response_body["accounts"].first

    required_fields = %w[id name balance currency classification account_type]
    required_fields.each do |field|
      assert account.key?(field), "Account should have #{field} field"
    end

    assert account["id"].is_a?(String), "ID should be string (UUID)"
    assert account["name"].is_a?(String), "Name should be string"
    assert account["balance"].is_a?(String), "Balance should be string (money)"
    assert account["currency"].is_a?(String), "Currency should be string"
    assert %w[asset liability].include?(account["classification"]), "Classification should be asset or liability"
  end

  test "should handle invalid pagination parameters gracefully" do
    get "/api/v1/accounts", params: { page: -1, per_page: "invalid" }, headers: api_headers

    assert_response :success
    response_body = JSON.parse(response.body)

    assert response_body.key?("pagination")
    assert response_body["pagination"]["page"] >= 1
    assert response_body["pagination"]["per_page"] > 0
  end

  test "should sort accounts alphabetically" do
    get "/api/v1/accounts", headers: api_headers

    assert_response :success
    response_body = JSON.parse(response.body)

    account_names = response_body["accounts"].map { |a| a["name"] }
    assert_equal account_names.sort, account_names
  end

  private

    def api_headers
      { "X-Api-Key" => @plain_api_key }
    end
end
