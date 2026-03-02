# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_03_02_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "account_status", ["ok", "syncing", "error"]

  create_table "account_providers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "provider_type", null: false
    t.uuid "provider_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider_type"], name: "index_account_providers_on_account_and_provider_type", unique: true
    t.index ["provider_type", "provider_id"], name: "index_account_providers_on_provider_type_and_provider_id", unique: true
  end

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subtype"
    t.uuid "family_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "accountable_type"
    t.uuid "accountable_id"
    t.decimal "balance", precision: 19, scale: 4
    t.string "currency"
    t.virtual "classification", type: :string, as: "\nCASE\n    WHEN ((accountable_type)::text = ANY (ARRAY[('Loan'::character varying)::text, ('CreditCard'::character varying)::text, ('OtherLiability'::character varying)::text])) THEN 'liability'::text\n    ELSE 'asset'::text\nEND", stored: true
    t.decimal "cash_balance", precision: 19, scale: 4, default: "0.0"
    t.jsonb "locked_attributes", default: {}
    t.string "status", default: "active"
    t.string "institution_name"
    t.string "institution_domain"
    t.text "notes"
    t.jsonb "holdings_snapshot_data"
    t.datetime "holdings_snapshot_at"
    t.index ["accountable_id", "accountable_type"], name: "index_accounts_on_accountable_id_and_accountable_type"
    t.index ["accountable_type"], name: "index_accounts_on_accountable_type"
    t.index ["currency"], name: "index_accounts_on_currency"
    t.index ["family_id", "accountable_type"], name: "index_accounts_on_family_id_and_accountable_type"
    t.index ["family_id", "id"], name: "index_accounts_on_family_id_and_id"
    t.index ["family_id", "status", "accountable_type"], name: "index_accounts_on_family_id_status_accountable_type"
    t.index ["family_id", "status"], name: "index_accounts_on_family_id_and_status"
    t.index ["family_id"], name: "index_accounts_on_family_id"
    t.index ["status"], name: "index_accounts_on_status"
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.uuid "user_id", null: false
    t.json "scopes"
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_key", null: false
    t.string "source", default: "web"
    t.index ["display_key"], name: "index_api_keys_on_display_key", unique: true
    t.index ["revoked_at"], name: "index_api_keys_on_revoked_at"
    t.index ["user_id", "source"], name: "index_api_keys_on_user_id_and_source"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "balances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.date "date", null: false
    t.decimal "balance", precision: 19, scale: 4, null: false
    t.string "currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "cash_balance", precision: 19, scale: 4, default: "0.0"
    t.decimal "start_cash_balance", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "start_non_cash_balance", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "cash_inflows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "cash_outflows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_inflows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_outflows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "net_market_flows", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "cash_adjustments", precision: 19, scale: 4, default: "0.0", null: false
    t.decimal "non_cash_adjustments", precision: 19, scale: 4, default: "0.0", null: false
    t.integer "flows_factor", default: 1, null: false
    t.virtual "start_balance", type: :decimal, precision: 19, scale: 4, as: "(start_cash_balance + start_non_cash_balance)", stored: true
    t.virtual "end_cash_balance", type: :decimal, precision: 19, scale: 4, as: "((start_cash_balance + ((cash_inflows - cash_outflows) * (flows_factor)::numeric)) + cash_adjustments)", stored: true
    t.virtual "end_non_cash_balance", type: :decimal, precision: 19, scale: 4, as: "(((start_non_cash_balance + ((non_cash_inflows - non_cash_outflows) * (flows_factor)::numeric)) + net_market_flows) + non_cash_adjustments)", stored: true
    t.virtual "end_balance", type: :decimal, precision: 19, scale: 4, as: "(((start_cash_balance + ((cash_inflows - cash_outflows) * (flows_factor)::numeric)) + cash_adjustments) + (((start_non_cash_balance + ((non_cash_inflows - non_cash_outflows) * (flows_factor)::numeric)) + net_market_flows) + non_cash_adjustments))", stored: true
    t.index ["account_id", "date", "currency"], name: "index_account_balances_on_account_id_date_currency_unique", unique: true
    t.index ["account_id", "date"], name: "index_balances_on_account_id_and_date", order: { date: :desc }
    t.index ["account_id"], name: "index_balances_on_account_id"
  end

  create_table "cryptos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "subtype"
    t.string "tax_treatment", default: "taxable", null: false
  end

  create_table "entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "entryable_type"
    t.uuid "entryable_id"
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.string "currency"
    t.date "date"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.boolean "excluded", default: false
    t.string "plaid_id"
    t.jsonb "locked_attributes", default: {}
    t.string "external_id"
    t.string "source"
    t.boolean "user_modified", default: false, null: false
    t.boolean "import_locked", default: false, null: false
    t.index "lower((name)::text)", name: "index_entries_on_lower_name"
    t.index ["account_id", "date"], name: "index_entries_on_account_id_and_date"
    t.index ["account_id", "source", "external_id"], name: "index_entries_on_account_source_and_external_id", unique: true, where: "((external_id IS NOT NULL) AND (source IS NOT NULL))"
    t.index ["account_id"], name: "index_entries_on_account_id"
    t.index ["date"], name: "index_entries_on_date"
    t.index ["entryable_type"], name: "index_entries_on_entryable_type"
    t.index ["import_locked"], name: "index_entries_on_import_locked_true", where: "(import_locked = true)"
    t.index ["user_modified"], name: "index_entries_on_user_modified_true", where: "(user_modified = true)"
  end

  create_table "exchange_rates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "from_currency", null: false
    t.string "to_currency", null: false
    t.decimal "rate", null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_currency", "to_currency", "date"], name: "index_exchange_rates_on_base_converted_date_unique", unique: true
    t.index ["from_currency"], name: "index_exchange_rates_on_from_currency"
    t.index ["to_currency"], name: "index_exchange_rates_on_to_currency"
  end

  create_table "families", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency", default: "USD"
    t.string "locale", default: "en"
    t.string "date_format", default: "%m-%d-%Y"
    t.string "country", default: "US"
    t.string "timezone"
    t.boolean "early_access", default: false
    t.boolean "auto_sync_on_login", default: true, null: false
    t.datetime "latest_sync_activity_at", default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "latest_sync_completed_at", default: -> { "CURRENT_TIMESTAMP" }
    t.integer "month_start_day", default: 1, null: false
    t.string "moniker", default: "Family", null: false
    t.check_constraint "month_start_day >= 1 AND month_start_day <= 28", name: "month_start_day_range"
  end

  create_table "holdings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.uuid "security_id", null: false
    t.date "date", null: false
    t.decimal "qty", precision: 19, scale: 4, null: false
    t.decimal "price", precision: 19, scale: 4, null: false
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.decimal "cost_basis", precision: 19, scale: 4
    t.uuid "account_provider_id"
    t.string "cost_basis_source"
    t.boolean "cost_basis_locked", default: false, null: false
    t.uuid "provider_security_id"
    t.boolean "security_locked", default: false, null: false
    t.index ["account_id", "external_id"], name: "idx_holdings_on_account_id_external_id_unique", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["account_id", "security_id", "date", "currency"], name: "idx_on_account_id_security_id_date_currency_5323e39f8b", unique: true
    t.index ["account_id"], name: "index_holdings_on_account_id"
    t.index ["account_provider_id"], name: "index_holdings_on_account_provider_id"
    t.index ["provider_security_id"], name: "index_holdings_on_provider_security_id"
    t.index ["security_id"], name: "index_holdings_on_security_id"
  end

  create_table "securities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "ticker", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "country_code"
    t.string "exchange_mic"
    t.string "exchange_acronym"
    t.string "logo_url"
    t.string "exchange_operating_mic"
    t.boolean "offline", default: false, null: false
    t.datetime "failed_fetch_at"
    t.integer "failed_fetch_count", default: 0, null: false
    t.datetime "last_health_check_at"
    t.string "website_url"
    t.index "upper((ticker)::text), COALESCE(upper((exchange_operating_mic)::text), ''::text)", name: "index_securities_on_ticker_and_exchange_operating_mic_unique", unique: true
    t.index ["country_code"], name: "index_securities_on_country_code"
    t.index ["exchange_operating_mic"], name: "index_securities_on_exchange_operating_mic"
  end

  create_table "security_prices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "date", null: false
    t.decimal "price", precision: 19, scale: 4, null: false
    t.string "currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "security_id"
    t.boolean "provisional", default: false, null: false
    t.index ["security_id", "date", "currency"], name: "index_security_prices_on_security_id_and_date_and_currency", unique: true
    t.index ["security_id"], name: "index_security_prices_on_security_id"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "subscribed_at"
    t.jsonb "prev_transaction_page_params", default: {}
    t.jsonb "data", default: {}
    t.string "ip_address_digest"
    t.index ["ip_address_digest"], name: "index_sessions_on_ip_address_digest"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "var", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["var"], name: "index_settings_on_var", unique: true
  end

  create_table "syncs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "syncable_type", null: false
    t.uuid "syncable_id", null: false
    t.string "status", default: "pending"
    t.string "error"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "parent_id"
    t.datetime "pending_at"
    t.datetime "syncing_at"
    t.datetime "completed_at"
    t.datetime "failed_at"
    t.date "window_start_date"
    t.date "window_end_date"
    t.text "sync_stats"
    t.index ["parent_id"], name: "index_syncs_on_parent_id"
    t.index ["status"], name: "index_syncs_on_status"
    t.index ["syncable_type", "syncable_id"], name: "index_syncs_on_syncable"
  end

  create_table "taggings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tag_id", null: false
    t.string "taggable_type"
    t.uuid "taggable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
  end

  create_table "tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "color", default: "#e99537", null: false
    t.uuid "family_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_tags_on_family_id"
  end

  create_table "trades", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "security_id", null: false
    t.decimal "qty", precision: 19, scale: 4
    t.decimal "price", precision: 19, scale: 10
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "currency"
    t.jsonb "locked_attributes", default: {}
    t.decimal "realized_gain", precision: 19, scale: 4
    t.decimal "cost_basis_amount", precision: 19, scale: 4
    t.string "cost_basis_currency"
    t.integer "holding_period_days"
    t.string "realized_gain_confidence"
    t.string "realized_gain_currency"
    t.string "investment_activity_label"
    t.index ["investment_activity_label"], name: "index_trades_on_investment_activity_label"
    t.index ["realized_gain"], name: "index_trades_on_realized_gain_not_null", where: "(realized_gain IS NOT NULL)"
    t.index ["security_id"], name: "index_trades_on_security_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "family_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "member", null: false
    t.boolean "active", default: true, null: false
    t.datetime "onboarded_at"
    t.string "unconfirmed_email"
    t.string "otp_secret"
    t.boolean "otp_required", default: false, null: false
    t.string "otp_backup_codes", default: [], array: true
    t.boolean "show_sidebar", default: true
    t.string "default_period", default: "last_30_days", null: false
    t.string "theme", default: "system"
    t.text "goals", default: [], array: true
    t.datetime "set_onboarding_preferences_at"
    t.datetime "set_onboarding_goals_at"
    t.string "default_account_order", default: "name_asc"
    t.jsonb "preferences", default: {}, null: false
    t.string "locale"
    t.string "ui_layout"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["family_id"], name: "index_users_on_family_id"
    t.index ["locale"], name: "index_users_on_locale"
    t.index ["otp_secret"], name: "index_users_on_otp_secret", unique: true, where: "(otp_secret IS NOT NULL)"
    t.index ["preferences"], name: "index_users_on_preferences", using: :gin
  end

  create_table "valuations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "locked_attributes", default: {}
    t.string "kind", default: "reconciliation", null: false
  end

  add_foreign_key "account_providers", "accounts", on_delete: :cascade
  add_foreign_key "accounts", "families"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "users"
  add_foreign_key "balances", "accounts", on_delete: :cascade
  add_foreign_key "entries", "accounts", on_delete: :cascade
  add_foreign_key "holdings", "account_providers"
  add_foreign_key "holdings", "accounts", on_delete: :cascade
  add_foreign_key "holdings", "securities"
  add_foreign_key "holdings", "securities", column: "provider_security_id"
  add_foreign_key "security_prices", "securities"
  add_foreign_key "sessions", "users"
  add_foreign_key "syncs", "syncs", column: "parent_id"
  add_foreign_key "taggings", "tags"
  add_foreign_key "tags", "families"
  add_foreign_key "trades", "securities"
  add_foreign_key "users", "families"
end
