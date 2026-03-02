class Settings::BankSyncController < ApplicationController
  layout "settings"

  def show
    @providers = []
  end
end
