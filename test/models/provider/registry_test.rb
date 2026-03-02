require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  test "providers filters out nil values when provider is not configured" do
    registry = Provider::Registry.for_concept(:exchange_rates)

    # Should return array of non-nil providers only
    assert registry.providers.none?(&:nil?)
  end

  test "get_provider raises error when provider not found for concept" do
    registry = Provider::Registry.for_concept(:exchange_rates)

    error = assert_raises(Provider::Registry::Error) do
      registry.get_provider(:nonexistent)
    end

    assert_match(/Provider 'nonexistent' not found for concept: exchange_rates/, error.message)
  end

  test "validates concept is in CONCEPTS" do
    assert_raises(ActiveModel::ValidationError) do
      Provider::Registry.for_concept(:invalid_concept)
    end
  end
end
