require "test_helper"

class SyncTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "does not run if not in a valid state" do
    syncable = accounts(:crypto)
    sync = Sync.create!(syncable: syncable, status: :completed)

    syncable.expects(:perform_sync).never

    sync.perform

    assert_equal "completed", sync.status
  end

  test "runs successful sync" do
    syncable = accounts(:crypto)
    sync = Sync.create!(syncable: syncable)

    syncable.expects(:perform_sync).with(sync).once

    assert_equal "pending", sync.status

    sync.perform

    assert sync.completed_at < Time.now
    assert_equal "completed", sync.status
  end

  test "handles sync errors" do
    syncable = accounts(:crypto)
    sync = Sync.create!(syncable: syncable)

    syncable.expects(:perform_sync).with(sync).raises(StandardError.new("test sync error"))

    assert_equal "pending", sync.status

    sync.perform

    assert sync.failed_at < Time.now
    assert_equal "failed", sync.status
    assert_equal "test sync error", sync.error
  end

  test "clean marks stale incomplete rows" do
    stale_pending = Sync.create!(
      syncable: accounts(:crypto),
      status: :pending,
      created_at: 25.hours.ago
    )

    stale_syncing = Sync.create!(
      syncable: accounts(:crypto),
      status: :syncing,
      created_at: 25.hours.ago,
      pending_at: 24.hours.ago,
      syncing_at: 23.hours.ago
    )

    Sync.clean

    assert_equal "stale", stale_pending.reload.status
    assert_equal "stale", stale_syncing.reload.status
  end

  test "expand_window_if_needed widens start and end dates on a pending sync" do
    initial_start = 1.day.ago.to_date
    initial_end   = 1.day.ago.to_date

    sync = Sync.create!(
      syncable: accounts(:crypto),
      window_start_date: initial_start,
      window_end_date: initial_end
    )

    new_start = 5.days.ago.to_date
    new_end   = Date.current

    sync.expand_window_if_needed(new_start, new_end)
    sync.reload

    assert_equal new_start, sync.window_start_date
    assert_equal new_end,   sync.window_end_date
  end
end
