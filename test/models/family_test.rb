require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  include SyncableInterfaceTest

  def setup
    @syncable = families(:dylan_family)
  end

  test "moniker helpers return expected singular and plural labels" do
    family = families(:dylan_family)

    family.update!(moniker: "Family")
    assert_equal "Family", family.moniker_label
    assert_equal "Families", family.moniker_label_plural

    family.update!(moniker: "Group")
    assert_equal "Group", family.moniker_label
    assert_equal "Groups", family.moniker_label_plural
  end
end
