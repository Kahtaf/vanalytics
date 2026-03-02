# frozen_string_literal: true

require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)

    # Clean up any existing API keys for the test user
    @user.api_keys.destroy_all

    # Create a test API key
    @plain_api_key = "base_test_#{SecureRandom.hex(8)}"
    @api_key = ApiKey.create!(
      user: @user,
      name: "Test API Key",
      display_key: @plain_api_key,
      scopes: [ "read_write" ]
    )

    # Clear any existing rate limit data
    Redis.new.del("api_rate_limit:#{@api_key.id}")
  end

  teardown do
    # Clean up Redis data after each test
    Redis.new.del("api_rate_limit:#{@api_key.id}")
  end

  test "should require authentication" do
    get "/api/v1/test"
    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
  end

  test "should authenticate with valid API key" do
    get "/api/v1/test", params: {}, headers: {
      "X-Api-Key" => @plain_api_key
    }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "test_success", response_body["message"]
    assert_equal @user.email, response_body["user"]
  end

  test "should reject invalid API key" do
    get "/api/v1/test", params: {}, headers: {
      "X-Api-Key" => "invalid_api_key"
    }

    assert_response :unauthorized
    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
    assert_includes response_body["message"], "API key"
  end

  test "should reject expired API key" do
    @api_key.update!(expires_at: 1.day.ago)

    get "/api/v1/test", params: {}, headers: {
      "X-Api-Key" => @plain_api_key
    }

    assert_response :unauthorized
    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
  end

  test "should reject revoked API key" do
    @api_key.revoke!

    get "/api/v1/test", params: {}, headers: {
      "X-Api-Key" => @plain_api_key
    }

    assert_response :unauthorized
    response_body = JSON.parse(response.body)
    assert_equal "unauthorized", response_body["error"]
  end

  test "should update last_used_at when API key is used" do
    original_time = @api_key.last_used_at

    get "/api/v1/test", params: {}, headers: {
      "X-Api-Key" => @plain_api_key
    }

    assert_response :success
    @api_key.reload
    assert_not_equal original_time, @api_key.last_used_at
    assert @api_key.last_used_at > (original_time || Time.at(0))
  end

  test "should provide current_scopes for API key authentication" do
    get "/api/v1/test_scope_required", params: {}, headers: {
      "X-Api-Key" => @plain_api_key
    }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "scope_authorized", response_body["message"]
    assert_includes response_body["scopes"], "read_write"
  end

  test "should authorize API key with required scope" do
    get "/api/v1/test_scope_required", params: {}, headers: {
      "X-Api-Key" => @plain_api_key
    }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "scope_authorized", response_body["message"]
    assert_equal "write", response_body["required_scope"]
  end

  test "should reject API key without required scope" do
    @api_key.revoke!
    limited_api_key = ApiKey.create!(
      user: @user,
      name: "Limited API Key",
      display_key: "limited_key_#{SecureRandom.hex(8)}",
      scopes: [ "read" ]
    )

    get "/api/v1/test_scope_required", params: {}, headers: {
      "X-Api-Key" => limited_api_key.display_key
    }

    assert_response :forbidden
    response_body = JSON.parse(response.body)
    assert_equal "insufficient_scope", response_body["error"]
    assert_includes response_body["message"], "write"
  end

  test "should authorize API key with multiple required scopes" do
    get "/api/v1/test_multiple_scopes_required", params: {}, headers: {
      "X-Api-Key" => @plain_api_key
    }

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal "read_scope_authorized", response_body["message"]
    assert_includes response_body["scopes"], "read_write"
  end

  test "should log API access with API key information" do
    logs = capture_log do
      get "/api/v1/test", params: {}, headers: {
        "X-Api-Key" => @plain_api_key
      }
    end

    assert_includes logs, "API Request"
    assert_includes logs, "GET /api/v1/test"
    assert_includes logs, @user.email
  end

  test "should handle ActiveRecord::RecordNotFound errors" do
    get "/api/v1/test_not_found", params: {}, headers: {
      "X-Api-Key" => @plain_api_key
    }

    assert_response :not_found
    response_body = JSON.parse(response.body)
    assert_equal "record_not_found", response_body["error"]
  end

  test "should enforce family-based access control with API key" do
    other_family = families(:dylan_family)
    other_user = users(:family_member)
    other_user.update!(family: other_family)
    other_user.api_keys.destroy_all

    other_user_api_key = ApiKey.create!(
      user: other_user,
      name: "Other User API Key",
      display_key: "other_user_key_#{SecureRandom.hex(8)}",
      scopes: [ "read" ]
    )

    get "/api/v1/test_family_access", params: {}, headers: {
      "X-Api-Key" => other_user_api_key.display_key
    }

    assert_response :forbidden
    response_body = JSON.parse(response.body)
    assert_equal "forbidden", response_body["error"]
  end

  test "should include rate limit headers on successful API key requests" do
    get "/api/v1/test", headers: { "X-Api-Key" => @plain_api_key }

    assert_response :success
    assert_not_nil response.headers["X-RateLimit-Limit"]
    assert_not_nil response.headers["X-RateLimit-Remaining"]
    assert_not_nil response.headers["X-RateLimit-Reset"]

    assert_equal "100", response.headers["X-RateLimit-Limit"]
    assert_equal "99", response.headers["X-RateLimit-Remaining"]
  end

  test "should increment rate limit count with each request" do
    get "/api/v1/test", headers: { "X-Api-Key" => @plain_api_key }
    assert_response :success
    assert_equal "99", response.headers["X-RateLimit-Remaining"]

    get "/api/v1/test", headers: { "X-Api-Key" => @plain_api_key }
    assert_response :success
    assert_equal "98", response.headers["X-RateLimit-Remaining"]
  end

  test "should return 429 when rate limit exceeded" do
    100.times do
      get "/api/v1/test", headers: { "X-Api-Key" => @plain_api_key }
      assert_response :success
    end

    get "/api/v1/test", headers: { "X-Api-Key" => @plain_api_key }
    assert_response :too_many_requests

    response_body = JSON.parse(response.body)
    assert_equal "rate_limit_exceeded", response_body["error"]
    assert_includes response_body["message"], "Rate limit exceeded"

    assert_equal "100", response.headers["X-RateLimit-Limit"]
    assert_equal "0", response.headers["X-RateLimit-Remaining"]
    assert_not_nil response.headers["X-RateLimit-Reset"]
    assert_not_nil response.headers["Retry-After"]
  end

  test "rate limiting should be per API key" do
    other_user = users(:family_member)
    other_api_key = ApiKey.create!(
      user: other_user,
      name: "Other Test API Key",
      scopes: [ "read" ],
      display_key: "other_rate_test_#{SecureRandom.hex(8)}"
    )

    begin
      50.times do
        get "/api/v1/test", headers: { "X-Api-Key" => @plain_api_key }
        assert_response :success
      end

      get "/api/v1/test", headers: { "X-Api-Key" => other_api_key.display_key }
      assert_response :success
      assert_equal "99", response.headers["X-RateLimit-Remaining"]
    ensure
      Redis.new.del("api_rate_limit:#{other_api_key.id}")
      other_api_key.destroy
    end
  end

private

  def capture_log(&block)
    io = StringIO.new
    original_logger = Rails.logger
    Rails.logger = Logger.new(io)

    yield

    io.string
  ensure
    Rails.logger = original_logger
  end
end
