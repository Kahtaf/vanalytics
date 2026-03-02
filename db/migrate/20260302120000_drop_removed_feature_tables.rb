class DropRemovedFeatureTables < ActiveRecord::Migration[7.2]
  def up
    # ── Remove foreign keys from remaining tables that reference tables being dropped ──

    # accounts → imports, plaid_accounts, simplefin_accounts
    remove_foreign_key :accounts, :imports, if_exists: true
    remove_foreign_key :accounts, :plaid_accounts, if_exists: true
    remove_foreign_key :accounts, :simplefin_accounts, if_exists: true

    # entries → imports
    remove_foreign_key :entries, :imports, if_exists: true

    # sessions → impersonation_sessions
    remove_foreign_key :sessions, :impersonation_sessions, column: :active_impersonator_session_id, if_exists: true

    # users → chats
    remove_foreign_key :users, :chats, column: :last_viewed_chat_id, if_exists: true

    # ── Remove orphaned columns from remaining tables ──

    # accounts: provider/import reference columns
    remove_column :accounts, :import_id, if_exists: true
    remove_column :accounts, :plaid_account_id, if_exists: true
    remove_column :accounts, :simplefin_account_id, if_exists: true

    # entries: import reference
    remove_column :entries, :import_id, if_exists: true

    # sessions: impersonation reference
    remove_column :sessions, :active_impersonator_session_id, if_exists: true

    # users: AI/chat/rules columns for removed features
    remove_column :users, :last_viewed_chat_id, if_exists: true
    remove_column :users, :show_ai_sidebar, if_exists: true
    remove_column :users, :ai_enabled, if_exists: true
    remove_column :users, :rule_prompts_disabled, if_exists: true
    remove_column :users, :rule_prompt_dismissed_at, if_exists: true

    # families: removed feature columns
    remove_column :families, :stripe_customer_id, if_exists: true
    remove_column :families, :data_enrichment_enabled, if_exists: true
    remove_column :families, :recurring_transactions_disabled, if_exists: true
    remove_column :families, :vector_store_id, if_exists: true
    remove_column :families, :assistant_type, if_exists: true

    # ── Drop all removed feature tables ──
    # Order: child tables before parent tables to avoid FK constraint errors

    # AI/Chat
    drop_table :tool_calls, if_exists: true
    drop_table :messages, if_exists: true
    drop_table :chats, if_exists: true
    drop_table :llm_usages, if_exists: true

    # Eval
    drop_table :eval_results, if_exists: true
    drop_table :eval_samples, if_exists: true
    drop_table :eval_runs, if_exists: true
    drop_table :eval_datasets, if_exists: true

    # Budgets/Categories/Merchants/Rules
    drop_table :budget_categories, if_exists: true
    drop_table :budgets, if_exists: true
    drop_table :recurring_transactions, if_exists: true
    drop_table :family_merchant_associations, if_exists: true
    drop_table :rule_actions, if_exists: true
    drop_table :rule_conditions, if_exists: true
    drop_table :rule_runs, if_exists: true
    drop_table :rules, if_exists: true
    drop_table :categories, if_exists: true
    drop_table :merchants, if_exists: true

    # Transactions/Transfers
    drop_table :rejected_transfers, if_exists: true
    drop_table :transfers, if_exists: true
    drop_table :transactions, if_exists: true

    # Imports/Exports
    drop_table :import_mappings, if_exists: true
    drop_table :import_rows, if_exists: true
    drop_table :imports, if_exists: true
    drop_table :family_exports, if_exists: true
    drop_table :family_documents, if_exists: true

    # Banking providers
    drop_table :plaid_accounts, if_exists: true
    drop_table :plaid_items, if_exists: true
    drop_table :simplefin_accounts, if_exists: true
    drop_table :simplefin_items, if_exists: true
    drop_table :enable_banking_accounts, if_exists: true
    drop_table :enable_banking_items, if_exists: true
    drop_table :lunchflow_accounts, if_exists: true
    drop_table :lunchflow_items, if_exists: true
    drop_table :mercury_accounts, if_exists: true
    drop_table :mercury_items, if_exists: true
    drop_table :snaptrade_accounts, if_exists: true
    drop_table :snaptrade_items, if_exists: true
    drop_table :indexa_capital_accounts, if_exists: true
    drop_table :indexa_capital_items, if_exists: true
    drop_table :coinbase_accounts, if_exists: true
    drop_table :coinbase_items, if_exists: true
    drop_table :coinstats_accounts, if_exists: true
    drop_table :coinstats_items, if_exists: true

    # Non-crypto account types
    drop_table :depositories, if_exists: true
    drop_table :investments, if_exists: true
    drop_table :properties, if_exists: true
    drop_table :vehicles, if_exists: true
    drop_table :credit_cards, if_exists: true
    drop_table :loans, if_exists: true
    drop_table :other_assets, if_exists: true
    drop_table :other_liabilities, if_exists: true
    drop_table :addresses, if_exists: true

    # Subscriptions/Invites/OAuth/SSO/Misc
    drop_table :subscriptions, if_exists: true
    drop_table :invite_codes, if_exists: true
    drop_table :invitations, if_exists: true
    drop_table :impersonation_session_logs, if_exists: true
    drop_table :impersonation_sessions, if_exists: true
    drop_table :data_enrichments, if_exists: true
    drop_table :mobile_devices, if_exists: true
    drop_table :oauth_access_grants, if_exists: true
    drop_table :oauth_access_tokens, if_exists: true
    drop_table :oauth_applications, if_exists: true
    drop_table :oidc_identities, if_exists: true
    drop_table :sso_audit_logs, if_exists: true
    drop_table :sso_providers, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
