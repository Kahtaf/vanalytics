class Account < ApplicationRecord
  include AASM, Syncable, Monetizable, Chartable, Linkable, Anchorable, Reconcileable, TaxTreatable

  validates :name, :balance, :currency, presence: true

  belongs_to :family

  has_many :entries, dependent: :destroy
  has_many :valuations, through: :entries, source: :entryable, source_type: "Valuation"
  has_many :trades, through: :entries, source: :entryable, source_type: "Trade"
  has_many :holdings, dependent: :destroy
  has_many :balances, dependent: :destroy

  monetize :balance, :cash_balance

  enum :classification, { asset: "asset", liability: "liability" }, validate: { allow_nil: true }

  scope :visible, -> { where(status: [ "draft", "active" ]) }
  scope :assets, -> { where(classification: "asset") }
  scope :liabilities, -> { where(classification: "liability") }
  scope :alphabetically, -> { order(:name) }
  scope :manual, -> {
    left_joins(:account_providers)
      .where(account_providers: { id: nil })
  }

  scope :visible_manual, -> {
    visible.manual
  }

  scope :listable_manual, -> {
    manual.where.not(status: :pending_deletion)
  }

  has_one_attached :logo, dependent: :purge_later

  delegated_type :accountable, types: Accountable::TYPES, dependent: :destroy
  delegate :subtype, to: :accountable, allow_nil: true

  # Writer for subtype that delegates to the accountable
  # This allows forms to set subtype directly on the account
  def subtype=(value)
    accountable&.subtype = value
  end

  accepts_nested_attributes_for :accountable, update_only: true

  # Account state machine
  aasm column: :status, timestamps: true do
    state :active, initial: true
    state :draft
    state :disabled
    state :pending_deletion

    event :activate do
      transitions from: [ :draft, :disabled ], to: :active
    end

    event :disable do
      transitions from: [ :draft, :active ], to: :disabled
    end

    event :enable do
      transitions from: :disabled, to: :active
    end

    event :mark_for_deletion do
      transitions from: [ :draft, :active, :disabled ], to: :pending_deletion
    end
  end

  class << self
    def human_attribute_name(attribute, options = {})
      options = { moniker: Current.family&.moniker_label || "Family" }.merge(options)
      super(attribute, options)
    end

    def create_and_sync(attributes, skip_initial_sync: false)
      attributes[:accountable_attributes] ||= {} # Ensure accountable is created, even if empty
      # Default cash_balance to balance unless explicitly provided (e.g., Crypto sets it to 0)
      attrs = attributes.dup
      attrs[:cash_balance] = attrs[:balance] unless attrs.key?(:cash_balance)
      account = new(attrs)
      initial_balance = attributes.dig(:accountable_attributes, :initial_balance)&.to_d

      transaction do
        account.save!

        manager = Account::OpeningBalanceManager.new(account)
        result = manager.set_opening_balance(balance: initial_balance || account.balance)
        raise result.error if result.error
      end

      # Skip initial sync for linked accounts - the provider sync will handle balance creation
      # after the correct currency is known
      account.sync_later unless skip_initial_sync
      account
    end


  end

  def institution_name
    read_attribute(:institution_name).presence || provider&.institution_name
  end

  def institution_domain
    read_attribute(:institution_domain).presence || provider&.institution_domain
  end

  def logo_url
    provider&.logo_url
  end

  def destroy_later
    mark_for_deletion!
    DestroyJob.perform_later(self)
  end

  # Override destroy to handle error recovery for accounts
  def destroy
    super
  rescue => e
    # If destruction fails, transition back to disabled state
    # This provides a cleaner recovery path than the generic scheduled_for_deletion flag
    disable! if may_disable?
    raise e
  end

  def current_holdings
    holdings
      .where(currency: currency)
      .where.not(qty: 0)
      .where(
        id: holdings.select("DISTINCT ON (security_id) id")
                    .where(currency: currency)
                    .order(:security_id, date: :desc)
      )
      .order(amount: :desc)
  end

  def start_date
    first_entry_date = entries.minimum(:date) || Date.current
    first_entry_date - 1.day
  end

  def lock_saved_attributes!
    super
    accountable.lock_saved_attributes!
  end

  def first_valuation
    entries.valuations.order(:date).first
  end

  def first_valuation_amount
    first_valuation&.amount_money || balance_money
  end

  # Get short version of the subtype label
  def short_subtype_label
    accountable_class.short_subtype_label_for(subtype) || accountable_class.display_name
  end

  # Get long version of the subtype label
  def long_subtype_label
    accountable_class.long_subtype_label_for(subtype) || accountable_class.display_name
  end

  def supports_trades?
    return accountable.supports_trades? if crypto? && accountable.respond_to?(:supports_trades?)
    false
  end

  def balance_type
    :investment
  end
end
