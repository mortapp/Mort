-- Disabled-by-default private email challenge authority. No hosted activation.
BEGIN;
CREATE SCHEMA IF NOT EXISTS mort_auth_guard;
REVOKE ALL ON SCHEMA mort_auth_guard FROM PUBLIC,anon,authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA mort_auth_guard REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

CREATE TABLE mort_auth_guard.control (
  singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
  enabled boolean NOT NULL DEFAULT false,
  activation_generation bigint NOT NULL DEFAULT 1 CHECK(activation_generation>0),
  restore_generation bigint NOT NULL DEFAULT 1 CHECK(restore_generation>0),
  account_hourly integer NOT NULL DEFAULT 5 CHECK(account_hourly BETWEEN 1 AND 100),
  recipient_hourly integer NOT NULL DEFAULT 5 CHECK(recipient_hourly BETWEEN 1 AND 100),
  global_hourly integer NOT NULL DEFAULT 40 CHECK(global_hourly BETWEEN 1 AND 1000),
  source_hourly integer NOT NULL DEFAULT 5 CHECK(source_hourly BETWEEN 1 AND 100),
  source_family_hourly integer NOT NULL DEFAULT 3 CHECK(source_family_hourly BETWEEN 1 AND 100),
  queue_limit integer NOT NULL DEFAULT 20 CHECK(queue_limit BETWEEN 1 AND 100),
  delivery_limit integer NOT NULL DEFAULT 2 CHECK(delivery_limit BETWEEN 1 AND 10),
  last_threshold_alert timestamptz
);
INSERT INTO mort_auth_guard.control(singleton) VALUES(true);
CREATE TABLE mort_auth_guard.account_generations (
  account_id uuid PRIMARY KEY,
  address_generation bigint NOT NULL DEFAULT 1 CHECK(address_generation>0),
  credential_generation bigint NOT NULL DEFAULT 1 CHECK(credential_generation>0),
  fence_generation bigint NOT NULL DEFAULT 1 CHECK(fence_generation>0),
  recipient_hash text NOT NULL CHECK(recipient_hash ~ '^[0-9a-f]{64}$'),
  deleted_at timestamptz
);
CREATE TABLE mort_auth_guard.families (
  id uuid PRIMARY KEY,account_id uuid NOT NULL,purpose text NOT NULL CHECK(purpose IN('confirmation','recovery')),
  recipient_hash text NOT NULL CHECK(recipient_hash ~ '^[0-9a-f]{64}$'),
  source_hash text NOT NULL CHECK(source_hash ~ '^[0-9a-f]{64}$'),
  address_generation bigint NOT NULL,credential_generation bigint NOT NULL,
  activation_generation bigint NOT NULL,restore_generation bigint NOT NULL,
  issued_at timestamptz NOT NULL,family_expires_at timestamptz NOT NULL,
  failures smallint NOT NULL DEFAULT 0 CHECK(failures BETWEEN 0 AND 5),
  state text NOT NULL DEFAULT 'active' CHECK(state IN('active','consumed','exhausted','expired','retired')),
  last_promoted_at timestamptz,inflight_until timestamptz,
  CHECK(family_expires_at=issued_at+interval '600 seconds')
);
CREATE UNIQUE INDEX mort_auth_one_active_family ON mort_auth_guard.families(account_id,purpose) WHERE state='active';
CREATE INDEX mort_auth_family_retention ON mort_auth_guard.families(family_expires_at);
CREATE TABLE mort_auth_guard.items (
  id uuid PRIMARY KEY,family_id uuid NOT NULL REFERENCES mort_auth_guard.families(id) ON DELETE CASCADE,
  code_hmac text NOT NULL CHECK(code_hmac ~ '^[0-9a-f]{64}$'),
  link_digest text NOT NULL CHECK(link_digest ~ '^[0-9a-f]{64}$'),
  state text NOT NULL DEFAULT 'issued' CHECK(state IN('issued','usable','grace','retired')),
  delivery_state text NOT NULL DEFAULT 'queued' CHECK(delivery_state IN('queued','leased','acknowledged','failed','ambiguous','expired')),
  issued_at timestamptz NOT NULL,promoted_at timestamptz,grace_until timestamptz,
  delivery_generation bigint NOT NULL DEFAULT 1,
  CHECK(state<>'grace' OR grace_until IS NOT NULL)
);
CREATE INDEX mort_auth_items_family ON mort_auth_guard.items(family_id);
CREATE TABLE mort_auth_guard.capabilities (
  digest text PRIMARY KEY CHECK(digest ~ '^[0-9a-f]{64}$'),
  family_id uuid NOT NULL UNIQUE REFERENCES mort_auth_guard.families(id) ON DELETE CASCADE,
  account_id uuid NOT NULL,purpose text NOT NULL CHECK(purpose IN('confirmation','recovery')),
  address_generation bigint NOT NULL,credential_generation bigint NOT NULL,
  activation_generation bigint NOT NULL,restore_generation bigint NOT NULL,
  verifier_hash text NOT NULL CHECK(verifier_hash ~ '^[0-9a-f]{64}$'),
  issued_at timestamptz NOT NULL,expires_at timestamptz NOT NULL,
  state text NOT NULL DEFAULT 'issued' CHECK(state IN('issued','reserved','consumed','retired')),
  CHECK(expires_at=issued_at+interval '300 seconds')
);
CREATE TABLE mort_auth_guard.address_proofs (
  account_id uuid PRIMARY KEY,address_generation bigint NOT NULL,recipient_hash text NOT NULL,
  activation_generation bigint NOT NULL,restore_generation bigint NOT NULL,
  source text NOT NULL CHECK(source IN('mort_challenge','provider_oauth','confirmed_baseline')),
  proved_at timestamptz NOT NULL,retired_at timestamptz
);
CREATE TABLE mort_auth_guard.operation_grants (
  id uuid PRIMARY KEY,account_id uuid NOT NULL,capability_digest text NOT NULL UNIQUE REFERENCES mort_auth_guard.capabilities(digest),
  purpose text NOT NULL CHECK(purpose IN('confirmation','recovery')),
  address_generation bigint NOT NULL,credential_generation bigint NOT NULL,fence_generation bigint NOT NULL,
  activation_generation bigint NOT NULL,restore_generation bigint NOT NULL,
  expires_at timestamptz NOT NULL,state text NOT NULL DEFAULT 'reserved' CHECK(state IN('reserved','pending','committed','fenced')),
  password_applied boolean NOT NULL DEFAULT false,confirmation_applied boolean NOT NULL DEFAULT false,
  reserved_at timestamptz NOT NULL,completed_at timestamptz
);
CREATE INDEX mort_auth_operation_accounts ON mort_auth_guard.operation_grants(account_id,fence_generation);
CREATE TABLE mort_auth_guard.quota_events (
  id uuid PRIMARY KEY,kind text NOT NULL CHECK(kind IN('family','dispatch','global_threshold','owner_adjustment')),
  account_id uuid,purpose text,recipient_hash text,source_hash text,occurred_at timestamptz NOT NULL,
  item_id uuid,attempt_id uuid UNIQUE,detail jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX mort_auth_quota_time ON mort_auth_guard.quota_events(occurred_at);
CREATE INDEX mort_auth_quota_recipient ON mort_auth_guard.quota_events(recipient_hash,occurred_at);
CREATE INDEX mort_auth_quota_source ON mort_auth_guard.quota_events(source_hash,occurred_at);
CREATE TABLE mort_auth_guard.hook_events (
  event_digest text PRIMARY KEY CHECK(event_digest ~ '^[0-9a-f]{64}$'),body_digest text NOT NULL,
  signed_at timestamptz NOT NULL,received_at timestamptz NOT NULL,item_id uuid,
  outcome text NOT NULL CHECK(outcome IN('accepted','denied'))
);
CREATE TABLE mort_auth_guard.outbox (
  item_id uuid PRIMARY KEY REFERENCES mort_auth_guard.items(id) ON DELETE CASCADE,
  encrypted_envelope text,created_at timestamptz NOT NULL,expires_at timestamptz NOT NULL,
  lease_id uuid,lease_until timestamptz,lease_generation bigint NOT NULL DEFAULT 1,
  state text NOT NULL DEFAULT 'queued' CHECK(state IN('queued','deferred','leased','terminal'))
);
CREATE TABLE mort_auth_guard.delivery_attempts (
  id uuid PRIMARY KEY,item_id uuid NOT NULL REFERENCES mort_auth_guard.items(id) ON DELETE CASCADE,
  generation bigint NOT NULL,claimed_at timestamptz NOT NULL,expires_at timestamptz NOT NULL,
  dispatched_at timestamptz,outcome text CHECK(outcome IN('acknowledged','failed','ambiguous','expired')),
  finished_at timestamptz,CHECK(expires_at<=claimed_at+interval '30 seconds')
);
DO $$ DECLARE tab record; BEGIN
  FOR tab IN SELECT tablename FROM pg_tables WHERE schemaname='mort_auth_guard' LOOP
    EXECUTE format('ALTER TABLE mort_auth_guard.%I ENABLE ROW LEVEL SECURITY',tab.tablename);
    EXECUTE format('REVOKE ALL ON mort_auth_guard.%I FROM PUBLIC,anon,authenticated',tab.tablename);
  END LOOP;
END $$;
-- No control setter, hook or trigger is enabled by this foundational migration.
COMMIT;
