-- Disposable local fixture only; not a product migration or hosted purge policy.
CREATE FUNCTION mort_fixture.purge_auth_audit(retention_seconds integer) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE removed bigint;
BEGIN
 IF retention_seconds IS NULL OR retention_seconds<60 OR retention_seconds>7776000 THEN RAISE EXCEPTION 'Retention parameter rejected' USING ERRCODE='22023';END IF;
 DELETE FROM auth.audit_log_entries WHERE created_at < transaction_timestamp()-make_interval(secs=>retention_seconds);
 GET DIAGNOSTICS removed=ROW_COUNT;RETURN removed;
END $$;
REVOKE ALL ON FUNCTION mort_fixture.purge_auth_audit(integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION mort_fixture.purge_auth_audit(integer) TO service_role;
