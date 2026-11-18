-- Preserve MORT's flat fee-per-completed-gig model. Do not choose a launch
-- price here: this test-only policy remains zero and all provider controls stay
-- disabled until the owner approves pricing and the legal/economic gates.

ALTER TABLE private.stripe_financial_policy_versions
  ADD COLUMN IF NOT EXISTS service_fee_fixed_cents integer;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'stripe_financial_policy_fixed_fee_check'
      AND conrelid = 'private.stripe_financial_policy_versions'::regclass
  ) THEN
    ALTER TABLE private.stripe_financial_policy_versions
      ADD CONSTRAINT stripe_financial_policy_fixed_fee_check
      CHECK (
        service_fee_fixed_cents IS NULL
        OR (
          policy_kind = 'service_fee'
          AND service_fee_fixed_cents >= 0
          AND service_fee_bps = 0
          AND service_fee_min_cents = 0
          AND service_fee_max_cents = 0
        )
      );
  END IF;
END;
$$;

COMMENT ON COLUMN private.stripe_financial_policy_versions.service_fee_fixed_cents IS
  'Owner-approved flat fee in cents per completed gig; NULL means unpriced and blocks quote calculation.';

CREATE OR REPLACE FUNCTION private.calculate_mort_service_fee_v1(
  p_base_cents integer,
  p_policy_id uuid
)
RETURNS integer
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_policy private.stripe_financial_policy_versions%rowtype;
BEGIN
  IF p_base_cents IS NULL OR p_base_cents < 0 THEN
    RAISE EXCEPTION 'invalid_compensated_base_cents';
  END IF;

  SELECT * INTO v_policy
  FROM private.stripe_financial_policy_versions
  WHERE id = p_policy_id AND policy_kind = 'service_fee';

  IF v_policy.id IS NULL THEN
    RAISE EXCEPTION 'service_fee_policy_missing';
  END IF;
  IF v_policy.service_fee_fixed_cents IS NULL THEN
    RAISE EXCEPTION 'service_fee_policy_unpriced';
  END IF;
  IF p_base_cents = 0 THEN
    RETURN 0;
  END IF;

  RETURN v_policy.service_fee_fixed_cents;
END;
$$;

-- Replace any active test percentage policy with a zero-fixed-fee test policy.
-- The zero is a test-only no-fee setting, not an approved business price.
UPDATE private.stripe_financial_policy_versions
SET active = false,
    retired_at = statement_timestamp()
WHERE environment = 'test'
  AND policy_kind = 'service_fee'
  AND currency_code = 'USD'
  AND scope_key = 'global'
  AND active
  AND version <> 'sandbox-flat-fee-test-only-v1';

INSERT INTO private.stripe_financial_policy_versions (
  environment, policy_kind, scope_key, currency_code, version,
  effective_at, active, service_fee_bps, service_fee_min_cents,
  service_fee_max_cents, service_fee_fixed_cents, quote_ttl_seconds
)
SELECT
  'test', 'service_fee', 'global', 'USD', 'sandbox-flat-fee-test-only-v1',
  statement_timestamp() - interval '1 second', true, 0, 0, 0, 0, 900
WHERE NOT EXISTS (
  SELECT 1
  FROM private.stripe_financial_policy_versions
  WHERE environment = 'test'
    AND policy_kind = 'service_fee'
    AND currency_code = 'USD'
    AND scope_key = 'global'
    AND version = 'sandbox-flat-fee-test-only-v1'
);

CREATE OR REPLACE FUNCTION public.get_my_financial_policy_config_v1()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor uuid := auth.uid();
  control private.stripe_runtime_controls%rowtype;
  environment text;
  fee_policy private.stripe_financial_policy_versions%rowtype;
  tip_policy private.stripe_financial_policy_versions%rowtype;
BEGIN
  IF actor IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING errcode = '42501';
  END IF;
  IF NOT public.is_profile_active(actor) THEN
    RAISE EXCEPTION 'user_account_restricted' USING errcode = '42501';
  END IF;

  SELECT * INTO control
  FROM private.stripe_runtime_controls
  WHERE singleton;

  IF control.singleton IS NOT TRUE THEN
    RAISE EXCEPTION 'stripe_runtime_controls_unavailable';
  END IF;

  environment := private.stripe_environment_for_mode(control.mode);

  SELECT * INTO fee_policy
  FROM private.resolve_financial_policy_v1(
    environment, 'service_fee', control.currency_code, 'global', statement_timestamp()
  );

  SELECT * INTO tip_policy
  FROM private.resolve_financial_policy_v1(
    environment, 'tip', control.currency_code, 'global', statement_timestamp()
  );

  RETURN jsonb_build_object(
    'ok', true,
    'environment', environment,
    'currency_code', control.currency_code,
    'service_fee', CASE
      WHEN fee_policy.id IS NULL THEN NULL
      ELSE jsonb_build_object(
        'version', fee_policy.version,
        'fee_model', 'flat_per_completed_gig',
        'fixed_cents', fee_policy.service_fee_fixed_cents,
        'currency_code', fee_policy.currency_code,
        'quote_ttl_seconds', fee_policy.quote_ttl_seconds
      )
    END,
    'tip', CASE
      WHEN tip_policy.id IS NULL THEN NULL
      ELSE jsonb_build_object(
        'version', tip_policy.version,
        'minimum_cents', tip_policy.tip_min_cents,
        'maximum_cents', tip_policy.tip_max_cents,
        'late_tip_window_seconds', tip_policy.late_tip_window_seconds,
        'teen_share_basis_points', tip_policy.tip_teen_share_bps,
        'mort_fee_basis_points', tip_policy.tip_mort_fee_bps,
        'excluded_from_fair_pay', tip_policy.tip_excluded_from_fair_pay
      )
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_financial_policy_config_v1() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_financial_policy_config_v1() TO authenticated;
