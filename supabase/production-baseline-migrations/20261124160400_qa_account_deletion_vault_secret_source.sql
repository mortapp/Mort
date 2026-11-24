-- Store the deletion worker credential in Supabase Vault as the single
-- source of truth for both the Edge Function and pg_cron scheduler.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.secrets
    WHERE name = 'account_deletion_worker_secret'
  ) THEN
    PERFORM vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'account_deletion_worker_secret',
      'Shared secret for the account deletion processor and scheduler'
    );
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.service_get_account_deletion_worker_secret()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
BEGIN
  SELECT ds.decrypted_secret
    INTO v_secret
  FROM vault.decrypted_secrets ds
  WHERE ds.name = 'account_deletion_worker_secret'
  LIMIT 1;

  IF v_secret IS NULL OR length(v_secret) < 64 THEN
    RAISE EXCEPTION 'account deletion worker secret unavailable';
  END IF;

  RETURN v_secret;
END;
$$;

REVOKE ALL ON FUNCTION public.service_get_account_deletion_worker_secret()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.service_get_account_deletion_worker_secret()
  TO service_role;
