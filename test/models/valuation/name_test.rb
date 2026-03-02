require "test_helper"

class Valuation::NameTest < ActiveSupport::TestCase
  test "generates opening anchor name" do
    name = Valuation::Name.new("opening_anchor", "Crypto")
    assert_equal "Opening account value", name.to_s
  end

  test "generates current anchor name" do
    name = Valuation::Name.new("current_anchor", "Crypto")
    assert_equal "Current account value", name.to_s
  end

  test "generates recon name" do
    name = Valuation::Name.new("reconciliation", "Crypto")
    assert_equal "Manual value update", name.to_s
  end
end
