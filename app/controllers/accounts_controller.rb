class AccountsController < ApplicationController
  before_action :set_account, only: %i[sync sparkline toggle_active show destroy]
  include Periodable

  def index
    @manual_accounts = family.accounts
          .listable_manual
          .order(:name)

    # Prevent Turbo Drive from caching this page to ensure fresh account lists
    expires_now
    render layout: "settings"
  end

  def new
    # Get all registered providers with any credentials configured
    @provider_configs = Provider::Factory.registered_adapters.flat_map do |adapter_class|
      adapter_class.connection_configs(family: family)
    end
  end

  def sync_all
    family.sync_later
    redirect_to accounts_path, notice: t("accounts.sync_all.syncing")
  end

  def show
    @chart_view = params[:chart_view] || "balance"
    @tab = params[:tab]
    @q = params.fetch(:q, {}).permit(:search, status: [])
    entries = @account.entries.where(excluded: false).search(@q).reverse_chronological

    @pagy, @entries = pagy(entries, limit: safe_per_page)

    @activity_feed_data = Account::ActivityFeedData.new(@account, @entries)
  end

  def sync
    unless @account.syncing?
      if @account.linked?
        # Sync all provider items for this account
        # Each provider item will trigger an account sync when complete
        @account.account_providers.each do |account_provider|
          item = account_provider.adapter&.item
          item&.sync_later if item && !item.syncing?
        end
      else
        # Manual accounts just need balance materialization
        @account.sync_later
      end
    end

    redirect_to account_path(@account)
  end

  def sparkline
    etag_key = @account.family.build_cache_key("#{@account.id}_sparkline", invalidate_on_data_updates: true)

    # Short-circuit with 304 Not Modified when the client already has the latest version.
    # We defer the expensive series computation until we know the content is stale.
    if stale?(etag: etag_key, last_modified: @account.family.latest_sync_completed_at)
      @sparkline_series = @account.sparkline_series
      render layout: false
    end
  end

  def toggle_active
    if @account.active?
      @account.disable!
    elsif @account.disabled?
      @account.enable!
    end
    redirect_to accounts_path
  end

  def destroy
    if @account.linked?
      redirect_to account_path(@account), alert: t("accounts.destroy.cannot_delete_linked")
    else
      @account.destroy_later
      redirect_to accounts_path, notice: t("accounts.destroy.success", type: @account.accountable_type)
    end
  end

  private
    def family
      Current.family
    end

    def set_account
      @account = family.accounts.find(params[:id])
    end
end
