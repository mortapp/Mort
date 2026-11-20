-- The current integration uses server-derived funding quotes and the
-- quote-bound PaymentIntent path. Retire the older direct preparation RPC,
-- which still had a percentage-fee formula and has no current client caller.
-- Keep its signature for compatibility, but fail closed before any lookup or
-- provider/ledger state change. Its dependent legacy record RPC consequently
-- fails before writing as well.

CREATE OR REPLACE FUNCTION public.stripe_server_prepare_job_payment(
  p_adult_id uuid,
  p_contract_id uuid,
  p_environment text,
  p_operation_version integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.require_stripe_service_role();
  RAISE EXCEPTION 'legacy_percentage_funding_path_disabled_use_quote_v1';
END;
$$;

REVOKE ALL ON FUNCTION public.stripe_server_prepare_job_payment(uuid, uuid, text, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stripe_server_prepare_job_payment(uuid, uuid, text, integer)
  TO service_role;

COMMENT ON FUNCTION public.stripe_server_prepare_job_payment(uuid, uuid, text, integer) IS
  'Deprecated server-only legacy percentage-fee path. Fails closed; use server-authoritative quote v1 and quote-bound PaymentIntent v2.';
