-- Disposable provider compatibility probe; never a hosted migration.
CREATE SCHEMA IF NOT EXISTS mort_provider_probe;
REVOKE ALL ON SCHEMA mort_provider_probe FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS mort_provider_probe.generations (
  account_id uuid PRIMARY KEY, generation bigint NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS mort_provider_probe.grants (
  id uuid PRIMARY KEY, account_id uuid NOT NULL, generation bigint NOT NULL,
  purpose text NOT NULL CHECK(purpose IN ('confirmation','recovery')),
  expires_at timestamptz NOT NULL, state text NOT NULL DEFAULT 'reserved',
  confirmed_applied boolean NOT NULL DEFAULT false,
  password_applied boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS mort_provider_probe.proofs(account_id uuid PRIMARY KEY,generation bigint NOT NULL);
ALTER TABLE mort_provider_probe.generations ENABLE ROW LEVEL SECURITY;
ALTER TABLE mort_provider_probe.grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE mort_provider_probe.proofs ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION mort_provider_probe.guard_mutation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  fence bigint;
  grant_row mort_provider_probe.grants%ROWTYPE;
  marker text;
  changed_password boolean := OLD.encrypted_password IS DISTINCT FROM NEW.encrypted_password;
  changed_confirmation boolean := OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL;
  changed_marker boolean := (OLD.raw_app_meta_data->>'mort_email_operation_id') IS DISTINCT FROM (NEW.raw_app_meta_data->>'mort_email_operation_id');
BEGIN
  SELECT generation INTO fence FROM mort_provider_probe.generations WHERE account_id=NEW.id FOR UPDATE;
  IF NOT FOUND THEN RETURN NEW; END IF;
  IF NOT(changed_password OR changed_confirmation OR changed_marker OR OLD.email IS DISTINCT FROM NEW.email) THEN RETURN NEW; END IF;
  marker := NEW.raw_app_meta_data->>'mort_email_operation_id';
  IF marker IS NULL OR marker !~ '^[0-9a-f-]{36}$' THEN RAISE EXCEPTION 'MORT credential operation denied'; END IF;
  SELECT * INTO grant_row FROM mort_provider_probe.grants WHERE id=marker::uuid AND account_id=NEW.id FOR UPDATE;
  IF NOT FOUND OR grant_row.generation<>fence OR grant_row.state<>'reserved' OR clock_timestamp()>=grant_row.expires_at
     OR OLD.email IS DISTINCT FROM NEW.email
     OR (changed_confirmation AND grant_row.purpose<>'confirmation') THEN
    RAISE EXCEPTION 'MORT credential operation denied';
  END IF;
  IF changed_confirmation OR changed_password THEN
    UPDATE mort_provider_probe.grants SET
      confirmed_applied=confirmed_applied OR changed_confirmation,
      password_applied=password_applied OR changed_password
    WHERE id=grant_row.id RETURNING * INTO grant_row;
    IF grant_row.password_applied AND (grant_row.purpose='recovery' OR grant_row.confirmed_applied) THEN
      UPDATE mort_provider_probe.grants SET state='committed' WHERE id=grant_row.id;
      IF grant_row.purpose='confirmation' THEN
        INSERT INTO mort_provider_probe.proofs VALUES(NEW.id,fence)
        ON CONFLICT(account_id) DO UPDATE SET generation=EXCLUDED.generation;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION mort_provider_probe.guard_mutation() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS mort_provider_probe_mutation ON auth.users;
CREATE TRIGGER mort_provider_probe_mutation BEFORE UPDATE ON auth.users
FOR EACH ROW EXECUTE FUNCTION mort_provider_probe.guard_mutation();
