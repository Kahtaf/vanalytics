require "test_helper"

class Account::LinkableTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
  end

  test "linked? returns false when account has no providers" do
    assert @account.unlinked?
  end

  test "can_delete_holdings? returns true for unlinked accounts" do
    assert @account.unlinked?
    assert @account.can_delete_holdings?
  end
end
