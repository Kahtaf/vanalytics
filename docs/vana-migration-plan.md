# Vanalytics Migration Plan

> Transforming a full-featured personal finance app into a Vana L1 crypto tracking tool.

**Source**: Fork of [we-promise/sure](https://github.com/we-promise/sure) — a Rails 7.2 / Hotwire / PostgreSQL personal finance application.

**Goal**: Strip non-crypto features and build a focused app for tracking wallet balances ($VANA, $USDC.e), staking positions, and portfolio history on the Vana L1 blockchain.

---

## Table of Contents

1. [Current State Inventory](#1-current-state-inventory)
2. [Features to Remove](#2-features-to-remove)
3. [Features to Keep & Adapt](#3-features-to-keep--adapt)
4. [New Vana-Specific Features](#4-new-vana-specific-features)
5. [Vana Blockchain Integration Details](#5-vana-blockchain-integration-details)
6. [Database Migration Plan](#6-database-migration-plan)
7. [Phased Roadmap](#7-phased-roadmap)

---

## 1. Current State Inventory

### Scale
| Component | Count |
|-----------|-------|
| Database tables | 88 |
| Models | 104 |
| Controllers | 61 |
| Stimulus controllers | 62 |
| ViewComponents | ~15 |
| View directories | 48 |

### Account Types (8 via delegated_type)

```ruby
# app/models/concerns/accountable.rb
TYPES = %w[Depository Investment Crypto Property Vehicle OtherAsset CreditCard Loan OtherLiability]
```

| Type | Classification | Purpose | Keep? |
|------|---------------|---------|-------|
| `Depository` | asset | Checking, savings | **Remove** |
| `Investment` | asset | 401k, IRA, brokerage (54+ subtypes) | **Remove** |
| `Crypto` | asset | Wallet / Exchange | **Keep & adapt** |
| `Property` | asset | Real estate | **Remove** |
| `Vehicle` | asset | Cars | **Remove** |
| `OtherAsset` | asset | Generic assets | **Remove** |
| `CreditCard` | liability | Credit cards | **Remove** |
| `Loan` | liability | Mortgages, student loans | **Remove** |
| `OtherLiability` | liability | Generic liabilities | **Remove** |

### Provider Integrations (9 total)

| Provider | Type | Purpose | Keep? |
|----------|------|---------|-------|
| Plaid | Banking | Bank account sync | **Remove** |
| SimpleFIN | Banking | Alternative bank sync | **Remove** |
| Enable Banking | Banking | European open banking | **Remove** |
| Lunchflow | Banking | Small business banking | **Remove** |
| Mercury | Banking | Business banking | **Remove** |
| Snaptrade | Investment | Multi-brokerage sync | **Remove** |
| Indexa Capital | Investment | Robo-advisor sync | **Remove** |
| Coinbase | Crypto | Exchange API | **Remove** (replaced by on-chain tracking) |
| CoinStats | Crypto | Multi-wallet aggregation | **Remove** (replaced by on-chain tracking) |

### Major Feature Areas

| Feature | Files Involved | Keep? |
|---------|---------------|-------|
| Balance sheet / net worth | `balance_sheet.rb`, dashboard partials | **Keep & adapt** (→ portfolio view) |
| Holdings & securities | `holding.rb`, `security.rb`, `security_prices` | **Keep & adapt** (→ VANA/USDC tracking) |
| Trades | `trade.rb`, entries system | **Keep & adapt** (→ staking events) |
| Transactions | `transaction.rb`, categories, merchants, rules | **Remove** (simplify to on-chain events) |
| Budgets | `budget.rb`, `budget_category.rb` | **Remove** |
| Categories | `category.rb`, hierarchical tree | **Remove** |
| Merchants | `merchant.rb`, `family_merchant.rb` | **Remove** |
| Rules engine | `rule.rb`, conditions, actions | **Remove** |
| Recurring transactions | `recurring_transaction.rb` | **Remove** |
| CSV/PDF imports | `import.rb`, import wizard | **Remove** |
| AI assistant | `chat.rb`, `message.rb`, `tool_call.rb` | **Remove** |
| Reports | `reports_controller.rb`, chart views | **Remove** (replace with crypto dashboard) |
| Transfers | `transfer.rb` | **Remove** |
| User/family system | `user.rb`, `family.rb`, auth | **Keep** |
| API (v1) | `api/v1/*` controllers | **Keep & simplify** |
| Admin | `admin/*` | **Keep** |
| Onboarding | `onboarding` views | **Adapt** (→ wallet address input) |

---

## 2. Features to Remove

### 2.1 Account Types to Remove

**Models** (delete entirely):
- `app/models/depository.rb`
- `app/models/investment.rb`
- `app/models/property.rb`
- `app/models/vehicle.rb`
- `app/models/credit_card.rb`
- `app/models/loan.rb`
- `app/models/other_asset.rb`
- `app/models/other_liability.rb`

**Controllers** (delete entirely):
- `app/controllers/depositories_controller.rb`
- `app/controllers/investments_controller.rb`
- `app/controllers/properties_controller.rb`
- `app/controllers/vehicles_controller.rb`
- `app/controllers/credit_cards_controller.rb`
- `app/controllers/loans_controller.rb`
- `app/controllers/other_assets_controller.rb`
- `app/controllers/other_liabilities_controller.rb`

**Views** (delete directories):
- `app/views/depositories/`
- `app/views/investments/`
- `app/views/properties/`
- `app/views/vehicles/`
- `app/views/credit_cards/`
- `app/views/loans/`
- `app/views/other_assets/`
- `app/views/other_liabilities/`

**Database tables** (migration to drop):
- `depositories`
- `investments`
- `properties`
- `vehicles`
- `credit_cards`
- `loans`
- `other_assets`
- `other_liabilities`
- `addresses` (used by properties)

**Update `Accountable::TYPES`**:
```ruby
# Before
TYPES = %w[Depository Investment Crypto Property Vehicle OtherAsset CreditCard Loan OtherLiability]

# After
TYPES = %w[Crypto]
```

### 2.2 Provider Integrations to Remove

**Complete provider stacks to delete** (model + item + account + entry + controller + views + routes):

| Provider | Models | Controller | Views |
|----------|--------|------------|-------|
| Plaid | `plaid_item.rb`, `plaid_account.rb`, `plaid_account/`, `plaid_entry/` | `plaid_items_controller.rb` | `app/views/plaid_items/` |
| SimpleFIN | `simplefin_item.rb`, `simplefin_account.rb`, `simplefin_account/`, `simplefin_entry/` | `simplefin_items_controller.rb` | `app/views/simplefin_items/` |
| Enable Banking | `enable_banking_item.rb`, `enable_banking_account.rb`, `enable_banking_account/`, `enable_banking_entry/` | `enable_banking_items_controller.rb` | `app/views/enable_banking_items/` |
| Lunchflow | `lunchflow_item.rb`, `lunchflow_account.rb`, `lunchflow_account/`, `lunchflow_entry/` | `lunchflow_items_controller.rb` | `app/views/lunchflow_items/` |
| Mercury | `mercury_item.rb`, `mercury_account.rb`, `mercury_account/`, `mercury_entry/` | `mercury_items_controller.rb` | `app/views/mercury_items/` |
| Snaptrade | `snaptrade_item.rb`, `snaptrade_account.rb`, `snaptrade_account/` | `snaptrade_items_controller.rb` | `app/views/snaptrade_items/` |
| Indexa Capital | `indexa_capital_item.rb`, `indexa_capital_account.rb`, `indexa_capital_account/` | `indexa_capital_items_controller.rb` | `app/views/indexa_capital_items/` |
| Coinbase | `coinbase_item.rb`, `coinbase_account.rb`, `coinbase_account/` | `coinbase_items_controller.rb` | `app/views/coinbase_items/` |
| CoinStats | `coinstats_item.rb`, `coinstats_account.rb`, `coinstats_account/`, `coinstats_entry/` | `coinstats_items_controller.rb` | `app/views/coinstats_items/` |

**Provider adapter layer** (in `app/models/provider/`):
- Remove: `plaid.rb`, `plaid_adapter.rb`, `plaid_eu_adapter.rb`, `plaid_sandbox.rb`, `simplefin.rb`, `simplefin_adapter.rb`, `enable_banking.rb`, `enable_banking_adapter.rb`, `lunchflow.rb`, `lunchflow_adapter.rb`, `mercury.rb`, `mercury_adapter.rb`, `snaptrade.rb`, `snaptrade_adapter.rb`, `indexa_capital.rb`, `indexa_capital_adapter.rb`, `coinbase.rb`, `coinbase_adapter.rb`, `coinstats.rb`, `coinstats_adapter.rb`
- Keep: `base.rb`, `registry.rb`, `factory.rb`, `configurable.rb`, `syncable.rb`, `github.rb`

**Database tables to drop** (18 tables):
- `plaid_items`, `plaid_accounts`
- `simplefin_items`, `simplefin_accounts`
- `enable_banking_items`, `enable_banking_accounts`
- `lunchflow_items`, `lunchflow_accounts`
- `mercury_items`, `mercury_accounts`
- `snaptrade_items`, `snaptrade_accounts`
- `indexa_capital_items`, `indexa_capital_accounts`
- `coinbase_items`, `coinbase_accounts`
- `coinstats_items`, `coinstats_accounts`

### 2.3 Financial Features to Remove

**Budgets**:
- Models: `budget.rb`, `budget_category.rb`
- Controller: `budgets_controller.rb`, `budget_categories_controller.rb`
- Views: `app/views/budgets/`
- Tables: `budgets`, `budget_categories`
- Navigation: Remove "Budgets" from desktop/mobile nav in `app/views/layouts/application.html.erb`

**Categories**:
- Models: `category.rb`, `category_import.rb`
- Controller: `categories_controller.rb`, `category/` namespace
- Views: `app/views/categories/`, `app/views/category/`
- Table: `categories` (evaluate — may keep simplified version for tagging trades)

**Merchants**:
- Models: `merchant.rb`, `family_merchant.rb`, `family_merchant_association.rb`, `provider_merchant.rb`
- Controller: `family_merchants_controller.rb`
- Views: `app/views/family_merchants/`
- Tables: `merchants`, `family_merchant_associations`

**Rules Engine**:
- Models: `rule.rb`, `rule_import.rb`, `rule_run.rb`, `app/models/rule/`
- Controller: `rules_controller.rb`
- Views: `app/views/rules/`
- Tables: `rules`, `rule_actions`, `rule_conditions`, `rule_runs`

**Recurring Transactions**:
- Models: `recurring_transaction.rb`, `app/models/recurring_transaction/`
- Controller: `recurring_transactions_controller.rb`
- Views: `app/views/recurring_transactions/`
- Table: `recurring_transactions`

**Transfers**:
- Models: `transfer.rb`, `rejected_transfer.rb`
- Controller: `transfers_controller.rb`, `transfer_matches_controller.rb`
- Views: `app/views/transfers/`
- Tables: `transfers`, `rejected_transfers`

**CSV/PDF Imports**:
- Models: `import.rb`, `app/models/import/`, `transaction_import.rb`, `trade_import.rb`, `account_import.rb`, `category_import.rb`, `rule_import.rb`, `mint_import.rb`, `pdf_import.rb`
- Controller: `imports_controller.rb`, `app/controllers/import/`
- Views: `app/views/imports/`, `app/views/import/`
- Tables: `imports`, `import_rows`, `import_mappings`

**AI Assistant**:
- Models: `chat.rb`, `assistant.rb`, `assistant_message.rb`, `developer_message.rb`, `user_message.rb`, `message.rb`, `tool_call.rb`, `app/models/tool_call/`, `app/models/assistant/`, `app/models/chat/`, `llm_usage.rb`, `vector_store.rb`, `app/models/vector_store/`
- Controller: `chats_controller.rb`, `messages_controller.rb`, `mcp_controller.rb`
- Views: `app/views/chats/`
- Tables: `chats`, `messages`, `tool_calls`, `llm_usages`
- Layout: Remove right sidebar (AI chat) from `app/views/layouts/application.html.erb`
- Provider models: `app/models/provider/openai.rb`, `app/models/provider/openai/`, `app/models/provider/llm_concept.rb`

**Reports** (remove, replaced by crypto dashboard):
- Controller: `reports_controller.rb`
- Views: `app/views/reports/`
- Models: `income_statement.rb`, `app/models/income_statement/`, `investment_statement.rb`, `app/models/investment_statement/`, `investment_flow_statement.rb`
- Navigation: Remove "Reports" from nav

**Transactions** (simplify — remove full transaction system, keep entries for on-chain events):
- Controller: `transactions_controller.rb`, `app/controllers/transactions/`, `transaction_categories_controller.rb`
- Views: `app/views/transactions/` (rebuild simplified version)
- Models: `transaction.rb`, `app/models/transaction/`, `entry_search.rb`, `transaction_import.rb`
- Navigation: Remove or rename "Transactions" → "Activity"

**Other removals**:
- `data_enrichment.rb`, `data_enrichments` table
- `subscription.rb`, `subscriptions` table (no paywall)
- `invite_code.rb`, `invite_codes` table
- `invitation.rb`, `invitations` table (single-user focus initially)
- `impersonation_session.rb`, `impersonation_session_log.rb` and related tables
- `family_export.rb`, `family_exports` table
- `family_document.rb`, `family_documents` table
- OAuth/Doorkeeper tables: `oauth_access_grants`, `oauth_access_tokens`, `oauth_applications`
- Eval tables: `eval_datasets`, `eval_results`, `eval_runs`, `eval_samples`
- `mobile_devices` table
- `sso_providers`, `sso_audit_logs`, `oidc_identities` tables (simplify auth)

### 2.4 Gems to Remove

```
plaid               # Bank sync
snaptrade           # Investment sync
omniauth-*          # SSO providers (unless keeping Google login)
stripe              # Payments/subscription
doorkeeper          # OAuth2 provider
ruby-openai         # AI assistant
langfuse-ruby       # LLM monitoring
skylight            # APM (managed service)
posthog             # Analytics (managed service)
pdf-reader          # PDF import
rswag               # OpenAPI docs (simplify)
```

### 2.5 Stimulus Controllers to Remove

- `budget_form_controller.js`
- `plaid_controller.js`
- `lunchflow_preload_controller.js`
- `rules_controller.js`, `rule/conditions_controller.js`, `rule/actions_controller.js`
- `sankey_chart_controller.js` (cashflow-specific)
- `category_controller.js`
- `transfer_match_controller.js`
- `cashflow_expand_controller.js`
- `import_controller.js`
- `chat_controller.js`
- `drag_and_drop_import_controller.js`
- `convert_to_trade_controller.js`
- `cost_basis_form_controller.js`
- `activity_label_quick_edit_controller.js`

---

## 3. Features to Keep & Adapt

### 3.1 Core Infrastructure (keep as-is)

| Component | Files | Notes |
|-----------|-------|-------|
| Rails framework | `Gemfile`, `config/` | Rails 7.2, keep Hotwire stack |
| PostgreSQL | `config/database.yml` | Keep existing DB setup |
| Sidekiq | `config/sidekiq.yml` | Background jobs for sync |
| User auth | `user.rb`, `session.rb`, sessions controller | Keep session-based auth |
| Family model | `family.rb` | Repurpose as "workspace" |
| Design system | `app/assets/tailwind/maybe-design-system.css` | Keep Tailwind + tokens |
| ViewComponents | `app/components/` DS namespace | Keep design system components |

### 3.2 Account System (adapt)

**`app/models/account.rb`** — Keep but simplify:
- Remove delegated_type variety (only `Crypto` remains)
- Simplify `balance_type` method (always `:investment`)
- Remove `create_from_simplefin_account`, `create_from_enable_banking_account`, `create_from_coinbase_account`
- Add `wallet_address` field (new migration)
- Add `chain` field (default: "vana")

**`app/models/crypto.rb`** — Keep and extend:
- Change subtypes from `wallet`/`exchange` to `vana_wallet` (or just remove subtypes)
- Add staking-related methods

**`app/controllers/accounts_controller.rb`** — Simplify:
- Remove multi-type account creation flow
- New flow: paste wallet address → auto-detect balances

### 3.3 Holdings & Securities (adapt)

**`app/models/holding.rb`** — Keep for tracking token balances:
- Each wallet will have holdings for VANA (native) and USDC.e (ERC-20)
- Staked VANA tracked as a separate holding type
- Historical balance snapshots preserved

**`app/models/security.rb`** — Keep for token definitions:
- Pre-seed with VANA and USDC.e token records
- Security prices track VANA/USD and USDC.e/USD

**`app/models/security_prices`** — Keep:
- Store VANA price history for portfolio valuation

### 3.4 Balance Tracking (adapt)

**`app/models/balance.rb`** — Keep:
- Daily balance snapshots per wallet
- Used for net worth chart over time

**`app/models/balance_sheet.rb`** — Simplify:
- Remove liabilities (no debt tracking)
- Assets only = VANA balance + USDC.e balance + staked VANA
- Net worth = sum of all wallet balances in USD

### 3.5 Dashboard (rebuild)

**`app/controllers/pages_controller.rb`** — Rebuild `dashboard` action:

Replace 5 current sections:
- ~~Cashflow Sankey~~ → **Portfolio Overview** (total value, VANA price, 24h change)
- ~~Outflows Donut~~ → **Token Allocation** (VANA vs USDC.e vs Staked VANA donut)
- ~~Investment Summary~~ → **Staking Summary** (total staked, rewards earned, APY)
- **Net Worth Chart** → Keep (portfolio value over time)
- ~~Balance Sheet~~ → **Wallet Balances** (per-wallet breakdown)

### 3.6 Existing Patterns to Reuse

| Pattern | Current Location | Reuse For |
|---------|-----------------|-----------|
| Syncable concern | `app/models/concerns/syncable.rb` | Vana wallet sync jobs |
| Provider base | `app/models/provider/base.rb` | New VanaRPC provider |
| Background sync | `SyncJob`, Sidekiq | Periodic wallet balance refresh |
| Time series charts | `time_series_chart_controller.js` | Portfolio value chart |
| Donut charts | `donut_chart_controller.js` | Token allocation chart |
| Sparkline charts | `accountable_sparklines_controller.rb` | Wallet balance sparklines |
| Balance snapshots | `app/models/balance/` | Daily wallet snapshots |
| Holding syncer | `app/models/holding/` | Token balance tracking |
| Period helper | `app/models/period.rb` | Time period selection |
| Money formatting | `Monetizable` concern | USD value display |
| Account sidebar | `app/views/accounts/_account_sidebar_tabs.html.erb` | Wallet list sidebar |

### 3.7 Navigation (adapt)

**Current nav items**: Home, Transactions, Reports, Budgets, Assistant

**New nav items**:
- **Dashboard** (portfolio overview)
- **Wallets** (wallet list & details)
- **Staking** (staking positions & history)
- **Activity** (on-chain events feed — optional, Phase 2+)

Remove right sidebar (AI assistant) entirely.

---

## 4. New Vana-Specific Features

### 4.1 Wallet Address Management

**User flow**: Paste a Vana L1 wallet address → app queries on-chain balances → displays portfolio.

**New model**: Repurpose `Account` with new fields:
```ruby
# New migration
add_column :accounts, :wallet_address, :string
add_column :accounts, :chain, :string, default: "vana"
add_index :accounts, [:family_id, :wallet_address], unique: true
```

**Controller flow**:
```
GET  /wallets/new          → Form with wallet address input
POST /wallets              → Validate address, create account, trigger sync
GET  /wallets/:id          → Wallet detail (balances, staking, history)
DELETE /wallets/:id        → Remove wallet tracking
```

### 4.2 On-Chain Balance Queries

**New provider**: `app/models/provider/vana_rpc.rb`

Query VANA native balance:
```ruby
# eth_getBalance via Vana RPC
def fetch_vana_balance(address)
  # POST https://rpc.vana.org
  # { "jsonrpc": "2.0", "method": "eth_getBalance", "params": [address, "latest"], "id": 1 }
  # Returns balance in wei → convert to VANA (18 decimals)
end
```

Query USDC.e balance (ERC-20):
```ruby
# eth_call with balanceOf(address) on USDC.e contract
def fetch_usdc_balance(address)
  # POST https://rpc.vana.org
  # { "method": "eth_call", "params": [{ "to": USDC_CONTRACT, "data": balanceOf_calldata }, "latest"] }
  # Returns balance → convert with 6 decimals
end
```

### 4.3 Staking Position Tracking

**Staking contract**: `0x641C18E2F286c86f96CE95C8ec1EB9fC0415Ca0e` (VanaPoolStaking)

**Data to query**:
- Shares owned by address: `balanceOf(address)` on the staking contract
- Value per share: derive from contract state (total VANA / total shares)
- Staked VANA value = shares × value per share
- Entity/validator the stake is delegated to

**New model**: `app/models/staking_position.rb`
```ruby
class StakingPosition < ApplicationRecord
  belongs_to :account

  # Fields: entity_id, entity_name, shares, vana_value, rewards_earned,
  #         staked_at, unstaked_at, status (active/unstaking/withdrawn)
end
```

**New table**: `staking_positions`
```ruby
create_table :staking_positions do |t|
  t.references :account, null: false, foreign_key: true, type: :uuid
  t.string :entity_id              # Validator/entity ID
  t.string :entity_name            # Human-readable name
  t.decimal :shares, precision: 30, scale: 18
  t.decimal :vana_value, precision: 30, scale: 18
  t.decimal :rewards_earned, precision: 30, scale: 18, default: 0
  t.string :status, default: "active"  # active, unstaking, withdrawn
  t.datetime :staked_at
  t.datetime :unstaked_at
  t.timestamps
end
```

**Staking event history**: Store in entries system:
- Use `Trade` entryable for stake/unstake events
- Activity labels: `stake`, `unstake`, `reward_claim`
- This gives us full history via the existing entries table

**Historical tracking**:
- Daily snapshots of staking positions (via balance snapshots)
- Track rewards accrued over time
- APY calculation from reward rate changes
- Use existing `Balance::Syncer` pattern for daily staking value snapshots

### 4.4 Vanascan API Integration

**Explorer API** (Blockscout-compatible):

```ruby
# app/models/provider/vanascan.rb
class Provider::Vanascan < Provider::Base
  BASE_URL = "https://api.vanascan.io/api"

  # Account balance
  def get_balance(address)
    get("?module=account&action=balance&address=#{address}")
  end

  # Token balance
  def get_token_balance(address, contract_address)
    get("?module=account&action=tokenbalance&contractaddress=#{contract_address}&address=#{address}")
  end

  # Transaction list (for activity feed)
  def get_transactions(address, page: 1)
    get("?module=account&action=txlist&address=#{address}&page=#{page}&offset=25&sort=desc")
  end

  # Token transfers (USDC.e movements)
  def get_token_transfers(address, contract_address)
    get("?module=account&action=tokentx&contractaddress=#{contract_address}&address=#{address}")
  end
end
```

### 4.5 Price Feed

**VANA/USD price**: Use CoinGecko or similar:
```ruby
# app/models/provider/vana_price.rb
# CoinGecko API: GET https://api.coingecko.com/api/v3/simple/price?ids=vana&vs_currencies=usd
```

Or reuse existing `Provider::YahooFinance` / `Provider::TwelveData` for VANA price if listed.

### 4.6 Sync Architecture

Reuse existing `Syncable` concern and `SyncJob` pattern:

```
WalletSyncJob (new)
  ├── Fetch VANA balance (eth_getBalance)
  ├── Fetch USDC.e balance (eth_call)
  ├── Fetch staking positions (contract reads)
  ├── Fetch VANA/USD price
  ├── Update holdings (VANA, USDC.e, staked VANA)
  ├── Snapshot balance
  └── Detect staking events (stake/unstake/rewards)
```

Schedule: Every 5-15 minutes via Sidekiq-cron (configurable).

---

## 5. Vana Blockchain Integration Details

### 5.1 Network Configuration

| Parameter | Value |
|-----------|-------|
| Chain name | Vana Mainnet |
| Chain ID | 1480 |
| RPC URL | `https://rpc.vana.org` |
| Currency | VANA (native, 18 decimals) |
| Explorer | https://vanascan.io |
| Explorer API | `https://api.vanascan.io/api` (Blockscout) |

### 5.2 Key Contract Addresses

| Contract | Address | Notes |
|----------|---------|-------|
| VanaPoolStaking | `0x641C18E2F286c86f96CE95C8ec1EB9fC0415Ca0e` | Active staking contract |
| USDC.e (Stargate Bridged) | TBD — verify on [vanascan.io/tokens](https://vanascan.io/tokens) | Bridged via LayerZero/Stargate |
| DLP Root Staking (deprecated) | `0xff14346dF2B8Fd0c95BF34f1c92e49417b508AD5` | Read-only, legacy |

### 5.3 Querying Balances

**Native VANA balance**:
```json
POST https://rpc.vana.org
{
  "jsonrpc": "2.0",
  "method": "eth_getBalance",
  "params": ["0xYOUR_ADDRESS", "latest"],
  "id": 1
}
// Returns hex-encoded wei value → divide by 10^18 for VANA
```

**USDC.e balance** (ERC-20 `balanceOf`):
```json
POST https://rpc.vana.org
{
  "jsonrpc": "2.0",
  "method": "eth_call",
  "params": [{
    "to": "USDC_CONTRACT_ADDRESS",
    "data": "0x70a08231000000000000000000000000YOUR_ADDRESS_WITHOUT_0x"
  }, "latest"],
  "id": 1
}
// Returns hex-encoded value → divide by 10^6 for USDC
```

**Staking position** (`balanceOf` on VanaPoolStaking):
```json
POST https://rpc.vana.org
{
  "jsonrpc": "2.0",
  "method": "eth_call",
  "params": [{
    "to": "0x641C18E2F286c86f96CE95C8ec1EB9fC0415Ca0e",
    "data": "0x70a08231000000000000000000000000YOUR_ADDRESS_WITHOUT_0x"
  }, "latest"],
  "id": 1
}
// Returns shares owned → convert to VANA value via share price
```

### 5.4 Staking Contract Interface

The VanaPoolStaking contract provides:
- **Non-rebasing shares**: Share count stays fixed; VANA value per share increases as rewards accrue
- **Entity-based delegation**: Stakes can be delegated to specific validators/entities
- **Slippage protection**: For stake/unstake operations
- **Continuous compounding**: Rewards compound automatically

Key read functions to implement:
- `balanceOf(address)` → shares owned
- Total pool value and total shares → calculate VANA per share
- Entity metadata → validator names and performance

### 5.5 Data Sources Summary

| Data Point | Source | Method |
|------------|--------|--------|
| VANA balance | Vana RPC | `eth_getBalance` |
| USDC.e balance | Vana RPC | `eth_call` (ERC-20 balanceOf) |
| Staking shares | Vana RPC | `eth_call` on VanaPoolStaking |
| Staking value | Calculated | shares × VANA per share |
| VANA/USD price | CoinGecko API | REST API |
| Transaction history | Vanascan API | Blockscout account module |
| Staking events | Vanascan API | Event logs from staking contract |
| Historical rewards | Vanascan API + snapshots | Track value per share over time |

---

## 6. Database Migration Plan

### 6.1 Tables to Drop (~40 tables)

```ruby
# Account type tables (8)
drop_table :depositories
drop_table :investments
drop_table :properties
drop_table :vehicles
drop_table :credit_cards
drop_table :loans
drop_table :other_assets
drop_table :other_liabilities
drop_table :addresses

# Provider tables (18)
drop_table :plaid_items
drop_table :plaid_accounts
drop_table :simplefin_items
drop_table :simplefin_accounts
drop_table :enable_banking_items
drop_table :enable_banking_accounts
drop_table :lunchflow_items
drop_table :lunchflow_accounts
drop_table :mercury_items
drop_table :mercury_accounts
drop_table :snaptrade_items
drop_table :snaptrade_accounts
drop_table :indexa_capital_items
drop_table :indexa_capital_accounts
drop_table :coinbase_items
drop_table :coinbase_accounts
drop_table :coinstats_items
drop_table :coinstats_accounts

# Feature tables (15+)
drop_table :budgets
drop_table :budget_categories
drop_table :categories
drop_table :merchants
drop_table :family_merchant_associations
drop_table :rules
drop_table :rule_actions
drop_table :rule_conditions
drop_table :rule_runs
drop_table :recurring_transactions
drop_table :transfers
drop_table :rejected_transfers
drop_table :imports
drop_table :import_rows
drop_table :import_mappings
drop_table :chats
drop_table :messages
drop_table :tool_calls
drop_table :llm_usages
drop_table :data_enrichments
drop_table :subscriptions
drop_table :invite_codes
drop_table :invitations
drop_table :impersonation_sessions
drop_table :impersonation_session_logs
drop_table :family_exports
drop_table :family_documents
drop_table :oauth_access_grants
drop_table :oauth_access_tokens
drop_table :oauth_applications
drop_table :eval_datasets
drop_table :eval_results
drop_table :eval_runs
drop_table :eval_samples
drop_table :mobile_devices
drop_table :sso_providers
drop_table :sso_audit_logs
drop_table :oidc_identities
```

### 6.2 Tables to Keep (~15 tables)

```
accounts              # Wallet records (add wallet_address, chain columns)
cryptos               # Accountable type record
account_providers     # Keep for provider linking pattern
entries               # Ledger entries (staking events, balance changes)
trades                # Stake/unstake events
valuations            # Wallet value snapshots
holdings              # Token balances (VANA, USDC.e, staked VANA)
securities            # Token definitions (VANA, USDC.e)
security_prices       # VANA/USD price history
balances              # Daily balance snapshots
exchange_rates        # USD conversion rates
users                 # User accounts
families              # Workspaces
sessions              # Auth sessions
api_keys              # API access (optional)
syncs                 # Sync operation tracking
tags                  # Optional: wallet labels
taggings              # Tag associations
active_storage_*      # File attachments (logos)
settings              # App configuration
```

### 6.3 New Tables

```ruby
# Staking positions
create_table :staking_positions, id: :uuid do |t|
  t.references :account, null: false, foreign_key: true, type: :uuid
  t.string :entity_id
  t.string :entity_name
  t.decimal :shares, precision: 30, scale: 18
  t.decimal :vana_value, precision: 30, scale: 18
  t.decimal :rewards_earned, precision: 30, scale: 18, default: 0
  t.decimal :apy_snapshot, precision: 10, scale: 4  # Current APY at snapshot time
  t.string :status, default: "active"
  t.datetime :staked_at
  t.datetime :unstaked_at
  t.jsonb :extra, default: {}  # Raw contract data
  t.timestamps
end

# Staking snapshots (for historical tracking)
create_table :staking_snapshots, id: :uuid do |t|
  t.references :staking_position, null: false, foreign_key: true, type: :uuid
  t.date :date, null: false
  t.decimal :shares, precision: 30, scale: 18
  t.decimal :vana_value, precision: 30, scale: 18
  t.decimal :cumulative_rewards, precision: 30, scale: 18
  t.decimal :apy, precision: 10, scale: 4
  t.timestamps
end
add_index :staking_snapshots, [:staking_position_id, :date], unique: true
```

### 6.4 Column Additions

```ruby
# accounts table
add_column :accounts, :wallet_address, :string
add_column :accounts, :chain, :string, default: "vana"
add_index :accounts, [:family_id, :wallet_address], unique: true

# Remove columns no longer needed
remove_column :accounts, :plaid_account_id       # Plaid reference
remove_column :accounts, :simplefin_account_id    # SimpleFIN reference
remove_column :accounts, :institution_name        # Bank institution
remove_column :accounts, :institution_domain      # Bank domain
```

---

## 7. Phased Roadmap

### Phase 1: Strip & Clean (Foundation)

**Goal**: Remove all non-crypto features, get a clean buildable app.

**Tasks**:
1. Remove account types: Depository, Investment, Property, Vehicle, CreditCard, Loan, OtherAsset, OtherLiability
2. Remove all 9 provider integrations (Plaid, SimpleFIN, EnableBanking, Lunchflow, Mercury, Snaptrade, IndexaCapital, Coinbase, CoinStats)
3. Remove budgets, categories, merchants, rules, recurring transactions, transfers
4. Remove AI assistant (chats, messages, tool_calls, LLM)
5. Remove imports/exports system
6. Remove subscriptions, invitations, invite codes, impersonation
7. Remove OAuth/Doorkeeper
8. Clean up unused gems from Gemfile
9. Clean routes (remove all deleted resource routes)
10. Update `Accountable::TYPES` to `%w[Crypto]`
11. Simplify navigation: remove Budgets, Reports, Transactions, AI sidebar
12. Run database migrations to drop ~40 tables
13. Ensure app boots and existing tests pass for remaining code

**Estimated scope**: ~200 files to delete, ~50 files to modify, 1 large migration

### Phase 2: Wallet & Balance Tracking (Core Feature)

**Goal**: Paste wallet addresses, see VANA and USDC.e balances.

**Tasks**:
1. Add `wallet_address` and `chain` columns to accounts
2. Build wallet address input UI (new account flow)
3. Create `Provider::VanaRpc` for on-chain queries
4. Implement VANA balance fetching (`eth_getBalance`)
5. Implement USDC.e balance fetching (`eth_call` with balanceOf)
6. Create `WalletSyncJob` using existing Syncable pattern
7. Set up Sidekiq-cron schedule for periodic sync
8. Seed securities: VANA token, USDC.e token
9. Integrate VANA/USD price feed (CoinGecko)
10. Build wallet detail page showing balances
11. Update sidebar to show wallet list with balances
12. Build portfolio overview dashboard (total value, allocation)

### Phase 3: Staking Integration (Key Differentiator)

**Goal**: Track staking positions with full history.

**Tasks**:
1. Create `staking_positions` and `staking_snapshots` tables
2. Build `StakingPosition` model with history tracking
3. Implement VanaPoolStaking contract reads (shares, value per share)
4. Add staking position sync to `WalletSyncJob`
5. Build staking events detection (stake/unstake from contract logs)
6. Store staking events as entries (using Trade entryable)
7. Build staking dashboard section (total staked, rewards, APY)
8. Build staking detail view (per-entity breakdown)
9. Implement daily staking snapshots for historical charts
10. APY tracking: calculate and store APY from reward rate changes
11. Staking rewards history chart (cumulative rewards over time)

### Phase 4: Dashboard & UX Polish

**Goal**: Polished, crypto-native dashboard experience.

**Tasks**:
1. Rebuild dashboard with crypto-specific sections:
   - Portfolio value chart (reuse time series chart)
   - Token allocation donut (reuse donut chart)
   - Staking summary card
   - Wallet list with sparklines
2. Rebrand: update logos, colors, app name to "Vanalytics"
3. Update all i18n strings for crypto context
4. Simplify onboarding: "Add your first Vana wallet"
5. Mobile-responsive wallet and staking views
6. Net worth tracking over time with proper snapshots
7. Cleanup remaining dead code and unused views/partials

### Phase 5: Enhanced Features (Future)

**Goal**: Advanced features for power users.

**Potential tasks**:
- On-chain activity feed (transaction history from Vanascan)
- Multiple chain support (if Vana expands)
- DLP (Data Liquidity Pool) tracking
- Token price alerts
- Portfolio performance analytics (ROI, time-weighted returns)
- Export portfolio data (CSV)
- API endpoints for external access
- Multi-wallet comparison views
- Whale wallet tracking (watch any address)

---

## Appendix: File Count Summary

| Action | Estimated Files |
|--------|----------------|
| Delete entirely | ~200 files (models, controllers, views, tests, locale files) |
| Modify | ~50 files (account.rb, routes.rb, layout, navigation, Gemfile, etc.) |
| Create new | ~20 files (Vana provider, staking model, new views, migrations) |
| Keep as-is | ~100 files (core Rails, design system, auth, base components) |

---

## Appendix: Reference Links

- [Vana Docs](https://docs.vana.org)
- [Vana RPC](https://rpc.vana.org) (Chain ID: 1480)
- [VanaPoolStaking Contract](https://vanascan.io/address/0x641C18E2F286c86f96CE95C8ec1EB9fC0415Ca0e)
- [Vanascan Explorer](https://vanascan.io)
- [Vanascan API](https://vanascan.io/api-docs) (Blockscout-compatible)
- [Vana Smart Contracts (GitHub)](https://github.com/vana-com/vana-smart-contracts)
- [Vana Staking App](https://stake.vana.org)
- [Stargate Bridged USDC on Vana](https://www.coingecko.com/en/coins/stargate-bridged-usdc-vana)
