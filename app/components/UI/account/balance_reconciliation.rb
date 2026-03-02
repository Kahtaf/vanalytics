class UI::Account::BalanceReconciliation < ApplicationComponent
  attr_reader :balance, :account

  def initialize(balance:, account:)
    @balance = balance
    @account = account
  end

  def reconciliation_items
    crypto_items
  end

  private

    def crypto_items
      items = [
        { label: "Start balance", value: balance.start_balance_money, tooltip: "The crypto holdings value at the beginning of this day", style: :start }
      ]

      items << { label: "Buys", value: balance.cash_outflows_money * -1, tooltip: "Crypto purchases during the day", style: :flow } if balance.cash_outflows != 0
      items << { label: "Sells", value: balance.cash_inflows_money, tooltip: "Crypto sales during the day", style: :flow } if balance.cash_inflows != 0
      items << { label: "Market changes", value: balance.net_market_flows_money, tooltip: "Value changes from market price movements", style: :flow } if balance.net_market_flows != 0

      if has_adjustments?
        items << { label: "End balance", value: end_balance_before_adjustments, tooltip: "The calculated balance after all activity", style: :subtotal }
        items << { label: "Adjustments", value: total_adjustments, tooltip: "Manual reconciliations or other adjustments", style: :adjustment }
      end

      items << { label: "Final balance", value: balance.end_balance_money, tooltip: "The final crypto holdings value for the day", style: :final }
      items
    end

    def net_cash_flow
      balance.cash_inflows_money - balance.cash_outflows_money
    end

    def net_non_cash_flow
      balance.non_cash_inflows_money - balance.non_cash_outflows_money
    end

    def net_total_flow
      net_cash_flow + net_non_cash_flow + balance.net_market_flows_money
    end

    def total_adjustments
      balance.cash_adjustments_money + balance.non_cash_adjustments_money
    end

    def has_adjustments?
      balance.cash_adjustments != 0 || balance.non_cash_adjustments != 0
    end

    def end_balance_before_adjustments
      balance.end_balance_money - total_adjustments
    end
end
