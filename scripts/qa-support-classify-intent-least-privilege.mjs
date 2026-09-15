import { createClient } from "@supabase/supabase-js";
import { anonKey, assertQa, qaLog, supabaseUrl, withDatabase, withQaUsers } from "./feature-qa-helpers.mjs";

const scope = "qa-support-classify-intent-least-privilege";

const chainFunctions = [
  ["private", "support_classify_message", "text"],
  ["private", "support_classify_message_20260816010000", "text"],
  ["private", "support_classify_message_20260813110000", "text"],
  ["private", "support_classify_message_20260813101000", "text"],
  ["private", "support_take_rate_limit", "uuid, text, integer, integer"],
];

await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
  // AUTHENTICATED_CLASSIFICATION: a real authenticated caller must reach the
  // classification logic again (this is the actual bug being fixed -- every
  // real caller has been hitting a permission-denied error since the
  // 20260813030000 hardening pass dropped the wrapper's SECURITY DEFINER
  // posture).
  const authed = await teen.client.rpc("support_classify_intent", {
    p_message: "I cannot sign in to my account",
  });
  assertQa(
    !authed.error && authed.data?.ok === true,
    `AUTHENTICATED_CLASSIFICATION: call failed (${authed.error?.message ?? JSON.stringify(authed.data)})`,
  );
  assertQa(
    authed.data?.classification?.intent === "account_access",
    `AUTHENTICATED_CLASSIFICATION: expected account_access intent, got ${JSON.stringify(authed.data?.classification)}`,
  );
  qaLog(scope, "AUTHENTICATED_CLASSIFICATION=PASS");

  // ANON_CLASSIFICATION: anon is not intentionally part of the authenticated
  // support-classification contract (the wrapper's very first check is
  // auth.uid() is null), so the correct, restored behavior is a clean
  // application-level denial -- not a raw Postgres permission error, and not
  // a successful classification.
  const anonClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const anonAttempt = await anonClient.rpc("support_classify_intent", {
    p_message: "I cannot sign in to my account",
  });
  assertQa(
    !anonAttempt.error && anonAttempt.data?.ok === false && anonAttempt.data?.code === "authentication_required",
    `ANON_CLASSIFICATION: expected a clean authentication_required denial, got error=${anonAttempt.error?.message} data=${JSON.stringify(anonAttempt.data)}`,
  );
  qaLog(scope, "ANON_CLASSIFICATION=DENIED (clean authentication_required, not part of the contract)");

  // PRIVATE_HELPER_DIRECT_ACCESS, layer 1: the `private` schema is not in
  // PostgREST's exposed-schema list, so a real client cannot even route to
  // it -- calling it by name must fail before permissions are ever
  // evaluated.
  const directCall = await teen.client.rpc("support_classify_message", {
    p_message: "I cannot sign in to my account",
  });
  assertQa(
    directCall.error != null,
    "PRIVATE_HELPER_DIRECT_ACCESS: private.support_classify_message was reachable directly by an authenticated client -- it must not be",
  );
  qaLog(scope, `PRIVATE_HELPER_DIRECT_ACCESS (PostgREST routing)=DENIED (${directCall.error?.message ?? "not routable"})`);

  // PRIVATE_HELPER_DIRECT_ACCESS, layer 2: an independent GRANT-level check,
  // so this regression actually catches a future regression where someone
  // adds a direct grant on these functions (the PostgREST-routing check
  // above would still pass in that scenario, since it verifies a different,
  // independent containment layer -- config, not privilege).
  const grants = await withDatabase(async (database) => {
    const rows = [];
    for (const [schema, name, argTypes] of chainFunctions) {
      const result = await database.query(
        `select
           has_function_privilege('authenticated', format('%I.%I(%s)', $1::text, $2::text, $3::text)::regprocedure, 'execute') as authenticated_can_execute,
           has_function_privilege('anon', format('%I.%I(%s)', $1::text, $2::text, $3::text)::regprocedure, 'execute') as anon_can_execute`,
        [schema, name, argTypes],
      );
      rows.push({ schema, name, ...result.rows[0] });
    }
    return rows;
  });
  for (const row of grants) {
    assertQa(
      row.authenticated_can_execute === false && row.anon_can_execute === false,
      `PRIVATE_HELPER_EXPOSURE: ${row.schema}.${row.name} must remain unreachable by authenticated/anon (got authenticated=${row.authenticated_can_execute}, anon=${row.anon_can_execute})`,
    );
  }
  qaLog(scope, `PRIVATE_HELPER_EXPOSURE=MINIMAL (verified has_function_privilege()=false for authenticated/anon on all ${grants.length} chain functions)`);

  // NO_UNRELATED_PRIVILEGE_GAIN / INVALID_INPUT_FAILS_CLOSED: the restored
  // length validation still fails closed for a too-short message, exactly as
  // the original 2026-07-29 wrapper did.
  const tooShort = await teen.client.rpc("support_classify_intent", { p_message: "hi" });
  assertQa(
    !tooShort.error && tooShort.data?.ok === false && tooShort.data?.code === "invalid_support_message",
    `INVALID_INPUT_FAILS_CLOSED: too-short message was not rejected as invalid_support_message (${JSON.stringify(tooShort.data)})`,
  );
  qaLog(scope, "INVALID_INPUT_FAILS_CLOSED=PASS");
});

qaLog(scope, "support_classify_intent least-privilege restoration verified end-to-end with synthetic QA fixtures only");
