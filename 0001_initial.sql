-- BITORA v1 initial schema for Cloudflare D1 / SQLite
-- Planning artifact: review before production use.
-- Amounts: store TON in nanotons (1 TON = 1,000,000,000 nanotons).
-- Points are integer app points and are not TON or guaranteed monetary value.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  telegram_user_id TEXT NOT NULL UNIQUE,
  username TEXT,
  first_name TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE','RESTRICTED','SUSPENDED','DELETED')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS user_entitlements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  entitlement_type TEXT NOT NULL
    CHECK (entitlement_type IN ('ACTIVATION_ELIGIBILITY','PREMIUM_ACCESS')),
  status TEXT NOT NULL CHECK (status IN ('ACTIVE','REVOKED','PENDING')),
  source_payment_id INTEGER,
  granted_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(user_id, entitlement_type)
);

CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_key TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  task_type TEXT NOT NULL CHECK (task_type IN ('FREE','PREMIUM','SPONSORED')),
  reward_points INTEGER NOT NULL CHECK (reward_points >= 0),
  unlock_price_nano INTEGER NOT NULL DEFAULT 0 CHECK (unlock_price_nano >= 0),
  verification_method TEXT NOT NULL
    CHECK (verification_method IN ('TELEGRAM_MEMBERSHIP','YOUTUBE_API','X_API','REFERRAL','MANUAL_REVIEW','CUSTOM')),
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT','SCHEDULED','LIVE','PAUSED','ENDED','CANCELLED')),
  starts_at TEXT,
  ends_at TEXT,
  created_by_admin_id INTEGER,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS sponsors (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
  display_name TEXT NOT NULL,
  review_status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (review_status IN ('PENDING','APPROVED','REJECTED','SUSPENDED')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS campaigns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sponsor_id INTEGER NOT NULL REFERENCES sponsors(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  verification_method TEXT NOT NULL
    CHECK (verification_method IN ('TELEGRAM_MEMBERSHIP','YOUTUBE_API','X_API','MANUAL_REVIEW','CUSTOM')),
  completion_cap INTEGER NOT NULL CHECK (completion_cap > 0),
  points_per_completion INTEGER NOT NULL CHECK (points_per_completion >= 0),
  cost_per_completion_nano INTEGER NOT NULL CHECK (cost_per_completion_nano >= 0),
  task_budget_nano INTEGER NOT NULL CHECK (task_budget_nano >= 0),
  fee_rate_bps INTEGER NOT NULL CHECK (fee_rate_bps >= 0 AND fee_rate_bps <= 10000),
  minimum_fee_nano INTEGER NOT NULL CHECK (minimum_fee_nano >= 0),
  service_fee_nano INTEGER NOT NULL CHECK (service_fee_nano >= 0),
  total_due_nano INTEGER NOT NULL CHECK (total_due_nano >= 0),
  starts_at TEXT,
  ends_at TEXT,
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT','PENDING_PAYMENT','PAYMENT_REVIEW','PENDING_APPROVAL','SCHEDULED','LIVE','PAUSED','ENDED','REJECTED','CANCELLED')),
  approved_by_admin_id INTEGER,
  approved_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS campaign_terms_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_id INTEGER NOT NULL REFERENCES campaigns(id),
  version INTEGER NOT NULL,
  terms_json TEXT NOT NULL,
  created_by_admin_id INTEGER,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(campaign_id, version)
);

CREATE TABLE IF NOT EXISTS payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_reference TEXT NOT NULL UNIQUE,
  user_id INTEGER NOT NULL REFERENCES users(id),
  campaign_id INTEGER REFERENCES campaigns(id),
  payment_purpose TEXT NOT NULL
    CHECK (payment_purpose IN ('ACTIVATION','PREMIUM_ACCESS','PREMIUM_TASK_UNLOCK','SPONSORED_CAMPAIGN','OTHER')),
  network TEXT NOT NULL DEFAULT 'TON',
  expected_amount_nano INTEGER NOT NULL CHECK (expected_amount_nano > 0),
  received_amount_nano INTEGER NOT NULL DEFAULT 0 CHECK (received_amount_nano >= 0),
  sender_address TEXT,
  recipient_address TEXT NOT NULL,
  tx_hash TEXT,
  status TEXT NOT NULL DEFAULT 'CREATED'
    CHECK (status IN ('CREATED','PENDING','CONFIRMED','UNDERPAID','OVERPAID','FAILED','EXPIRED','REFUND_PENDING','REFUNDED','REVIEW_REQUIRED')),
  provider_reference TEXT,
  confirmed_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (tx_hash IS NULL OR length(tx_hash) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_network_tx_unique
  ON payments(network, tx_hash) WHERE tx_hash IS NOT NULL;

CREATE TABLE IF NOT EXISTS payment_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_id INTEGER NOT NULL REFERENCES payments(id),
  event_type TEXT NOT NULL,
  event_payload_json TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS sponsor_credit_accounts (
  sponsor_id INTEGER PRIMARY KEY REFERENCES sponsors(id),
  balance_nano INTEGER NOT NULL DEFAULT 0 CHECK (balance_nano >= 0),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS sponsor_credit_ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sponsor_id INTEGER NOT NULL REFERENCES sponsors(id),
  campaign_id INTEGER REFERENCES campaigns(id),
  payment_id INTEGER REFERENCES payments(id),
  entry_type TEXT NOT NULL
    CHECK (entry_type IN ('CAMPAIGN_REMAINDER_CREDIT','CREDIT_APPLIED','ADMIN_ADJUSTMENT')),
  amount_nano INTEGER NOT NULL CHECK (amount_nano > 0),
  idempotency_key TEXT NOT NULL UNIQUE,
  note TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS campaign_budget_ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_id INTEGER NOT NULL REFERENCES campaigns(id),
  payment_id INTEGER REFERENCES payments(id),
  entry_type TEXT NOT NULL
    CHECK (entry_type IN ('BUDGET_FUNDED','BUDGET_RESERVED','BUDGET_SPENT','REMAINDER_CREDITED','ADMIN_ADJUSTMENT')),
  amount_nano INTEGER NOT NULL CHECK (amount_nano > 0),
  idempotency_key TEXT NOT NULL UNIQUE,
  note TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS task_completions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER REFERENCES tasks(id),
  campaign_id INTEGER REFERENCES campaigns(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  terms_version_id INTEGER REFERENCES campaign_terms_versions(id),
  status TEXT NOT NULL DEFAULT 'STARTED'
    CHECK (status IN ('STARTED','SUBMITTED','UNDER_REVIEW','VERIFIED','REJECTED','REWARDED')),
  verification_method TEXT NOT NULL,
  verification_reference TEXT,
  submitted_at TEXT,
  verified_at TEXT,
  reviewed_by_admin_id INTEGER,
  rewarded_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (task_id IS NOT NULL OR campaign_id IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_task_completion_task_user
  ON task_completions(task_id, user_id) WHERE task_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_task_completion_campaign_user
  ON task_completions(campaign_id, user_id) WHERE campaign_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS verification_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  completion_id INTEGER NOT NULL REFERENCES task_completions(id),
  provider TEXT NOT NULL,
  result TEXT NOT NULL CHECK (result IN ('PENDING','PASS','FAIL','MANUAL_REVIEW')),
  evidence_reference TEXT,
  details_json TEXT,
  checked_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS points_ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  amount_points INTEGER NOT NULL CHECK (amount_points <> 0),
  idempotency_key TEXT NOT NULL UNIQUE,
  note TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS daily_claims (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  claim_date_utc TEXT NOT NULL,
  streak_day INTEGER NOT NULL CHECK (streak_day BETWEEN 1 AND 8),
  reward_points INTEGER NOT NULL CHECK (reward_points >= 0),
  points_ledger_id INTEGER NOT NULL UNIQUE REFERENCES points_ledger(id),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(user_id, claim_date_utc)
);

CREATE TABLE IF NOT EXISTS referrals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  referrer_user_id INTEGER NOT NULL REFERENCES users(id),
  referred_user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING','QUALIFIED','REJECTED','REVIEW')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  qualified_at TEXT,
  CHECK (referrer_user_id <> referred_user_id)
);

CREATE TABLE IF NOT EXISTS allocation_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id),
  allocation_version TEXT NOT NULL,
  amount_units TEXT,
  status TEXT NOT NULL DEFAULT 'UNPLANNED'
    CHECK (status IN ('UNPLANNED','ELIGIBLE','ALLOCATED','DISTRIBUTED','CANCELLED')),
  details_json TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS admin_settings (
  setting_key TEXT PRIMARY KEY,
  setting_value TEXT NOT NULL,
  updated_by_admin_id INTEGER,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_telegram_user_id TEXT NOT NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  before_json TEXT,
  after_json TEXT,
  request_id TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS idempotency_keys (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scope TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  response_status INTEGER,
  response_json TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE(scope, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_tasks_status_schedule ON tasks(status, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_campaigns_status_schedule ON campaigns(status, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_payments_user_created ON payments(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_completions_user_status ON task_completions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_points_user_created ON points_ledger(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_created ON admin_audit_log(created_at);
