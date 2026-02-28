# Vanalytics Implementation Guide

> The single entrypoint for all subagents working on the Vanalytics migration.

---

## Instructions for Subagents

**Before starting any task, you MUST:**

1. **Read `docs/vana-migration-plan.md`** in full — it contains the complete codebase analysis, architecture decisions, Vana blockchain details, and testing strategy.
2. **Read this file** to find the next available task.
3. **Pick the next most important `TODO` task** — tasks are ordered by priority within each phase. Do not skip phases; Phase 1 must be complete before Phase 2.
4. **Check dependencies** — some tasks depend on others. Do not start a task if its dependencies are not `COMPLETE`.
5. **Update status** in this file:
   - Set the task to `IN PROGRESS` when you start work
   - Set the task to `COMPLETE` when finished and tests pass
   - Set the task to `FAILED` with a note if you cannot complete it
6. **Follow TDD** — write failing tests first, then implement. See Section 8 of the migration plan.
7. **Run verification** before marking complete:
   - `bin/rails test` (all tests pass)
   - `bin/rubocop -f github -a` (linting passes)
   - `bin/brakeman --no-pager` (security passes)
8. **Commit atomically** — each task should be one or more focused commits with clear messages.

### Status Legend

| Status | Meaning |
|--------|---------|
| `TODO` | Not started — available to pick up |
| `IN PROGRESS` | A subagent is actively working on this |
| `COMPLETE` | Done, tests pass, committed |
| `FAILED` | Could not complete — see notes |
| `BLOCKED` | Waiting on a dependency or decision |

---

## Phase 1: Strip & Clean (Foundation)

> **Goal**: Remove all non-crypto features. App should boot and remaining tests should pass.

### P1-01: Remove AI Assistant

**Status**: `TODO`
**Priority**: High
**Dependencies**: None
**Estimated files**: ~25

**Description**: Remove the AI assistant feature entirely — models, controllers, views, routes, layout sidebar, and all related tests.

**Files to delete**:
- Models: `app/models/chat.rb`, `app/models/message.rb`, `app/models/tool_call.rb`, `app/models/assistant.rb`, `app/models/assistant_message.rb`, `app/models/developer_message.rb`, `app/models/user_message.rb`, `app/models/llm_usage.rb`, `app/models/vector_store.rb`, and directories `app/models/tool_call/`, `app/models/assistant/`, `app/models/chat/`, `app/models/vector_store/`
- Provider: `app/models/provider/openai.rb`, `app/models/provider/openai/`, `app/models/provider/llm_concept.rb`
- Controllers: `app/controllers/chats_controller.rb`, `app/controllers/messages_controller.rb`, `app/controllers/mcp_controller.rb`
- Views: `app/views/chats/`, `app/views/messages/`
- Tests: `test/controllers/chats_controller_test.rb`, `test/controllers/messages_controller_test.rb`, `test/models/assistant/`, `test/models/eval/`, `test/interfaces/llm_interface_test.rb`, `test/vcr_cassettes/openai/`
- Layout: Remove AI chat sidebar from `app/views/layouts/application.html.erb`

**Files to modify**:
- `config/routes.rb` — remove chat/message routes
- `app/models/family.rb` — remove chat associations
- `app/models/user.rb` — remove chat/message associations
- `Gemfile` — remove `ruby-openai`, `langfuse-ruby`

**Acceptance criteria**:
- [ ] All AI-related files deleted
- [ ] No references to `Chat`, `Message`, `ToolCall`, `Assistant` in remaining code
- [ ] Layout no longer renders AI sidebar
- [ ] `bin/rails test` passes (remaining tests)
- [ ] `bin/rubocop -a` passes
- [ ] App boots without errors

---

### P1-02: Remove Banking Provider Integrations

**Status**: `TODO`
**Priority**: High
**Dependencies**: None
**Estimated files**: ~80

**Description**: Remove all 9 banking/investment/crypto provider integrations (Plaid, SimpleFIN, Enable Banking, Lunchflow, Mercury, Snaptrade, Indexa Capital, Coinbase, CoinStats). These will be replaced by direct on-chain queries in Phase 2.

**Provider stacks to delete** (for each: model directory, item model, account model, controller, views, tests):
1. Plaid (`plaid_item`, `plaid_account`, `plaid_account/`, `plaid_entry/`)
2. SimpleFIN (`simplefin_item`, `simplefin_account`, `simplefin_account/`, `simplefin_entry/`)
3. Enable Banking (`enable_banking_item`, `enable_banking_account`, `enable_banking_account/`, `enable_banking_entry/`)
4. Lunchflow (`lunchflow_item`, `lunchflow_account`, `lunchflow_account/`, `lunchflow_entry/`)
5. Mercury (`mercury_item`, `mercury_account`, `mercury_account/`, `mercury_entry/`)
6. Snaptrade (`snaptrade_item`, `snaptrade_account`, `snaptrade_account/`)
7. Indexa Capital (`indexa_capital_item`, `indexa_capital_account`, `indexa_capital_account/`)
8. Coinbase (`coinbase_item`, `coinbase_account`, `coinbase_account/`)
9. CoinStats (`coinstats_item`, `coinstats_account`, `coinstats_account/`, `coinstats_entry/`)

**Provider adapters to delete** (in `app/models/provider/`):
- `plaid.rb`, `plaid_adapter.rb`, `plaid_eu_adapter.rb`, `plaid_sandbox.rb`
- `simplefin.rb`, `simplefin_adapter.rb`
- `enable_banking.rb`, `enable_banking_adapter.rb`
- `lunchflow.rb`, `lunchflow_adapter.rb`
- `mercury.rb`, `mercury_adapter.rb`
- `snaptrade.rb`, `snaptrade_adapter.rb`
- `indexa_capital.rb`, `indexa_capital_adapter.rb`
- `coinbase.rb`, `coinbase_adapter.rb`
- `coinstats.rb`, `coinstats_adapter.rb`
- `stripe.rb`, `app/models/provider/stripe/`

**Keep** (in `app/models/provider/`):
- `base.rb`, `registry.rb`, `factory.rb`, `configurable.rb`, `syncable.rb`
- `github.rb` (for changelog)
- `exchange_rate_concept.rb`, `security_concept.rb`
- `twelve_data.rb`, `yahoo_finance.rb` (may reuse for price feeds)

**Files to modify**:
- `config/routes.rb` — remove all provider routes
- `app/models/family.rb` — remove provider item associations
- `app/models/account.rb` — remove `create_from_*` methods, `plaid_account_id`, `simplefin_account_id` references
- `Gemfile` — remove `plaid`, `snaptrade`, `stripe`, `omniauth-*`
- `config/initializers/` — remove provider-specific initializers
- `app/models/provider/registry.rb` — remove provider registrations

**Acceptance criteria**:
- [ ] All provider files deleted
- [ ] No references to removed providers in remaining code
- [ ] `bin/rails test` passes
- [ ] `bin/rubocop -a` passes

---

### P1-03: Remove Non-Crypto Account Types

**Status**: `TODO`
**Priority**: High
**Dependencies**: None
**Estimated files**: ~30

**Description**: Remove all account types except `Crypto`: Depository, Investment, Property, Vehicle, CreditCard, Loan, OtherAsset, OtherLiability.

**Files to delete**:
- Models: `depository.rb`, `investment.rb`, `property.rb`, `vehicle.rb`, `credit_card.rb`, `loan.rb`, `other_asset.rb`, `other_liability.rb`, `address.rb`
- Controllers: `depositories_controller.rb`, `investments_controller.rb`, `properties_controller.rb`, `vehicles_controller.rb`, `credit_cards_controller.rb`, `loans_controller.rb`, `other_assets_controller.rb`, `other_liabilities_controller.rb`
- Views: `app/views/depositories/`, `investments/`, `properties/`, `vehicles/`, `credit_cards/`, `loans/`, `other_assets/`, `other_liabilities/`, `investment_activity/`
- Tests: corresponding test files for all above

**Files to modify**:
- `app/models/concerns/accountable.rb` — change `TYPES = %w[Crypto]`
- `app/models/account.rb` — simplify `balance_type` (always `:investment`), remove multi-type logic
- `config/routes.rb` — remove account type routes
- Sidebar views — remove non-crypto account groups

**Acceptance criteria**:
- [ ] `Accountable::TYPES == %w[Crypto]`
- [ ] No references to removed account types in remaining code
- [ ] Sidebar only shows crypto accounts
- [ ] `bin/rails test` passes

---

### P1-04: Remove Budgets, Categories, Merchants, Rules

**Status**: `TODO`
**Priority**: High
**Dependencies**: None
**Estimated files**: ~40

**Description**: Remove the budgeting system, category hierarchy, merchant tracking, and rules engine.

**Feature groups to delete**:
- **Budgets**: `budget.rb`, `budget_category.rb`, controllers, views, tests
- **Categories**: `category.rb`, `category_import.rb`, `category/` namespace controllers/views
- **Merchants**: `merchant.rb`, `family_merchant.rb`, `family_merchant_association.rb`, controllers, views
- **Rules**: `rule.rb`, `rule_import.rb`, `rule_run.rb`, `app/models/rule/`, controllers, views
- **Recurring transactions**: `recurring_transaction.rb`, `app/models/recurring_transaction/`, controllers, views

**Files to modify**:
- `config/routes.rb` — remove budget/category/merchant/rule routes
- `app/models/family.rb` — remove associations
- Navigation — remove "Budgets" menu item
- `app/models/entry.rb` — remove category/merchant associations if present

**Acceptance criteria**:
- [ ] All budget/category/merchant/rule files deleted
- [ ] No references to removed features in remaining code
- [ ] `bin/rails test` passes

---

### P1-05: Remove Transactions, Transfers, Imports/Exports

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: None
**Estimated files**: ~45

**Description**: Remove the full transaction system (keeping entries framework), transfers, and CSV/PDF import system.

**Files to delete**:
- **Transactions**: `app/controllers/transactions_controller.rb`, `app/controllers/transactions/`, `app/controllers/transaction_categories_controller.rb`, `app/views/transactions/`
- **Transaction models**: `app/models/transaction.rb`, `app/models/transaction/` — **CAREFUL**: `Transaction` is an entryable type used by entries. Keep the model class but strip it down, OR remove and ensure entries system works without it.
- **Transfers**: `transfer.rb`, `rejected_transfer.rb`, `transfer_matches_controller.rb`, `transfers_controller.rb`, views
- **Imports**: `import.rb`, `app/models/import/`, all `*_import.rb` models, `imports_controller.rb`, `app/controllers/import/`, `app/views/imports/`, `app/views/import/`
- **Exports**: `family_export.rb`, `family_exports_controller.rb`
- **Reports**: `reports_controller.rb`, `app/views/reports/`, `income_statement.rb`, `investment_statement.rb`, `investment_flow_statement.rb`

**Important note**: The `Entry` model is the core ledger — it uses `entryable` polymorphism for `Transaction`, `Valuation`, and `Trade`. We want to keep `Entry`, `Valuation`, and `Trade` but can simplify or remove `Transaction`. Evaluate carefully whether `Transaction` can be fully removed or needs a stub.

**Files to modify**:
- `config/routes.rb` — remove transaction/transfer/import/report routes
- Navigation — remove "Transactions", "Reports" menu items
- `app/models/entry.rb` — potentially remove Transaction entryable if safe

**Acceptance criteria**:
- [ ] Transaction UI and controllers removed
- [ ] Entries system still works for Valuations and Trades
- [ ] Import/export system removed
- [ ] Navigation simplified
- [ ] `bin/rails test` passes

---

### P1-06: Remove Miscellaneous Features

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: None
**Estimated files**: ~25

**Description**: Remove remaining features not needed for Vanalytics.

**Features to remove**:
- **Subscriptions/billing**: `subscription.rb`, `subscriptions` table
- **Invite codes**: `invite_code.rb`, `invite_codes` table
- **Invitations**: `invitation.rb`, `invitations` table, `invitations_controller.rb`
- **Impersonation**: `impersonation_session.rb`, `impersonation_session_log.rb`, controller
- **Data enrichments**: `data_enrichment.rb`, `data_enrichments` table
- **Family documents**: `family_document.rb`
- **OAuth/Doorkeeper**: Remove Doorkeeper config, OAuth tables
- **Eval system**: `eval_dataset.rb`, `eval_result.rb`, `eval_run.rb`, `eval_sample.rb`, all under `test/models/eval/`
- **Mobile devices**: `mobile_device.rb`
- **SSO**: `sso_provider.rb`, `sso_audit_log.rb`, `oidc_identity.rb`, `oidc_accounts_controller.rb`

**Files to modify**:
- `Gemfile` — remove `doorkeeper`, `omniauth-*`, `stripe`, etc.
- `config/routes.rb` — remove corresponding routes
- `config/initializers/` — remove Doorkeeper, Stripe initializers
- `app/models/user.rb` — remove SSO/OIDC associations
- `app/models/family.rb` — remove subscription/invite associations

**Acceptance criteria**:
- [ ] All listed features removed
- [ ] `bin/rails test` passes
- [ ] `bin/rubocop -a` passes

---

### P1-07: Clean Up Gems and Dependencies

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P1-01, P1-02, P1-06
**Estimated files**: 2 (Gemfile, Gemfile.lock)

**Description**: Remove unused gems after feature removal.

**Gems to remove**:
```
plaid
snaptrade
stripe
doorkeeper
ruby-openai
langfuse-ruby
pdf-reader
omniauth
omniauth-google-oauth2
omniauth-rails_csrf_protection
```

**After removal**:
```bash
bundle install
bin/rails test  # verify nothing breaks
```

**Acceptance criteria**:
- [ ] Unused gems removed from Gemfile
- [ ] `bundle install` succeeds
- [ ] `bin/rails test` passes

---

### P1-08: Database Migration — Drop Removed Tables

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P1-01 through P1-06
**Estimated files**: 1 migration file

**Description**: Create a single migration to drop all tables for removed features (~40 tables). See Section 6.1 of the migration plan for the full list.

**Important**: This migration is irreversible. The `down` method should raise `ActiveRecord::IrreversibleMigration`.

**Test**: Write a migration test or verify via `bin/rails db:migrate` followed by `bin/rails test`.

**Acceptance criteria**:
- [ ] Migration file created
- [ ] `bin/rails db:migrate` succeeds
- [ ] `bin/rails test` passes after migration
- [ ] Schema.rb updated with dropped tables removed

---

### P1-09: Clean Routes and Navigation

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P1-01 through P1-06
**Estimated files**: ~5

**Description**: Clean up `config/routes.rb` to remove all routes for deleted features. Update navigation to show only: Dashboard, Wallets (placeholder), Staking (placeholder).

**Files to modify**:
- `config/routes.rb` — remove ~50 unused resource routes
- `app/views/layouts/application.html.erb` — update navigation
- Any navigation partials/components — simplify menu items

**Acceptance criteria**:
- [ ] `bin/rails routes` shows only active routes
- [ ] Navigation renders without errors
- [ ] No dead links in UI
- [ ] `bin/rails test` passes

---

### P1-10: Verify Clean Build

**Status**: `TODO`
**Priority**: High
**Dependencies**: P1-01 through P1-09
**Estimated files**: 0 (verification only)

**Description**: Final verification that the stripped-down app is clean and functional.

**Verification steps**:
```bash
bin/rails db:prepare
bin/rails test
bin/rails test:system  # if applicable
bin/rubocop -f github -a
bundle exec erb_lint ./app/**/*.erb -a
bin/brakeman --no-pager
```

**Acceptance criteria**:
- [ ] App boots without errors
- [ ] All remaining tests pass
- [ ] Rubocop passes
- [ ] Brakeman reports no critical issues
- [ ] No references to removed features in codebase

---

## Phase 2: Wallet & Balance Tracking (Core Feature)

> **Goal**: Users can paste Vana wallet addresses and see VANA + USDC.e balances.
> **Prerequisite**: All Phase 1 tasks must be `COMPLETE`.

### P2-01: Add Wallet Address to Account Model

**Status**: `TODO`
**Priority**: High
**Dependencies**: Phase 1 complete
**Estimated files**: 3

**Description**: Add `wallet_address` and `chain` columns to the accounts table.

**TDD — write tests first**:
```ruby
# test/models/account/wallet_test.rb
# Test: validates wallet_address format (0x + 40 hex chars)
# Test: enforces unique wallet_address per family
# Test: defaults chain to "vana"
# Test: rejects invalid addresses
```

**Implementation**:
- Migration: `add_column :accounts, :wallet_address, :string` + `add_column :accounts, :chain, :string, default: "vana"`
- Index: `add_index :accounts, [:family_id, :wallet_address], unique: true`
- Model: Add validation to `Account` for wallet_address format
- Remove: `plaid_account_id`, `simplefin_account_id` columns (if not already handled)

**Acceptance criteria**:
- [ ] Tests written and passing (TDD)
- [ ] Migration runs cleanly
- [ ] Wallet address validated (format, uniqueness per family)

---

### P2-02: Create VanaRPC Provider

**Status**: `TODO`
**Priority**: High
**Dependencies**: P2-01
**Estimated files**: 4

**Description**: Build the `Provider::VanaRpc` class to query the Vana L1 blockchain via JSON-RPC.

**TDD — write tests first**:
```ruby
# test/models/provider/vana_rpc_test.rb
# Test: fetches VANA native balance (eth_getBalance)
# Test: converts wei to VANA (18 decimals)
# Test: fetches ERC-20 balance (balanceOf)
# Test: converts USDC.e raw to human (6 decimals)
# Test: fetches staking shares from VanaPoolStaking
# Test: handles RPC error responses
# Test: handles network timeouts
# Test: handles malformed responses
```

**Implementation**:
- Create `app/models/provider/vana_rpc.rb`
- Create `test/support/vana_test_helper.rb` (WebMock stubs)
- Register in `Provider::Registry` (if applicable)
- Environment config: `VANA_RPC_URL` (default: `https://rpc.vana.org`)

**Key contract addresses** (from migration plan Section 5.2):
- VanaPoolStaking: `0x641C18E2F286c86f96CE95C8ec1EB9fC0415Ca0e`
- USDC.e: verify on vanascan.io/tokens

**Acceptance criteria**:
- [ ] All unit tests pass with WebMock stubs
- [ ] Correctly converts wei to VANA (18 decimals)
- [ ] Correctly converts USDC.e raw to human (6 decimals)
- [ ] Graceful error handling (no crashes on RPC failures)

---

### P2-03: Create Vanascan API Provider

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P2-02
**Estimated files**: 3

**Description**: Build `Provider::Vanascan` to query the Vanascan explorer API (Blockscout-compatible) for transaction history and token transfers.

**TDD — write tests first**:
```ruby
# test/models/provider/vanascan_test.rb
# Test: fetches account transactions
# Test: fetches token transfers
# Test: handles pagination
# Test: handles API errors and rate limits
```

**Implementation**:
- Create `app/models/provider/vanascan.rb`
- Base URL: `https://api.vanascan.io/api`
- Methods: `get_balance`, `get_token_balance`, `get_transactions`, `get_token_transfers`

**Acceptance criteria**:
- [ ] All unit tests pass with WebMock stubs
- [ ] API responses parsed correctly

---

### P2-04: VANA Price Feed Integration

**Status**: `TODO`
**Priority**: High
**Dependencies**: P2-02
**Estimated files**: 3

**Description**: Integrate VANA/USD price feed for portfolio valuation.

**TDD — write tests first**:
```ruby
# test/models/provider/vana_price_test.rb
# Test: fetches VANA/USD price
# Test: stores price in security_prices table
# Test: handles API errors
# Test: USDC.e price defaults to 1.00
```

**Implementation**:
- Create `app/models/provider/vana_price.rb` (CoinGecko API or existing Yahoo Finance)
- Seed VANA and USDC.e as securities
- Schedule price refresh via Sidekiq-cron

**Acceptance criteria**:
- [ ] VANA price fetched and stored
- [ ] USDC.e price stored as 1.00
- [ ] Price history builds over time

---

### P2-05: Wallet Sync Job

**Status**: `TODO`
**Priority**: High
**Dependencies**: P2-02, P2-04
**Estimated files**: 4

**Description**: Build `WalletSyncJob` that fetches balances from Vana RPC and updates holdings/balances.

**TDD — write tests first**:
```ruby
# test/jobs/wallet_sync_job_test.rb
# Test: fetches and updates VANA balance
# Test: fetches and updates USDC.e balance
# Test: creates/updates holdings for each token
# Test: creates daily balance snapshot
# Test: handles RPC errors without crashing
# Test: handles partial failures gracefully
```

**Implementation**:
- Create `app/jobs/wallet_sync_job.rb`
- Use existing `Syncable` concern pattern
- Flow: fetch balances → update holdings → snapshot balance → update account balance
- Schedule: every 15 minutes via Sidekiq-cron

**Acceptance criteria**:
- [ ] All tests pass
- [ ] Holdings created/updated for VANA and USDC.e
- [ ] Balance snapshots created
- [ ] Account balance updated to reflect current value
- [ ] Errors logged but don't crash the job

---

### P2-06: Wallet Management UI

**Status**: `TODO`
**Priority**: High
**Dependencies**: P2-01, P2-05
**Estimated files**: ~8

**Description**: Build the wallet management UI — add wallet form, wallet list, wallet detail page.

**TDD — write tests first**:
```ruby
# test/controllers/wallets_controller_test.rb
# Test: GET /wallets/new renders form
# Test: POST /wallets creates wallet with valid address
# Test: POST /wallets rejects invalid address
# Test: POST /wallets rejects duplicate address
# Test: GET /wallets/:id shows wallet detail
# Test: DELETE /wallets/:id removes wallet
# Test: requires authentication
```

**Implementation**:
- Controller: reuse/rename `CryptosController` or create new `WalletsController`
- Views: new wallet form (address input), wallet detail (balances, holdings)
- Routes: `resources :wallets`
- Sidebar: update to list wallets with balance sparklines

**Acceptance criteria**:
- [ ] Controller tests pass
- [ ] Can add wallet by pasting address
- [ ] Invalid addresses rejected with error message
- [ ] Wallet detail shows VANA + USDC.e balances
- [ ] Wallet appears in sidebar

---

### P2-07: Portfolio Dashboard

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P2-05, P2-06
**Estimated files**: ~6

**Description**: Rebuild the dashboard for crypto portfolio overview.

**Implementation**:
- Update `PagesController#dashboard` to show crypto-specific data
- Sections:
  1. **Portfolio Overview**: total value in USD, 24h change
  2. **Token Allocation**: donut chart (VANA vs USDC.e vs Staked VANA)
  3. **Net Worth Chart**: reuse existing time series chart
  4. **Wallet List**: per-wallet breakdown with balances

**Acceptance criteria**:
- [ ] Dashboard renders without errors
- [ ] Portfolio value calculated correctly
- [ ] Charts display with real data
- [ ] Works with 0, 1, and multiple wallets

---

### P2-08: Integration Test — Wallet Sync Flow

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P2-05, P2-06
**Estimated files**: 1

**Description**: Write the end-to-end integration test for the wallet sync flow (see Section 8.5 of migration plan).

**Test flow**:
1. Sign in → POST wallet → stub RPC → run sync → verify holdings + balances → verify dashboard

**Acceptance criteria**:
- [ ] Integration test passes
- [ ] Covers full user flow from adding wallet to seeing balances

---

## Phase 3: Staking Integration (Key Differentiator)

> **Goal**: Track staking positions with full history, rewards, and APY.
> **Prerequisite**: All Phase 2 tasks must be `COMPLETE`.

### P3-01: Create Staking Position Model

**Status**: `TODO`
**Priority**: High
**Dependencies**: Phase 2 complete
**Estimated files**: 3

**Description**: Create `StakingPosition` model and migration.

**TDD — write tests first**:
```ruby
# test/models/staking_position_test.rb
# Test: belongs_to account
# Test: validates required fields (entity_id, shares, status)
# Test: status transitions (active → unstaking → withdrawn)
# Test: calculates VANA value from shares
# Test: tracks rewards earned
```

**Implementation**:
- Migration: create `staking_positions` table (see Section 6.3 of migration plan)
- Model: `app/models/staking_position.rb`
- Associations: `Account has_many :staking_positions`

**Acceptance criteria**:
- [ ] Model tests pass
- [ ] Migration runs cleanly
- [ ] Associations work correctly

---

### P3-02: Create Staking Snapshot Model

**Status**: `TODO`
**Priority**: High
**Dependencies**: P3-01
**Estimated files**: 3

**Description**: Create `StakingSnapshot` model for historical tracking.

**TDD — write tests first**:
```ruby
# test/models/staking_snapshot_test.rb
# Test: belongs_to staking_position
# Test: enforces unique [staking_position_id, date]
# Test: tracks shares, vana_value, cumulative_rewards, apy
```

**Implementation**:
- Migration: create `staking_snapshots` table (see Section 6.3 of migration plan)
- Model: `app/models/staking_snapshot.rb`

**Acceptance criteria**:
- [ ] Model tests pass
- [ ] Unique index enforced

---

### P3-03: Staking Contract Reader

**Status**: `TODO`
**Priority**: High
**Dependencies**: P2-02, P3-01
**Estimated files**: 2

**Description**: Add staking contract read methods to `Provider::VanaRpc`.

**TDD — write tests first**:
```ruby
# Additional tests in test/models/provider/vana_rpc_test.rb
# Test: reads shares balance from VanaPoolStaking contract
# Test: calculates VANA value per share
# Test: identifies which entity/validator the stake is delegated to
# Test: handles zero staking balance
```

**Implementation**:
- Add methods to `Provider::VanaRpc`:
  - `fetch_staking_shares(address)` — balanceOf on staking contract
  - `fetch_vana_per_share()` — derive from contract state
  - `fetch_staking_entity(address)` — entity delegation info

**Acceptance criteria**:
- [ ] Tests pass with WebMock stubs
- [ ] Correctly reads staking data from contract

---

### P3-04: Add Staking to Wallet Sync

**Status**: `TODO`
**Priority**: High
**Dependencies**: P2-05, P3-01, P3-03
**Estimated files**: 2

**Description**: Extend `WalletSyncJob` to also sync staking positions.

**TDD — write tests first**:
```ruby
# Additional tests in test/jobs/wallet_sync_job_test.rb
# Test: creates new staking position when shares detected
# Test: updates existing staking position on re-sync
# Test: detects unstaking (shares decreased)
# Test: calculates rewards earned (value increased, shares same)
# Test: creates daily staking snapshot
# Test: creates staking event entries (Trade entryable)
```

**Implementation**:
- Extend `WalletSyncJob` to:
  1. Query staking shares
  2. Create/update `StakingPosition`
  3. Create `StakingSnapshot` for the day
  4. Detect stake/unstake events and create entries

**Acceptance criteria**:
- [ ] Tests pass
- [ ] Staking positions synced correctly
- [ ] Daily snapshots created
- [ ] Staking events detected and recorded

---

### P3-05: Staking Dashboard UI

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P3-04
**Estimated files**: ~6

**Description**: Build the staking dashboard and detail views.

**TDD — write tests first**:
```ruby
# test/controllers/staking_controller_test.rb
# Test: GET /staking shows staking overview
# Test: GET /staking/:id shows position detail
# Test: requires authentication
```

**Implementation**:
- Controller: `app/controllers/staking_controller.rb`
- Views:
  - Staking overview: total staked, total rewards, current APY
  - Position detail: entity name, shares, value, reward history chart
- Routes: `resources :staking, only: [:index, :show]`
- Add "Staking" to navigation

**Acceptance criteria**:
- [ ] Controller tests pass
- [ ] Staking overview renders with positions
- [ ] Position detail shows history and rewards
- [ ] APY displayed correctly

---

### P3-06: Integration Test — Staking Lifecycle

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P3-04, P3-05
**Estimated files**: 1

**Description**: Write the end-to-end staking lifecycle integration test (see Section 8.5 of migration plan).

**Test flow**:
1. Create wallet → sync (no staking) → sync again (staking detected) → sync again (rewards accrued) → verify snapshots and history

**Acceptance criteria**:
- [ ] Integration test passes
- [ ] Full staking lifecycle verified

---

## Phase 4: Dashboard & UX Polish

> **Goal**: Polished, crypto-native experience.
> **Prerequisite**: All Phase 3 tasks must be `COMPLETE`.

### P4-01: Rebrand to Vanalytics

**Status**: `TODO`
**Priority**: High
**Dependencies**: Phase 3 complete
**Estimated files**: ~10

**Description**: Update branding throughout the app — name, logos, colors, meta tags, email templates.

**Files to modify**:
- `app/views/layouts/application.html.erb` — title, meta tags
- `config/application.rb` — app name
- `app/assets/images/` — logos
- `config/locales/en.yml` — app name references
- Email templates — branding

**Acceptance criteria**:
- [ ] All user-visible references say "Vanalytics" not "Sure"
- [ ] Logo updated
- [ ] Tests pass

---

### P4-02: Update i18n for Crypto Context

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: Phase 3 complete
**Estimated files**: ~5

**Description**: Update all i18n strings to use crypto terminology.

**Examples**:
- "Net worth" → "Portfolio value"
- "Accounts" → "Wallets"
- "New account" → "Add wallet"
- "Balance sheet" → "Portfolio"
- "Assets" / "Liabilities" → just "Tokens" / "Staking"

**Acceptance criteria**:
- [ ] All user-facing strings use crypto terminology
- [ ] No finance-specific language remaining

---

### P4-03: Simplified Onboarding

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P2-06
**Estimated files**: ~4

**Description**: Simplify the onboarding flow to: "Add your first Vana wallet".

**Implementation**:
- New onboarding view with wallet address input
- Skip multi-step account type selection
- Auto-trigger sync after adding first wallet

**Acceptance criteria**:
- [ ] New user sees "Add your first Vana wallet" prompt
- [ ] Single step to start tracking

---

### P4-04: Portfolio Performance Analytics

**Status**: `TODO`
**Priority**: Low
**Dependencies**: P2-07, P3-05
**Estimated files**: ~4

**Description**: Add portfolio performance analytics — ROI, time-weighted returns, performance vs VANA price.

**Implementation**:
- Calculate portfolio performance from balance snapshots
- Compare portfolio value change vs VANA price change
- Display in dashboard section

**Acceptance criteria**:
- [ ] Portfolio ROI calculated correctly
- [ ] Comparison chart renders

---

### P4-05: Integration Test — Portfolio Valuation

**Status**: `TODO`
**Priority**: Medium
**Dependencies**: P2-07, P3-05
**Estimated files**: 1

**Description**: Write the portfolio valuation integration test (see Section 8.5 of migration plan).

**Test flow**:
- Multi-wallet portfolio → VANA + USDC.e + staked VANA → total value correct → price change → value updates

**Acceptance criteria**:
- [ ] Integration test passes
- [ ] Multi-wallet aggregation correct

---

## Phase 5: Enhanced Features (Future)

> **Goal**: Power user features. These are optional and can be prioritized later.

### P5-01: On-Chain Activity Feed

**Status**: `TODO`
**Priority**: Low
**Dependencies**: P2-03
**Description**: Display transaction history from Vanascan API as an activity feed.

### P5-02: Token Price Alerts

**Status**: `TODO`
**Priority**: Low
**Dependencies**: P2-04
**Description**: Notify user when VANA price crosses a threshold.

### P5-03: DLP Tracking

**Status**: `TODO`
**Priority**: Low
**Dependencies**: Phase 3 complete
**Description**: Track Data Liquidity Pool positions on Vana.

### P5-04: CSV Portfolio Export

**Status**: `TODO`
**Priority**: Low
**Dependencies**: Phase 2 complete
**Description**: Export portfolio data as CSV for tax/reporting purposes.

### P5-05: Multi-Chain Support

**Status**: `TODO`
**Priority**: Low
**Dependencies**: Phase 2 complete
**Description**: Support additional EVM chains beyond Vana L1.

---

## Task Dependency Graph

```
Phase 1 (all can run in parallel):
  P1-01 ─┐
  P1-02 ─┤
  P1-03 ─┼─→ P1-07 (gems) ─→ P1-08 (migration) ─→ P1-09 (routes) ─→ P1-10 (verify)
  P1-04 ─┤
  P1-05 ─┤
  P1-06 ─┘

Phase 2 (sequential):
  P2-01 ─→ P2-02 ─→ P2-04 ─→ P2-05 ─→ P2-06 ─→ P2-07 ─→ P2-08
                 └─→ P2-03

Phase 3 (sequential):
  P3-01 ─→ P3-02
       └─→ P3-03 ─→ P3-04 ─→ P3-05 ─→ P3-06

Phase 4 (mostly parallel):
  P4-01, P4-02, P4-03 (parallel)
  P4-04 ─→ P4-05
```
