import { executeResolutionOperations } from "../stripe-resolve-job-payment/resolution_operations.ts";

function assertEquals(actual: string, expected: string, label: string): void {
  if (actual !== expected) {
    throw new Error(
      `${label}: expected ${JSON.stringify(expected)}, received ${
        JSON.stringify(actual)
      }`,
    );
  }
}

const container = "supabase_db_mort-mobile";
const encoder = new TextEncoder();
const migration = await Deno.readTextFile(
  new URL(
    "../../migrations/20261025012531_mort_financial_integrity_and_webhook_fencing.sql",
    import.meta.url,
  ),
);

async function executeLocalSql(sql: string): Promise<string> {
  const child = new Deno.Command("docker", {
    args: [
      "exec",
      "-i",
      container,
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
      "-q",
      "-t",
      "-A",
    ],
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
  }).spawn();
  const writer = child.stdin.getWriter();
  await writer.write(
    encoder.encode("BEGIN;\n" + migration + "\n" + sql + "\nROLLBACK;\n"),
  );
  await writer.close();
  const result = await child.output();
  if (!result.success) {
    throw new Error(
      `local SQL fixture failed (${result.code}): ${
        new TextDecoder().decode(result.stderr).slice(0, 1600)
      }`,
    );
  }
  return new TextDecoder().decode(result.stdout).trim();
}

function scenarioSql(refundAmount: number): string {
  const obligationId = crypto.randomUUID();
  const contractId = crypto.randomUUID();
  const versionId = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const resolutionId = crypto.randomUUID();
  const disputeId = crypto.randomUUID();
  const actorId = crypto.randomUUID();
  const requestId = crypto.randomUUID();
  const suffix = crypto.randomUUID().replaceAll("-", "");
  const refundId = `re_Test${suffix.slice(0, 18)}`;
  const paymentIdem = `mort_test_${suffix}`;
  const refundIdem = `mort_refund_${suffix}`;
  const transferGroup = `MORT_JOB_${suffix.slice(0, 32)}`;

  return `
SET LOCAL request.jwt.claim.role = 'service_role';
SET LOCAL session_replication_role = 'replica';
INSERT INTO public.job_payment_obligations (
  id, contract_id, contract_version_id, obligated_poster_id, worker_id,
  amount_cents, currency_code, payment_preference, due_rule, status, disputed_at
) VALUES (
  '${obligationId}', '${contractId}', '${versionId}', '${actorId}', '${crypto.randomUUID()}',
  2500, 'USD', 'cash', 'after_completion', 'disputed', now()
);
INSERT INTO private.stripe_job_payment_intents (
  id, contract_id, contract_version_id, obligation_id, adult_id, teen_id,
  environment, earnings_amount_cents, service_fee_cents, total_amount_cents,
  currency_code, transfer_group, idempotency_key, status
) VALUES (
  '${paymentId}', '${contractId}', '${versionId}', '${obligationId}', '${actorId}', '${crypto.randomUUID()}',
  'test', 2500, 0, 2500, 'USD', '${transferGroup}', '${paymentIdem}', 'disputed'
);
INSERT INTO private.stripe_payment_resolutions (
  id, environment, resolution_source, contract_id, payment_intent_id, dispute_id,
  eligibility_path, transfer_amount_cents, refund_amount_cents, currency_code,
  status, financial_operator_id, review_request_id, execution_request_id,
  transfer_idempotency_key, refund_idempotency_key
) VALUES (
  '${resolutionId}', 'test', 'human_dispute_review', '${contractId}', '${paymentId}', '${disputeId}',
  'partial_completion_approved', 0, ${refundAmount}, 'USD', 'financial_execution_started',
  '${actorId}', '${requestId}', '${crypto.randomUUID()}', '${paymentIdem}_transfer', '${refundIdem}'
);
DO $fixture$
BEGIN
  PERFORM public.stripe_server_record_resolution_operation_result(
    '${resolutionId}', 'test', 'refund', 'succeeded', '${refundId}', NULL
  );
  PERFORM public.stripe_server_record_resolution_result(
    '${resolutionId}', 'test', NULL, '${refundId}', 'succeeded', NULL
  );
END;
$fixture$;
SELECT status || '|' || coalesce(became_due_at::text, 'NULL')
FROM public.job_payment_obligations WHERE id = '${obligationId}';
`;
}

Deno.test("full and partial provider-confirmed refunds keep disputed obligations pending review", async () => {
  for (
    const [label, refundAmount] of [["full", 2500], ["partial", 900]] as const
  ) {
    const result = await executeLocalSql(scenarioSql(refundAmount));
    assertEquals(
      result,
      "disputed|NULL",
      `${label} refund obligation state`,
    );
  }
});

Deno.test("resolution records expose separate transfer and refund operational states", async () => {
  const result = await executeLocalSql(`
SELECT
  (SELECT count(*) = 2 FROM information_schema.columns
    WHERE table_schema = 'private' AND table_name = 'stripe_payment_resolutions'
      AND column_name IN ('transfer_status', 'refund_status'))::text
  || '|' || coalesce(to_regprocedure('public.stripe_server_record_resolution_operation_result(uuid,text,text,text,text,text)')::text, 'missing');
`);
  assertEquals(
    result,
    "true|stripe_server_record_resolution_operation_result(uuid,text,text,text,text,text)",
    "independent resolution operation status schema",
  );
});

Deno.test("zero-amount resolution operations are initialized as not required", async () => {
  const result = await executeLocalSql(`
CREATE TEMP TABLE resolution_operation_trigger_fixture (
  transfer_amount_cents integer NOT NULL,
  refund_amount_cents integer NOT NULL,
  transfer_status text NOT NULL DEFAULT 'not_started',
  refund_status text NOT NULL DEFAULT 'not_started'
);
CREATE TRIGGER initialize_operation_states
BEFORE INSERT ON resolution_operation_trigger_fixture
FOR EACH ROW EXECUTE FUNCTION private.set_resolution_operation_initial_states();
INSERT INTO resolution_operation_trigger_fixture(transfer_amount_cents, refund_amount_cents)
VALUES (0, 900);
SELECT EXISTS (
  SELECT 1 FROM pg_trigger
  WHERE tgrelid = 'private.stripe_payment_resolutions'::regclass
    AND tgname = 'stripe_resolution_operation_initial_states'
    AND NOT tgisinternal
)::text || '|' || (SELECT transfer_status || '|' || refund_status FROM resolution_operation_trigger_fixture);
`);
  assertEquals(
    result,
    "true|not_required|not_started",
    "operation initial-state trigger",
  );
});

Deno.test("webhook mutations require reclaimable lease fencing", async () => {
  const result = await executeLocalSql(`
SELECT
  (SELECT count(*) = 3 FROM information_schema.columns
    WHERE table_schema = 'private' AND table_name = 'stripe_webhook_events'
      AND column_name IN ('lease_token', 'lease_epoch', 'lease_expires_at'))::text
  || '|' || coalesce(to_regprocedure('public.stripe_server_apply_webhook_event(text,text,uuid,text,jsonb)')::text, 'missing');
`);
  assertEquals(
    result,
    "true|stripe_server_apply_webhook_event(text,text,uuid,text,jsonb)",
    "webhook fencing schema",
  );
});

Deno.test("profiles reject direct client writes while self-service RPCs remain executable", async () => {
  const result = await executeLocalSql(`
SELECT
  has_table_privilege('authenticated', 'public.profiles', 'INSERT')::text || '|'
  || has_table_privilege('authenticated', 'public.profiles', 'UPDATE')::text || '|'
  || has_table_privilege('authenticated', 'public.profiles', 'DELETE')::text || '|'
  || has_table_privilege('anon', 'public.profiles', 'INSERT')::text || '|'
  || has_table_privilege('anon', 'public.profiles', 'UPDATE')::text || '|'
  || has_table_privilege('anon', 'public.profiles', 'DELETE')::text || '|'
  || has_any_column_privilege('authenticated', 'public.profiles', 'INSERT')::text || '|'
  || has_any_column_privilege('authenticated', 'public.profiles', 'UPDATE')::text || '|'
  || has_any_column_privilege('anon', 'public.profiles', 'INSERT')::text || '|'
  || has_any_column_privilege('anon', 'public.profiles', 'UPDATE')::text || '|'
  || has_function_privilege('authenticated', 'public.update_my_profile(jsonb,timestamptz,uuid)', 'EXECUTE')::text || '|'
  || has_function_privilege('authenticated', 'public.complete_my_onboarding()', 'EXECUTE')::text || '|'
  || has_function_privilege('authenticated', 'public.save_my_onboarding_profile(text,text,date,text,text,text,boolean,text,uuid)', 'EXECUTE')::text;
`);
  assertEquals(
    result,
    "false|false|false|false|false|false|false|false|false|false|true|true|true",
    "public.profiles client permissions",
  );
});

Deno.test("authenticated direct profile DML is denied while self-service RPCs execute", async () => {
  const userId = crypto.randomUUID();
  const requestId = crypto.randomUUID();
  const email = `profile-fixture-${crypto.randomUUID()}@example.invalid`;
  const result = await executeLocalSql(`
SET LOCAL session_replication_role = 'replica';
INSERT INTO auth.users (id, aud, role, email, encrypted_password)
VALUES ('${userId}', 'authenticated', 'authenticated', '${email}', 'fixture-only');
INSERT INTO public.profiles (id, role, display_name, username, dob, city, state, location_setup_mode, onboarding_completed)
VALUES ('${userId}', 'adult', 'Fixture Account', 'fixture_${
    userId.replaceAll("-", "").slice(0, 12)
  }', date '1990-01-01', 'Indianapolis', 'IN', 'city_state', false);
SET LOCAL session_replication_role = 'origin';
SET LOCAL ROLE anon;
DO $fixture$
BEGIN
  BEGIN
    INSERT INTO public.profiles (id) VALUES ('${userId}');
    RAISE EXCEPTION 'anon_direct_insert_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    UPDATE public.profiles SET display_name = 'Direct Write' WHERE id = '${userId}';
    RAISE EXCEPTION 'anon_direct_update_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    DELETE FROM public.profiles WHERE id = '${userId}';
    RAISE EXCEPTION 'anon_direct_delete_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$fixture$;
RESET ROLE;
SET LOCAL request.jwt.claim.sub = '${userId}';
SET LOCAL request.jwt.claim.role = 'authenticated';
SET LOCAL ROLE authenticated;
DO $fixture$
BEGIN
  BEGIN
    INSERT INTO public.profiles (id) VALUES ('${userId}');
    RAISE EXCEPTION 'authenticated_direct_insert_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$fixture$;
SELECT public.save_my_onboarding_profile(
  'adult', 'Fixture Account', date '1990-01-01', 'Indianapolis', 'IN',
  'city_state', false, 'none', '${requestId}'
)->>'ok';
DO $fixture$
BEGIN
  BEGIN
    UPDATE public.profiles SET display_name = 'Direct Write' WHERE id = '${userId}';
    RAISE EXCEPTION 'authenticated_direct_update_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    DELETE FROM public.profiles WHERE id = '${userId}';
    RAISE EXCEPTION 'authenticated_direct_delete_was_allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$fixture$;
SELECT public.update_my_profile('{"display_name":"Fixture Updated"}'::jsonb)->>'ok';
SELECT public.complete_my_onboarding()->>'code';
`);
  assertEquals(
    result,
    "true\ntrue\nonboarding_steps_incomplete",
    "caller-bound profile RPCs execute and direct DML is rejected",
  );
});
Deno.test("transfer and refund operational outcomes persist independently and finalize only when both succeed", async () => {
  const obligationId = crypto.randomUUID();
  const obligationIdTwo = crypto.randomUUID();
  const contractId = crypto.randomUUID();
  const versionId = crypto.randomUUID();
  const contractIdTwo = crypto.randomUUID();
  const versionIdTwo = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const paymentIdTwo = crypto.randomUUID();
  const resolutionId = crypto.randomUUID();
  const resolutionIdTwo = crypto.randomUUID();
  const disputeId = crypto.randomUUID();
  const disputeIdTwo = crypto.randomUUID();
  const adultId = crypto.randomUUID();
  const teenId = crypto.randomUUID();
  const accountId = crypto.randomUUID();
  const requestId = crypto.randomUUID();
  const requestIdTwo = crypto.randomUUID();
  const suffix = crypto.randomUUID().replaceAll("-", "");
  const transferId = `tr_${suffix.slice(0, 20)}`;
  const refundId = `re_${suffix.slice(0, 20)}`;
  const refundIdTwo = `re_${suffix.slice(20, 38)}`;
  const transferGroup = `MORT_JOB_${suffix.slice(0, 32)}`;
  const idem = `mort_operation_${suffix}`;
  const result = await executeLocalSql(`
SET LOCAL request.jwt.claim.role = 'service_role';
SET LOCAL session_replication_role = 'replica';
INSERT INTO public.job_payment_obligations (
  id, contract_id, contract_version_id, obligated_poster_id, worker_id,
  amount_cents, currency_code, payment_preference, due_rule, status, disputed_at
) VALUES ('${obligationId}', '${contractId}', '${versionId}', '${adultId}', '${teenId}', 2500, 'USD', 'cash', 'after_completion', 'disputed', now());
INSERT INTO private.stripe_connected_accounts (id, user_id, environment, provider_account_id)
VALUES ('${accountId}', '${teenId}', 'test', 'acct_${suffix.slice(0, 20)}');
INSERT INTO public.job_payment_obligations (
  id, contract_id, contract_version_id, obligated_poster_id, worker_id,
  amount_cents, currency_code, payment_preference, due_rule, status, disputed_at
) VALUES ('${obligationIdTwo}', '${contractIdTwo}', '${versionIdTwo}', '${adultId}', '${teenId}', 2500, 'USD', 'cash', 'after_completion', 'disputed', now());
INSERT INTO private.stripe_job_payment_intents (
  id, contract_id, contract_version_id, obligation_id, adult_id, teen_id,
  environment, earnings_amount_cents, service_fee_cents, total_amount_cents,
  currency_code, provider_charge_id, transfer_group, idempotency_key, status
) VALUES (
  '${paymentId}', '${contractId}', '${versionId}', '${obligationId}', '${adultId}', '${teenId}',
  'test', 2500, 0, 2500, 'USD', 'ch_${
    suffix.slice(0, 20)
  }', '${transferGroup}', '${idem}', 'disputed'
);
INSERT INTO private.stripe_payment_resolutions (
  id, environment, resolution_source, contract_id, payment_intent_id, dispute_id,
  eligibility_path, transfer_amount_cents, refund_amount_cents, currency_code,
  status, financial_operator_id, review_request_id, execution_request_id,
  transfer_idempotency_key, refund_idempotency_key
) VALUES (
  '${resolutionId}', 'test', 'human_dispute_review', '${contractId}', '${paymentId}', '${disputeId}',
  'partial_completion_approved', 1600, 900, 'USD', 'financial_execution_started',
  '${adultId}', '${requestId}', '${crypto.randomUUID()}', '${idem}_transfer', '${idem}_refund'
);
DO $fixture$
BEGIN
  PERFORM public.stripe_server_record_resolution_operation_result('${resolutionId}', 'test', 'transfer', 'succeeded', '${transferId}', NULL);
  PERFORM public.stripe_server_record_resolution_operation_result('${resolutionId}', 'test', 'refund', 'failed', '${refundId}', 'refund_failed');
  PERFORM public.stripe_server_record_resolution_result('${resolutionId}', 'test', '${transferId}', '${refundId}', 'processing', 'refund_failed');
END;
$fixture$;
SELECT transfer_status || '|' || refund_status || '|' || status || '|' ||
  (SELECT stripe_job_transfers.status FROM private.stripe_job_transfers WHERE payment_intent_id = '${paymentId}') || '|' ||
  (SELECT stripe_job_refunds.status FROM private.stripe_job_refunds WHERE payment_intent_id = '${paymentId}')
FROM private.stripe_payment_resolutions WHERE id = '${resolutionId}';DO $fixture$
BEGIN
  PERFORM public.stripe_server_record_resolution_operation_result('${resolutionId}', 'test', 'refund', 'succeeded', '${refundId}', NULL);
  PERFORM public.stripe_server_record_resolution_operation_result('${resolutionId}', 'test', 'refund', 'succeeded', '${refundId}', NULL);
  PERFORM public.stripe_server_record_resolution_result('${resolutionId}', 'test', '${transferId}', '${refundId}', 'succeeded', NULL);
END;
$fixture$;
SELECT transfer_status || '|' || refund_status || '|' || status || '|' ||
  (SELECT status FROM public.job_payment_obligations WHERE id = '${obligationId}') || '|' ||
  (SELECT idempotency_key FROM private.stripe_job_transfers WHERE payment_intent_id = '${paymentId}') || '|' ||
  (SELECT idempotency_key FROM private.stripe_job_refunds WHERE payment_intent_id = '${paymentId}') || '|' ||
  (SELECT count(*)::text FROM private.stripe_job_transfers WHERE payment_intent_id = '${paymentId}') || '|' ||
  (SELECT count(*)::text FROM private.stripe_job_refunds WHERE payment_intent_id = '${paymentId}')
FROM private.stripe_payment_resolutions WHERE id = '${resolutionId}';
INSERT INTO private.stripe_job_payment_intents (
  id, contract_id, contract_version_id, obligation_id, adult_id, teen_id,
  environment, earnings_amount_cents, service_fee_cents, total_amount_cents,
  currency_code, transfer_group, idempotency_key, status
) VALUES (
  '${paymentIdTwo}', '${contractIdTwo}', '${versionIdTwo}', '${obligationIdTwo}', '${adultId}', '${teenId}',
  'test', 2500, 0, 2500, 'USD', '${transferGroup}', '${idem}_two', 'disputed'
);
INSERT INTO private.stripe_payment_resolutions (
  id, environment, resolution_source, contract_id, payment_intent_id, dispute_id,
  eligibility_path, transfer_amount_cents, refund_amount_cents, currency_code,
  status, financial_operator_id, review_request_id, execution_request_id,
  transfer_idempotency_key, refund_idempotency_key
) VALUES (
  '${resolutionIdTwo}', 'test', 'human_dispute_review', '${contractIdTwo}', '${paymentIdTwo}', '${disputeIdTwo}',
  'partial_completion_approved', 1600, 900, 'USD', 'financial_execution_started',
  '${adultId}', '${requestIdTwo}', '${crypto.randomUUID()}', '${idem}_two_transfer', '${idem}_two_refund'
);
DO $fixture$
BEGIN
  PERFORM public.stripe_server_record_resolution_operation_result('${resolutionIdTwo}', 'test', 'transfer', 'failed', NULL, 'transfer_failed');
  PERFORM public.stripe_server_record_resolution_operation_result('${resolutionIdTwo}', 'test', 'refund', 'succeeded', '${refundIdTwo}', NULL);
  PERFORM public.stripe_server_record_resolution_result('${resolutionIdTwo}', 'test', NULL, '${refundIdTwo}', 'processing', 'transfer_failed');
END;
$fixture$;
SELECT transfer_status || '|' || refund_status || '|' || status || '|' ||
  (SELECT status FROM public.job_payment_obligations WHERE id = '${obligationId}')
FROM private.stripe_payment_resolutions WHERE id = '${resolutionIdTwo}';`);
  const rows = result.split(/\r?\n/).filter(Boolean);
  assertEquals(
    rows[0],
    "succeeded|failed|provider_processing|paid|failed",
    "successful transfer and failed refund remain separate and retryable",
  );
  assertEquals(
    rows[1],
    `succeeded|succeeded|completed|disputed|${idem}_transfer|${idem}_refund|1|1`,
    "same-key refund retry completes only after confirmed success and preserves dispute",
  );
  assertEquals(
    rows[2],
    "failed|succeeded|provider_processing|disputed",
    "failed transfer and successful refund do not close the resolution",
  );
});

Deno.test("expired webhook lease can be reclaimed and the prior worker is fenced out", async () => {
  const eventId = `evt_${crypto.randomUUID().replaceAll("-", "")}`;
  const paymentId = crypto.randomUUID();
  const paymentIntentId = `pi_${
    crypto.randomUUID().replaceAll("-", "").slice(0, 24)
  }`;
  const contractId = crypto.randomUUID();
  const versionId = crypto.randomUUID();
  const obligationId = crypto.randomUUID();
  const adultId = crypto.randomUUID();
  const teenId = crypto.randomUUID();
  const transferGroup = `MORT_JOB_${
    crypto.randomUUID().replaceAll("-", "").slice(0, 32)
  }`;
  const paymentIdempotencyKey = `mort_webhook_${
    crypto.randomUUID().replaceAll("-", "")
  }`;
  const digest = "a".repeat(64);
  const result = await executeLocalSql(`
SET LOCAL request.jwt.claim.role = 'service_role';
SET LOCAL session_replication_role = 'replica';
INSERT INTO private.stripe_job_payment_intents (
  id, contract_id, contract_version_id, obligation_id, adult_id, teen_id,
  environment, earnings_amount_cents, service_fee_cents, total_amount_cents,
  currency_code, provider_payment_intent_id, transfer_group, idempotency_key, status
) VALUES (
  '${paymentId}', '${contractId}', '${versionId}', '${obligationId}', '${adultId}', '${teenId}',
  'test', 2500, 0, 2500, 'USD', '${paymentIntentId}', '${transferGroup}', '${paymentIdempotencyKey}', 'requires_payment_method'
);
DO $fixture$
DECLARE
  v_first jsonb;
  v_in_flight jsonb;
  v_reclaimed jsonb;
  v_old_token uuid;
  v_new_token uuid;
  v_epoch bigint;
  v_payload jsonb := jsonb_build_object(
    'provider_payment_intent_id', '${paymentIntentId}',
    'provider_charge_id', NULL,
    'amount_cents', 2500,
    'currency_code', 'USD',
    'safe_failure_code', NULL
  );
BEGIN
  v_first := public.stripe_server_claim_webhook_event('test', '${eventId}', 'payment_intent.processing', now(), '${digest}');
  IF v_first->>'claimed' <> 'true' THEN RAISE EXCEPTION 'initial_claim_failed'; END IF;
  v_old_token := (v_first->>'lease_token')::uuid;
  v_in_flight := public.stripe_server_claim_webhook_event('test', '${eventId}', 'payment_intent.processing', now(), '${digest}');
  IF v_in_flight->>'claimed' <> 'false' OR v_in_flight->>'in_flight' <> 'true' THEN RAISE EXCEPTION 'active_lease_stolen'; END IF;
  UPDATE private.stripe_webhook_events SET lease_expires_at = clock_timestamp() - interval '1 second'
  WHERE environment = 'test' AND provider_event_id = '${eventId}';
  BEGIN
    PERFORM public.stripe_server_apply_webhook_event('test', '${eventId}', v_old_token, 'payment_intent.processing', v_payload);
    RAISE EXCEPTION 'expired_worker_was_not_rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'stripe_webhook_lease_lost' THEN RAISE; END IF;
  END;
  v_reclaimed := public.stripe_server_claim_webhook_event('test', '${eventId}', 'payment_intent.processing', now(), '${digest}');
  IF v_reclaimed->>'claimed' <> 'true' THEN RAISE EXCEPTION 'expired_lease_not_reclaimed'; END IF;
  v_new_token := (v_reclaimed->>'lease_token')::uuid;
  v_epoch := (v_reclaimed->>'lease_epoch')::bigint;
  IF v_old_token = v_new_token OR v_epoch <> 2 THEN RAISE EXCEPTION 'fencing_generation_not_advanced'; END IF;
  BEGIN
    PERFORM public.stripe_server_apply_webhook_event('test', '${eventId}', v_old_token, 'payment_intent.processing', v_payload);
    RAISE EXCEPTION 'stale_worker_was_not_rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'stripe_webhook_lease_lost' THEN RAISE; END IF;
  END;
  PERFORM public.stripe_server_apply_webhook_event('test', '${eventId}', v_new_token, 'payment_intent.processing', v_payload);
END;
$fixture$;
SELECT processing_status || '|' || lease_epoch::text || '|' || (lease_token IS NULL)::text || '|' || attempt_count::text
  || '|' || (SELECT status FROM private.stripe_job_payment_intents WHERE id = '${paymentId}')
FROM private.stripe_webhook_events WHERE environment = 'test' AND provider_event_id = '${eventId}';
`);
  assertEquals(
    result,
    "processed|2|true|2|processing",
    "expired/stale rejection and valid atomic payment mutation",
  );
});
Deno.test("overlapping webhook workers yield exactly one active lease owner", async () => {
  let arrived = 0;
  let releaseBarrier: (() => void) | undefined;
  const barrier = new Promise<void>((resolve) => {
    releaseBarrier = resolve;
  });
  let lock = Promise.resolve();
  let leaseToken: string | null = null;
  const claim = async (token: string) => {
    arrived += 1;
    if (arrived === 2) releaseBarrier?.();
    await barrier;
    let unlock: (() => void) | undefined;
    const previous = lock;
    lock = new Promise<void>((resolve) => {
      unlock = resolve;
    });
    await previous;
    try {
      if (leaseToken !== null) return { claimed: false, inFlight: true };
      leaseToken = token;
      return { claimed: true, inFlight: false };
    } finally {
      unlock?.();
    }
  };
  const claims = await Promise.all([claim("worker-a"), claim("worker-b")]);
  const owners = claims.filter((result) => result.claimed).length;
  const inFlight = claims.filter((result) => result.inFlight).length;
  assertEquals(
    `${owners}|${inFlight}`,
    "1|1",
    "overlapping webhook claim arbitration",
  );
});
Deno.test("resolution Edge Function records each provider outcome independently", async () => {
  const source = await Deno.readTextFile(
    new URL("../stripe-resolve-job-payment/index.ts", import.meta.url),
  );
  if (!source.includes("executeResolutionOperations")) {
    throw new Error(
      "stripe-resolve-job-payment does not use independent operation orchestration",
    );
  }
  if (!source.includes("stripe_server_record_resolution_operation_result")) {
    throw new Error(
      "stripe-resolve-job-payment does not persist per-operation provider outcomes",
    );
  }
  for (
    const stableKey of [
      "idempotencyKey: String(prepared.transfer_idempotency_key)",
      "idempotencyKey: String(prepared.refund_idempotency_key)",
    ]
  ) {
    if (!source.includes(stableKey)) {
      throw new Error(
        `stripe-resolve-job-payment does not pass the stable provider key: ${stableKey}`,
      );
    }
  }
});

Deno.test("operation orchestration keeps transfer and pending refund statuses separate", async () => {
  const trace: string[] = [];
  const result = await executeResolutionOperations({
    transferAmountCents: 1600,
    refundAmountCents: 900,
    createTransfer: async () => ({ id: "tr_test" }),
    createRefund: async () => ({ id: "re_test", status: "pending" }),
    recordOperation: async (operation, status) => {
      trace.push(`record:${operation}:${status}`);
    },
    finalize: async ({ providerStatus }) => {
      trace.push(`finalize:${providerStatus}`);
      return { status: "provider_processing" };
    },
  });
  assertEquals(
    `${result.transferStatus}|${result.refundStatus}|${result.resolutionStatus}|${
      trace.join(",")
    }`,
    "succeeded|pending|provider_processing|record:transfer:pending,record:transfer:succeeded,record:refund:pending,record:refund:pending,finalize:processing",
    "independent transfer/refund provider outcomes",
  );
});

Deno.test("ambiguous transfer outcome is recorded and prevents starting a refund", async () => {
  const trace: string[] = [];
  const result = await executeResolutionOperations({
    transferAmountCents: 1600,
    refundAmountCents: 900,
    createTransfer: async () => {
      throw new Error("transport reset");
    },
    createRefund: async () => {
      trace.push("refund-called");
      return { id: "re_should_not_exist", status: "succeeded" };
    },
    recordOperation: async (operation, status) => {
      trace.push(`record:${operation}:${status}`);
    },
    finalize: async ({ providerStatus }) => {
      trace.push(`finalize:${providerStatus}`);
      return { status: "provider_processing" };
    },
  });
  assertEquals(
    `${result.transferStatus}|${result.refundStatus}|${trace.join(",")}`,
    "unknown|unknown|record:transfer:pending,record:transfer:unknown,finalize:processing",
    "ambiguous transfer blocks subsequent refund",
  );
});

Deno.test("refund transport failure retains successful transfer and records refund unknown", async () => {
  const trace: string[] = [];
  const result = await executeResolutionOperations({
    transferAmountCents: 1600,
    refundAmountCents: 900,
    createTransfer: async () => ({ id: "tr_test" }),
    createRefund: async () => {
      throw new Error("transport reset");
    },
    recordOperation: async (operation, status) => {
      trace.push(`record:${operation}:${status}`);
    },
    finalize: async ({ providerStatus }) => {
      trace.push(`finalize:${providerStatus}`);
      return { status: "provider_processing" };
    },
  });
  assertEquals(
    `${result.transferStatus}|${result.refundStatus}|${trace.join(",")}`,
    "succeeded|unknown|record:transfer:pending,record:transfer:succeeded,record:refund:pending,record:refund:unknown,finalize:processing",
    "refund failure does not erase the successful transfer result",
  );
});

Deno.test("Stripe webhook handler routes mutations only through the lease-fenced dispatcher", async () => {
  const source = await Deno.readTextFile(
    new URL("../stripe-webhook/index.ts", import.meta.url),
  );
  if (
    !source.includes("stripe_server_apply_webhook_event") ||
    !source.includes("stripe_server_fail_webhook_event_fenced")
  ) {
    throw new Error("webhook handler is missing the fenced apply/failure RPCs");
  }
  for (
    const unsafeRpc of [
      "stripe_server_apply_payment_event",
      "stripe_server_apply_dispute_event",
      "stripe_server_apply_transfer_event",
      "stripe_server_apply_payout_event",
      "stripe_server_apply_refund_event",
      "stripe_server_complete_webhook_event",
      "stripe_server_fail_webhook_event",
    ]
  ) {
    if (source.includes(`\"${unsafeRpc}\"`)) {
      throw new Error(`webhook handler still directly calls ${unsafeRpc}`);
    }
  }
});
