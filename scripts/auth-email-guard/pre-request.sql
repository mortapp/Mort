-- Disposable owned fixture experiment only; not an applied migration.
ALTER TABLE mort_fixture.pre_request_control ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION mort_fixture.guard_pre_request()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  -- Inspect the transaction role set by PostgREST, not this definer's owner.
  IF current_setting('role',true)<>'authenticated' THEN RETURN; END IF;
  IF NOT EXISTS(SELECT 1 FROM mort_fixture.pre_request_control WHERE enabled) THEN RETURN; END IF;
  IF NOT mort_fixture.session_is_live() THEN
    RAISE SQLSTATE 'PT401' USING MESSAGE='Session ended';
  END IF;
END $$;
REVOKE ALL ON FUNCTION mort_fixture.guard_pre_request() FROM public;
GRANT USAGE ON SCHEMA mort_fixture TO anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION mort_fixture.guard_pre_request() TO anon,authenticated,service_role;
ALTER ROLE authenticator SET pgrst.db_pre_request='mort_fixture.guard_pre_request';
NOTIFY pgrst,'reload config';
