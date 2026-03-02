class DataCleanerJob < ApplicationJob
  queue_as :scheduled

  def perform
    # No-op: merchant associations removed in P1-04
  end
end
