-- Read-only release preflight. Run against the explicitly chosen QA or
-- production connection; this queries catalog metadata and calls no RPC.
-- Every overload is shown. Compare its INPUT argument names with the exact
-- deployed Edge bundle before considering the dependency present.
WITH required(workflow, rpc_name) AS (
  VALUES
    ('account-deletion-processor', 'service_claim_account_deletion_request'),
    ('account-deletion-processor', 'service_check_account_deletion_financial_retention'),
    ('account-deletion-processor', 'service_hold_account_deletion_for_financial_retention'),
    ('account-deletion-processor', 'service_complete_account_deletion_request'),
    ('account-deletion-processor', 'service_fail_account_deletion_request'),
    ('account-deletion-processor', 'service_list_account_deletion_storage_objects'),
    ('google-play-rtdn', 'record_google_play_purchase_verification'),
    ('identity-verification-webhook', 'process_identity_verification_provider_event_v2'),
    ('password-guard', 'mort_consume_password_guard_rate_limit'),
    ('revenuecat-webhook', 'process_revenuecat_provider_event')
),
catalog AS (
  SELECT
    required.*,
    p.oid,
    pg_get_function_identity_arguments(p.oid) AS identity_arguments,
    pg_get_function_arguments(p.oid) AS arguments_with_defaults,
    has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_execute,
    has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute
  FROM required
  LEFT JOIN pg_proc p
    ON p.pronamespace = 'public'::regnamespace
    AND p.proname = required.rpc_name
    AND p.prokind = 'f'
)
SELECT
  workflow,
  rpc_name,
  identity_arguments,
  arguments_with_defaults,
  service_execute,
  anon_execute,
  authenticated_execute,
  CASE
    WHEN oid IS NULL THEN 'MISSING'
    WHEN NOT service_execute THEN 'SERVICE_EXECUTE_MISSING'
    WHEN anon_execute OR authenticated_execute THEN 'REVIEW_CLIENT_EXECUTE'
    ELSE 'SERVICE_EXECUTE_PRESENT'
  END AS catalog_status
FROM catalog
ORDER BY workflow, rpc_name, identity_arguments;
