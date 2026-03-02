# Vanalytics Implementation Plan

> Source of truth for all tasks. Read `docs/vana-migration-plan.md` for full architecture context.

## Task Table

| ID | Task | Deps | Status |
|----|------|------|--------|
| **Phase 1: Strip & Clean** | | | |
| P1-01 | Remove AI assistant (models, controllers, views, tests, layout sidebar) | — | `[x]` |
| P1-02 | Remove banking providers (Plaid, SimpleFIN, EnableBanking, Lunchflow, Mercury, Snaptrade, IndexaCapital, Coinbase, CoinStats) | — | `[x]` |
| P1-03 | Remove non-crypto account types (Depository, Investment, Property, Vehicle, CreditCard, Loan, OtherAsset, OtherLiability) | — | `[x]` |
| P1-04 | Remove budgets, categories, merchants, rules, recurring transactions | — | `[x]` |
| P1-05 | Remove transactions UI, transfers, imports/exports, reports (keep Entry/Valuation/Trade) | — | `[x]` |
| P1-06 | Remove misc features (subscriptions, invites, impersonation, OAuth/Doorkeeper, eval, SSO, mobile devices, data enrichments) | — | `[ ]` |
| P1-07 | Clean up Gemfile — remove unused gems, bundle install | P1-01..P1-06 | `[ ]` |
| P1-08 | Database migration — drop ~40 removed tables | P1-01..P1-06 | `[ ]` |
| P1-09 | Clean routes.rb and navigation (remove dead routes, simplify nav) | P1-01..P1-06 | `[ ]` |
| P1-10 | Verify clean build (rails test, rubocop, brakeman all pass) | P1-07..P1-09 | `[ ]` |
| **Phase 2: Wallet & Balance Tracking** | | | |
| P2-01 | Add wallet_address and chain columns to accounts table | P1-10 | `[ ]` |
| P2-02 | Create Provider::VanaRpc (eth_getBalance, ERC-20 balanceOf, staking reads) | P2-01 | `[ ]` |
| P2-03 | Create Provider::Vanascan (Blockscout API — txlist, token transfers) | P2-02 | `[ ]` |
| P2-04 | VANA price feed (CoinGecko → security_prices table) | P2-02 | `[ ]` |
| P2-05 | WalletSyncJob (fetch balances → update holdings → snapshot balance) | P2-02, P2-04 | `[ ]` |
| P2-06 | Wallet management UI (add/view/delete wallets, sidebar listing) | P2-01, P2-05 | `[ ]` |
| P2-07 | Portfolio dashboard (portfolio value, token allocation donut, net worth chart) | P2-05, P2-06 | `[ ]` |
| P2-08 | Integration test — full wallet sync flow (add wallet → sync → verify balances) | P2-05, P2-06 | `[ ]` |
| **Phase 3: Staking Integration** | | | |
| P3-01 | Create StakingPosition model + migration | P2-08 | `[ ]` |
| P3-02 | Create StakingSnapshot model + migration (daily history) | P3-01 | `[ ]` |
| P3-03 | Staking contract reader (VanaPoolStaking shares, value per share, entity info) | P2-02, P3-01 | `[ ]` |
| P3-04 | Add staking sync to WalletSyncJob (detect events, create snapshots) | P2-05, P3-01, P3-03 | `[ ]` |
| P3-05 | Staking dashboard UI (overview, position detail, reward history chart) | P3-04 | `[ ]` |
| P3-06 | Integration test — staking lifecycle (stake → rewards accrue → unstake → verify history) | P3-04, P3-05 | `[ ]` |
| **Phase 4: Dashboard & UX Polish** | | | |
| P4-01 | Rebrand to Vanalytics (app name, logos, meta tags, email templates) | P3-06 | `[ ]` |
| P4-02 | Update i18n for crypto context (accounts→wallets, net worth→portfolio value) | P3-06 | `[ ]` |
| P4-03 | Simplified onboarding ("Add your first Vana wallet" flow) | P2-06 | `[ ]` |
| P4-04 | Portfolio performance analytics (ROI, time-weighted returns) | P2-07, P3-05 | `[ ]` |
| P4-05 | Integration test — portfolio valuation (multi-wallet, price changes) | P2-07, P3-05 | `[ ]` |

---

## Task Details

### P1-01: Remove AI Assistant

**Delete**:
- Models: `app/models/chat.rb`, `message.rb`, `tool_call.rb`, `assistant.rb`, `assistant_message.rb`, `developer_message.rb`, `user_message.rb`, `llm_usage.rb`, `vector_store.rb`, dirs `tool_call/`, `assistant/`, `chat/`, `vector_store/`
- Provider: `app/models/provider/openai.rb`, `provider/openai/`, `provider/llm_concept.rb`
- Controllers: `chats_controller.rb`, `messages_controller.rb`, `mcp_controller.rb`
- Views: `app/views/chats/`, `app/views/messages/`
- Tests: `test/controllers/chats_controller_test.rb`, `messages_controller_test.rb`, `test/models/assistant/`, `test/models/eval/`, `test/interfaces/llm_interface_test.rb`, `test/vcr_cassettes/openai/`

**Modify**:
- `config/routes.rb` — remove chat/message routes
- `app/models/family.rb` — remove chat associations
- `app/models/user.rb` — remove chat/message associations
- `Gemfile` — remove `ruby-openai`, `langfuse-ruby`
- Layout `app/views/layouts/application.html.erb` — remove AI chat sidebar

**Verify**: `bin/rails test` passes, no references to Chat/Message/Assistant remain.

---

### P1-02: Remove Banking Provider Integrations

**Delete** (for each provider: item model, account model, model dirs, controller, views, tests, VCR cassettes):
1. Plaid — `plaid_item.rb`, `plaid_account.rb`, `plaid_account/`, `plaid_entry/`, controller, views, tests, `test/vcr_cassettes/plaid/`
2. SimpleFIN — `simplefin_item.rb`, `simplefin_account.rb`, `simplefin_account/`, `simplefin_entry/`, controller, views, tests
3. Enable Banking — `enable_banking_item.rb`, `enable_banking_account.rb`, `enable_banking_account/`, `enable_banking_entry/`, controller, views, tests
4. Lunchflow — `lunchflow_item.rb`, `lunchflow_account.rb`, `lunchflow_account/`, `lunchflow_entry/`, controller, views, tests
5. Mercury — `mercury_item.rb`, `mercury_account.rb`, `mercury_account/`, `mercury_entry/`, controller, views, tests
6. Snaptrade — `snaptrade_item.rb`, `snaptrade_account.rb`, `snaptrade_account/`, controller, views, tests
7. Indexa Capital — `indexa_capital_item.rb`, `indexa_capital_account.rb`, `indexa_capital_account/`, controller, views, tests
8. Coinbase — `coinbase_item.rb`, `coinbase_account.rb`, `coinbase_account/`, controller, views, tests
9. CoinStats — `coinstats_item.rb`, `coinstats_account.rb`, `coinstats_account/`, `coinstats_entry/`, controller, views, tests

**Provider adapters to delete** (in `app/models/provider/`): `plaid.rb`, `plaid_adapter.rb`, `plaid_eu_adapter.rb`, `plaid_sandbox.rb`, `simplefin.rb`, `simplefin_adapter.rb`, `enable_banking.rb`, `enable_banking_adapter.rb`, `lunchflow.rb`, `lunchflow_adapter.rb`, `mercury.rb`, `mercury_adapter.rb`, `snaptrade.rb`, `snaptrade_adapter.rb`, `indexa_capital.rb`, `indexa_capital_adapter.rb`, `coinbase.rb`, `coinbase_adapter.rb`, `coinstats.rb`, `coinstats_adapter.rb`, `stripe.rb`, `provider/stripe/`

**Keep** in `app/models/provider/`: `base.rb`, `registry.rb`, `factory.rb`, `configurable.rb`, `syncable.rb`, `github.rb`, `exchange_rate_concept.rb`, `security_concept.rb`, `twelve_data.rb`, `yahoo_finance.rb`

**Modify**: `config/routes.rb`, `app/models/family.rb`, `app/models/account.rb` (remove `create_from_*` methods), `Gemfile` (remove `plaid`, `snaptrade`, `stripe`), `config/initializers/` (remove provider initializers), `app/models/provider/registry.rb`

**Verify**: `bin/rails test` passes, no references to removed providers remain.

---

### P1-03: Remove Non-Crypto Account Types

**Delete**:
- Models: `depository.rb`, `investment.rb`, `property.rb`, `vehicle.rb`, `credit_card.rb`, `loan.rb`, `other_asset.rb`, `other_liability.rb`, `address.rb`
- Controllers: `depositories_controller.rb`, `investments_controller.rb`, `properties_controller.rb`, `vehicles_controller.rb`, `credit_cards_controller.rb`, `loans_controller.rb`, `other_assets_controller.rb`, `other_liabilities_controller.rb`
- Views: `app/views/depositories/`, `investments/`, `properties/`, `vehicles/`, `credit_cards/`, `loans/`, `other_assets/`, `other_liabilities/`, `investment_activity/`
- Tests: all corresponding test files

**Modify**:
- `app/models/concerns/accountable.rb` — `TYPES = %w[Crypto]`
- `app/models/account.rb` — simplify `balance_type` (always `:investment`), remove multi-type logic
- `config/routes.rb` — remove account type routes
- Sidebar views — remove non-crypto account groups

**Verify**: `Accountable::TYPES == %w[Crypto]`, `bin/rails test` passes.

---

### P1-04: Remove Budgets, Categories, Merchants, Rules

**Delete**:
- Budgets: `budget.rb`, `budget_category.rb`, `budgets_controller.rb`, `budget_categories_controller.rb`, `app/views/budgets/`
- Categories: `category.rb`, `category_import.rb`, `categories_controller.rb`, `app/controllers/category/`, `app/views/categories/`, `app/views/category/`
- Merchants: `merchant.rb`, `family_merchant.rb`, `family_merchant_association.rb`, `family_merchants_controller.rb`, `app/views/family_merchants/`
- Rules: `rule.rb`, `rule_import.rb`, `rule_run.rb`, `app/models/rule/`, `rules_controller.rb`, `app/views/rules/`
- Recurring: `recurring_transaction.rb`, `app/models/recurring_transaction/`, `recurring_transactions_controller.rb`, `app/views/recurring_transactions/`
- All corresponding test files

**Modify**: `config/routes.rb`, `app/models/family.rb` (remove associations), navigation (remove "Budgets"), `app/models/entry.rb` (remove category/merchant refs if present)

**Verify**: `bin/rails test` passes.

---

### P1-05: Remove Transactions, Transfers, Imports/Exports

**Delete**:
- Transaction UI: `transactions_controller.rb`, `app/controllers/transactions/`, `transaction_categories_controller.rb`, `app/views/transactions/`
- Transfers: `transfer.rb`, `rejected_transfer.rb`, `transfer_matches_controller.rb`, `transfers_controller.rb`, views
- Imports: `import.rb`, `app/models/import/`, all `*_import.rb`, `imports_controller.rb`, `app/controllers/import/`, `app/views/imports/`, `app/views/import/`
- Exports: `family_export.rb`, `family_exports_controller.rb`
- Reports: `reports_controller.rb`, `app/views/reports/`, `income_statement.rb`, `investment_statement.rb`, `investment_flow_statement.rb`

**IMPORTANT**: `Transaction` is an entryable type via polymorphism. Keep `Entry`, `Valuation`, `Trade`. Evaluate whether `Transaction` model can be fully removed or needs a minimal stub — the entry system must still work.

**Modify**: `config/routes.rb`, navigation (remove "Transactions", "Reports")

**Verify**: Entries system works for Valuations and Trades. `bin/rails test` passes.

---

### P1-06: Remove Miscellaneous Features

**Delete**: `subscription.rb`, `invite_code.rb`, `invitation.rb`, `invitations_controller.rb`, `impersonation_session.rb`, `impersonation_session_log.rb`, `impersonation_sessions_controller.rb`, `data_enrichment.rb`, `family_document.rb`, `family_export.rb`, `eval_dataset.rb`, `eval_result.rb`, `eval_run.rb`, `eval_sample.rb`, `mobile_device.rb`, `sso_provider.rb`, `sso_audit_log.rb`, `oidc_identity.rb`, `oidc_accounts_controller.rb`, all corresponding tests.

**Modify**: `Gemfile` (remove `doorkeeper`, `omniauth-*`, `stripe`), `config/routes.rb`, `config/initializers/` (remove Doorkeeper, Stripe), `app/models/user.rb` (remove SSO/OIDC), `app/models/family.rb` (remove subscription/invite)

**Verify**: `bin/rails test` passes.

---

### P1-07: Clean Up Gemfile

Remove: `plaid`, `snaptrade`, `stripe`, `doorkeeper`, `ruby-openai`, `langfuse-ruby`, `pdf-reader`, `omniauth`, `omniauth-google-oauth2`, `omniauth-rails_csrf_protection`, and any other gems only used by removed features.

Run `bundle install`, then `bin/rails test`.

---

### P1-08: Database Migration — Drop Removed Tables

Create one irreversible migration dropping ~40 tables (see Section 6.1 of `vana-migration-plan.md` for full list). `down` method raises `ActiveRecord::IrreversibleMigration`.

Run `bin/rails db:migrate`, then `bin/rails test`.

---

### P1-09: Clean Routes and Navigation

Audit `config/routes.rb` — remove all routes for deleted resources. Update layout navigation to show only: Dashboard, Wallets (placeholder), Staking (placeholder). Remove dead links.

Run `bin/rails routes` to verify, then `bin/rails test`.

---

### P1-10: Verify Clean Build

Run full verification suite:
```bash
bin/rails db:prepare && bin/rails test && bin/rubocop -f github -a && bin/brakeman --no-pager
```
Grep codebase for references to removed features. Fix any remaining issues.

---

### P2-01: Add Wallet Address to Account Model

**Tests first** (`test/models/account/wallet_test.rb`):
- Validates wallet_address format (0x + 40 hex chars)
- Enforces unique wallet_address per family
- Defaults chain to "vana"
- Rejects invalid addresses

**Implementation**: Migration adding `wallet_address` (string) and `chain` (string, default "vana") to accounts. Unique index on `[family_id, wallet_address]`. Validation in `Account` model.

---

### P2-02: Create Provider::VanaRpc

**Tests first** (`test/models/provider/vana_rpc_test.rb`):
- Fetches VANA native balance (`eth_getBalance`), converts wei → VANA (18 decimals)
- Fetches ERC-20 balance (`balanceOf`), converts raw → USDC.e (6 decimals)
- Fetches staking shares from VanaPoolStaking contract
- Handles RPC errors, timeouts, malformed responses

**Implementation**: `app/models/provider/vana_rpc.rb` with WebMock stubs in `test/support/vana_test_helper.rb`. RPC URL: `https://rpc.vana.org`. Staking contract: `0x641C18E2F286c86f96CE95C8ec1EB9fC0415Ca0e`.

---

### P2-03: Create Provider::Vanascan

**Tests first** (`test/models/provider/vanascan_test.rb`):
- Fetches account transactions, token transfers
- Handles pagination, API errors, rate limits

**Implementation**: `app/models/provider/vanascan.rb`. Base URL: `https://api.vanascan.io/api` (Blockscout-compatible).

---

### P2-04: VANA Price Feed

**Tests first** (`test/models/provider/vana_price_test.rb`):
- Fetches VANA/USD from CoinGecko, stores in security_prices
- USDC.e defaults to 1.00
- Handles API errors

**Implementation**: `app/models/provider/vana_price.rb`. Seed VANA and USDC.e as securities. Sidekiq-cron schedule.

---

### P2-05: Wallet Sync Job

**Tests first** (`test/jobs/wallet_sync_job_test.rb`):
- Fetches/updates VANA and USDC.e balances
- Creates/updates holdings per token
- Creates daily balance snapshot
- Handles RPC errors without crashing

**Implementation**: `app/jobs/wallet_sync_job.rb` using Syncable pattern. Schedule every 15 min.

---

### P2-06: Wallet Management UI

**Tests first** (`test/controllers/wallets_controller_test.rb`):
- CRUD endpoints for wallets (create with address, show detail, delete)
- Rejects invalid/duplicate addresses
- Requires auth

**Implementation**: Controller + views (address input form, detail page with balances). Routes: `resources :wallets`. Update sidebar.

---

### P2-07: Portfolio Dashboard

Rebuild `PagesController#dashboard` with crypto sections: portfolio value + 24h change, token allocation donut, net worth chart, wallet list with balances.

---

### P2-08: Integration Test — Wallet Sync Flow

End-to-end: sign in → add wallet → stub RPC → sync → verify holdings + balances + dashboard renders.

---

### P3-01: Create StakingPosition Model

**Tests first** (`test/models/staking_position_test.rb`):
- belongs_to account, validates entity_id/shares/status
- Status transitions (active → unstaking → withdrawn)
- Calculates VANA value from shares

**Implementation**: Migration (see Section 6.3 of migration plan), model, account association.

---

### P3-02: Create StakingSnapshot Model

**Tests first** (`test/models/staking_snapshot_test.rb`):
- belongs_to staking_position
- Unique [staking_position_id, date]
- Tracks shares, vana_value, cumulative_rewards, apy

**Implementation**: Migration + model.

---

### P3-03: Staking Contract Reader

**Tests first** (add to `test/models/provider/vana_rpc_test.rb`):
- Reads shares from VanaPoolStaking, calculates value per share, entity info
- Handles zero balance

**Implementation**: Add `fetch_staking_shares`, `fetch_vana_per_share`, `fetch_staking_entity` to `Provider::VanaRpc`.

---

### P3-04: Add Staking to Wallet Sync

**Tests first** (add to `test/jobs/wallet_sync_job_test.rb`):
- Creates/updates staking positions, detects events, creates snapshots, records entries

**Implementation**: Extend WalletSyncJob.

---

### P3-05: Staking Dashboard UI

**Tests first** (`test/controllers/staking_controller_test.rb`):
- GET /staking overview, GET /staking/:id detail, requires auth

**Implementation**: Controller + views. Add "Staking" to nav.

---

### P3-06: Integration Test — Staking Lifecycle

End-to-end: wallet → sync (no staking) → sync (staking detected) → sync (rewards accrued) → verify snapshots + history.

---

### P4-01 through P4-05

See task table above for descriptions. Detailed specs in `docs/vana-migration-plan.md` Sections 3–4.
