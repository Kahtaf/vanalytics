# Minimal stub — kept only to prevent NameError in code paths that will be
# removed in P1-05 (reports, income_statement, transaction/search, pages_controller).
# Do NOT add new functionality here.  Delete this file in P1-05.
class Category < ApplicationRecord
  UNCATEGORIZED_COLOR = "#6b7280".freeze

  scope :uncategorized, -> { none }
  scope :other_investments, -> { none }
  scope :alphabetically, -> { order(:name) }

  def self.all_uncategorized_names
    []
  end

  def self.all_investment_contributions_names
    []
  end

  def self.investment_contributions_name
    "Investment Contributions"
  end

  def uncategorized?
    false
  end

  def other_investments?
    false
  end
end
