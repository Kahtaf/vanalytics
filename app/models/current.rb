class Current < ActiveSupport::CurrentAttributes
  attribute :user_agent, :ip_address

  attribute :session

  delegate :family, to: :user, allow_nil: true

  def user
    session&.user
  end
end
