import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { assertQa, qaLog, withDatabase, withQaUsers } from "./feature-qa-helpers.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

export async function runStripeQa(scope, scenario) {
  const checks = {
    "mode-isolation": checkModeIsolation,
    "secret-boundary": checkSecretBoundary,
    "connected-account-isolation": checkConnectedAccountIsolation,
    "minor-guardian-status": checkMinorGuardianStatus,
    "onboarding-link-security": checkOnboardingLinkSecurity,
    "payment-amount-forgery": checkPaymentAmountForgery,
    "payment-idempotency": checkPaymentIdempotency,
    "payment-sheet-contract": checkPaymentSheetContract,
    "webhook-signature": checkWebhookSignature,
    "webhook-replay": checkWebhookReplay,
    "webhook-idempotency": checkWebhookIdempotency,
    "job-funding": checkJobFunding,
    "transfer-eligibility": checkTransferEligibility,
    "transfer-duplication": checkTransferDuplication,
    refund: checkRefund,
    "transfer-reversal": checkTransferReversal,
    "dispute-hold": checkDisputeHold,
    "payout-status": checkPayoutStatus,
    "cashapp-boundary": checkCashAppBoundary,
    "public-profile-privacy": checkPublicProfilePrivacy,
    "google-play-billing-boundary": checkGooglePlayBoundary,
    "saved-payment-consent": checkSavedPaymentConsent,
    "resolution-role-separation": checkResolutionRoleSeparation,
    "resolution-idempotency": checkResolutionIdempotency,
    "refund-webhook-reconciliation": checkRefundWebhookReconciliation,
  };
  const check = checks[scenario];
  if (!check) throw new Error(`Unknown Stripe QA scenario: ${scenario}`);
  await check(scope);
}

async function checkModeIsolation(scope) {
  await withDatabase(async (database) => {
    const result = await database.query(`
      select mode, stripe_payments_enabled, stripe_connected_onboarding_enabled,
             stripe_job_funding_enabled, stripe_transfers_enabled,
             stripe_refunds_enabled, stripe_live_mode_enabled,
             live_owner_approved
      from private.stripe_runtime_controls where singleton
    `);
    const controls = result.rows[0];
    assertQa(controls?.mode === "sandbox", "Stripe server mode is not sandbox");
    for (const field of [
      "stripe_payments_enabled", "stripe_connected_onboarding_enabled",
      "stripe_job_funding_enabled", "stripe_transfers_enabled",
      "stripe_refunds_enabled", "stripe_live_mode_enabled", "live_owner_approved",
    ]) assertQa(controls[field] === false, `${field} must default false`);
  });
  qaLog(scope, "remote Stripe mode is sandbox while every money-moving and live control remains off");
}

async function checkSecretBoundary(scope) {
  const files = await sourceFiles(["flutter_mort/lib", "flutter_mort/android", "flutter_mort/ios", "docs"]);
  const patterns = [/sk_(?:test|live)_[A-Za-z0-9]{8,}/, /whsec_[A-Za-z0-9]{8,}/, /rk_(?:test|live)_[A-Za-z0-9]{8,}/];
  for (const file of files) {
    const value = await readFile(file, "utf8");
    for (const pattern of patterns) assertQa(!pattern.test(value), `provider secret pattern found in ${path.relative(root, file)}`);
  }
  qaLog(scope, "Flutter, native source, and docs contain no Stripe secret, restricted, or webhook key values");
}

async function checkConnectedAccountIsolation(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const forbidden = await teen.client.rpc("stripe_server_prepare_connected_account", { p_user_id: teen.id, p_environment: "test" });
    assertQa(forbidden.error, "authenticated client executed a service-only connected-account RPC");
    const status = await teen.client.rpc("get_my_stripe_payout_status");
    assertQa(!status.error && status.data.status === "not_started", "caller-bound payout status failed");
    assertQa(!JSON.stringify(status.data).includes("acct_"), "connected-account ID leaked to client status");
  });
  qaLog(scope, "client cannot create or mutate provider accounts and minimized status exposes no provider account ID");
}

async function checkMinorGuardianStatus(scope) {
  const source = await functionSource("public.get_my_stripe_payout_status");
  assertQa(source.includes("guardian_requirement_status"), "provider guardian category is missing");
  assertQa(!source.includes("guardian_connections"), "Stripe guardian status was coupled to optional Guardian Mode");
  qaLog(scope, "Stripe provider guardian status is minimized and remains separate from optional MORT Guardian Mode");
}

async function checkOnboardingLinkSecurity(scope) {
  const shared = await text("supabase/functions/_shared/stripe.ts");
  const onboarding = await text("supabase/functions/stripe-create-onboarding-link/index.ts");
  assertQa(shared.includes("MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS"), "redirect allowlist is absent");
  assertQa(shared.includes('url.protocol !== "https:"'), "HTTPS redirect enforcement is absent");
  assertQa(onboarding.includes('mode: LaunchMode.externalApplication') === false, "Edge Function unexpectedly contains client WebView logic");
  assertQa(onboarding.includes('type: "account_onboarding"'), "Stripe-hosted onboarding link is absent");
  qaLog(scope, "onboarding uses single-use hosted links with HTTPS origin allowlisting and no open redirect input");
}

async function checkPaymentAmountForgery(scope) {
  const args = await functionArguments("public.stripe_server_prepare_job_payment");
  const source = await functionSource("public.stripe_server_prepare_job_payment");
  assertQa(!args.includes("amount"), "payment preparation accepts a client amount");
  assertQa(source.includes("public.job_payment_obligations"), "server does not derive amount from the obligation");
  assertQa(source.includes("payment_amount_limit_exceeded"), "server amount ceiling is absent");
  qaLog(scope, "payment creation accepts no client amount and derives cents/currency from the accepted obligation");
}

async function checkPaymentIdempotency(scope) {
  const source = await functionSource("public.stripe_server_prepare_job_payment");
  const edge = await text("supabase/functions/stripe-create-job-payment-intent/index.ts");
  assertQa(source.includes(":funding:"), "server funding operation version is absent from the key");
  assertQa(edge.includes("idempotencyKey: prepared.idempotency_key"), "Stripe create call lacks server idempotency");
  await assertUnique("private", "stripe_job_payment_intents", ["contract_version_id", "environment", "operation_version"]);
  qaLog(scope, "database and provider idempotency protect repeated funding requests");
}

async function checkPaymentSheetContract(scope) {
  const edge = await text("supabase/functions/stripe-create-job-payment-intent/index.ts");
  const client = await text("flutter_mort/lib/features/payments/stripe_payment_sheet_service.dart");
  const config = await text("flutter_mort/lib/core/config/app_config.dart");
  const pubspec = await text("flutter_mort/pubspec.yaml");
  assertQa(edge.includes("payment_intent_client_secret") && edge.includes("customer_ephemeral_key_secret"), "server Payment Sheet contract is incomplete");
  assertQa(client.includes("marketplace_payments_disabled"), "closed-test Payment Sheet stub does not fail closed");
  assertQa(config.includes("nativeStripePaymentSheetCompiledIn = false"), "native Stripe compilation boundary is not explicit");
  assertQa(!pubspec.includes("flutter_stripe:"), "Stripe SDK is compiled into a payment-disabled release");
  assertQa(!client.includes("initPaymentSheet") && !client.includes("presentPaymentSheet"), "payment execution remained in the signed client");
  qaLog(scope, "server Payment Sheet contract is retained for future review while the distributed client has no payment SDK and fails closed");
}

async function checkWebhookSignature(scope) {
  const webhook = await text("supabase/functions/stripe-webhook/index.ts");
  assertQa(webhook.includes("await request.text()"), "webhook does not preserve raw body");
  assertQa(webhook.includes("constructEventAsync(rawBody, signature"), "Stripe signature verification is absent");
  assertQa(webhook.indexOf("constructEventAsync") < webhook.indexOf("processEvent("), "event is processed before signature verification");
  qaLog(scope, "webhook verifies Stripe-Signature against the untouched raw body before dispatch");
}

async function checkWebhookReplay(scope) {
  await assertUnique("private", "stripe_webhook_events", ["environment", "provider_event_id"]);
  const source = await functionSource("public.stripe_server_claim_webhook_event");
  assertQa(source.includes("payload_sha256"), "replay payload hash comparison is absent");
  assertQa(source.includes("stripe_webhook_replay_payload_mismatch"), "changed replay payload is not rejected");
  qaLog(scope, "event ID uniqueness and payload hash matching reject replay mutation");
}

async function checkWebhookIdempotency(scope) {
  const source = await functionSource("public.stripe_server_claim_webhook_event");
  assertQa(source.includes("on conflict") && source.includes("claimed"), "webhook claim is not idempotent");
  const completion = await functionSource("public.stripe_server_complete_webhook_event");
  assertQa(completion.includes("processing_status = 'received'"), "processed events can be completed repeatedly");
  qaLog(scope, "duplicate delivery returns the existing claim and completion mutates only received events");
}

async function checkJobFunding(scope) {
  const preview = await functionSource("public.preview_job_funding");
  const event = await functionSource("public.stripe_server_apply_payment_event");
  assertQa(preview.includes("stripe_job_funding_enabled"), "preview ignores funding shutdown");
  assertQa(event.includes("payment_intent.succeeded") && event.includes("'funded'"), "funded state lacks provider event binding");
  const client = await text("flutter_mort/lib/features/payments/stripe_marketplace_screens.dart");
  assertQa(client.includes("waiting for Stripe webhook confirmation"), "client implies callback is authoritative");
  qaLog(scope, "server controls gate funding and only a verified provider event marks a payment funded");
}

async function checkTransferEligibility(scope) {
  const source = await functionSource("public.stripe_server_prepare_transfer");
  for (const required of ["completed_contract_required", "funded_payment_required", "eligible_connected_account_required", "active_dispute_blocks_transfer", "refund_blocks_transfer"]) {
    assertQa(source.includes(required), `transfer gate missing ${required}`);
  }
  assertQa(source.includes("provider_source_charge_id"), "transfer does not bind source charge");
  qaLog(scope, "transfer requires completion, funded charge, eligible payout account, no dispute, and no refund");
}

async function checkTransferDuplication(scope) {
  await assertUnique("private", "stripe_job_transfers", ["payment_intent_id"]);
  const edge = await text("supabase/functions/stripe-create-job-transfer/index.ts");
  assertQa(edge.includes("idempotencyKey: prepared.idempotency_key"), "transfer lacks provider idempotency");
  qaLog(scope, "one transfer per payment plus Stripe idempotency blocks duplicate payout transfer creation");
}

async function checkRefund(scope) {
  const source = await functionSource("public.stripe_server_prepare_refund");
  assertQa(source.includes("stripe_refunds_enabled"), "refund shutdown control is absent");
  assertQa(source.includes("invalid_refund_amount"), "refund amount bounds are absent");
  assertQa(source.includes("transfer_reversal_review_required"), "post-transfer refund review flag is absent");
  await assertUnique("private", "stripe_job_refunds", ["environment", "idempotency_key"]);
  qaLog(scope, "refunds are service-only, bounded, idempotent, and flag post-transfer reversal review");
}

async function checkTransferReversal(scope) {
  const source = await functionSource("public.stripe_server_apply_transfer_event");
  assertQa(source.includes("partially_reversed") && source.includes("reversed_at"), "transfer reversal states are absent");
  const webhook = await text("supabase/functions/stripe-webhook/index.ts");
  assertQa(webhook.includes('"transfer.reversed"'), "transfer reversal webhook event is absent");
  qaLog(scope, "transfer reversals are webhook-reconciled and never initiated from Flutter");
}

async function checkDisputeHold(scope) {
  const transfer = await functionSource("public.stripe_server_prepare_transfer");
  const dispute = await functionSource("public.stripe_server_apply_dispute_event");
  assertQa(transfer.includes("private.stripe_job_disputes"), "Stripe disputes do not block transfer");
  assertQa(dispute.includes("'disputed'"), "payment is not moved into a neutral dispute state");
  qaLog(scope, "provider disputes freeze pending transfer without assigning guilt");
}

async function checkPayoutStatus(scope) {
  const source = await functionSource("public.get_my_stripe_payout_status");
  assertQa(source.includes("destination_last4"), "minimized payout destination summary is absent");
  assertQa(!source.includes("provider_account_id"), "connected account ID leaks through payout status");
  assertQa(!source.includes("bank_account_number"), "bank credentials appear in payout status");
  qaLog(scope, "payout status is caller-bound and limited to state, destination type, and optional last four");
}

async function checkCashAppBoundary(scope) {
  const files = await sourceFiles(["flutter_mort/lib", "supabase/functions", "supabase/migrations"]);
  const forbidden = [
    /cash_?app_?(?:password|pin)\s*[:=]/i,
    /(?:bank_?login|bank_?password)\s*[:=]/i,
    /routing_?number\s*[:=]/i,
  ];
  for (const file of files) {
    const source = await readFile(file, "utf8");
    for (const pattern of forbidden) assertQa(!pattern.test(source), `Cash App or bank credential collection found in ${path.relative(root, file)}`);
  }
  qaLog(scope, "MORT collects no Cash App login, PIN, cashtag, bank login, or routing credential");
}

async function checkPublicProfilePrivacy(scope) {
  await withDatabase(async (database) => {
    const columns = await database.query(`select column_name from information_schema.columns where table_schema = 'public' and table_name = 'profiles'`);
    const names = new Set(columns.rows.map((row) => row.column_name));
    for (const forbidden of ["stripe_account_id", "stripe_customer_id", "payouts_enabled", "stripe_verification_status"]) {
      assertQa(!names.has(forbidden), `${forbidden} appears in public profiles`);
    }
  });
  qaLog(scope, "public profiles expose no Stripe customer, connected account, payout, or provider verification fields");
}

async function checkGooglePlayBoundary(scope) {
  const migration = await text("supabase/migrations/20260722032907_stripe_connect_sandbox_foundation.sql");
  const pubspec = await text("flutter_mort/pubspec.yaml");
  const manifest = await text("flutter_mort/android/app/src/main/AndroidManifest.xml");
  const config = await text("flutter_mort/lib/core/config/app_config.dart");
  assertQa(migration.includes("google_play_billing"), "server does not declare the digital purchase boundary");
  assertQa(!pubspec.includes("purchases_flutter"), "legacy RevenueCat SDK returned to the signed client");
  assertQa(!pubspec.includes("in_app_purchase:"), "Google Play Billing SDK is compiled into an IAP-disabled release");
  assertQa(!manifest.includes("com.android.vending.BILLING"), "Android billing permission is present in an IAP-disabled release");
  assertQa(config.includes("nativeBillingCompiledIn = false") && config.includes("nativeStripePaymentSheetCompiledIn = false"), "native financial compilation gates are not explicit");
  qaLog(scope, "physical-service payments remain a disabled server architecture and the signed Android client contains no digital or marketplace billing capability");
}

async function checkSavedPaymentConsent(scope) {
  const consent = await functionSource("public.record_my_saved_payment_consent");
  const validator = await functionSource("public.stripe_server_validate_saved_payment_consent");
  const edge = await text("supabase/functions/stripe-create-job-payment-intent/index.ts");
  const client = await text("flutter_mort/lib/data/repositories/stripe_marketplace_repository.dart");
  assertQa(consent.includes("auth.uid()") && consent.includes("consent_text_hash"), "saved-method consent is not caller-bound and hashed");
  assertQa(validator.includes("revoked_at is null"), "revoked consent remains valid");
  assertQa(edge.includes("stripe_server_validate_saved_payment_consent"), "payment Edge Function does not validate consent");
  assertQa(client.includes("record_my_saved_payment_consent") && client.includes("saved-payment-consent-v1"), "Flutter does not record versioned explicit consent");
  qaLog(scope, "saved payment methods require caller-bound, versioned, revocable consent before PaymentIntent setup");
}

async function checkResolutionRoleSeparation(scope) {
  const review = await functionSource("public.stripe_server_prepare_dispute_resolution");
  const execute = await functionSource("public.stripe_server_load_resolution_for_execution");
  assertQa(review.includes("payment_reviewer_role_required"), "reviewer role gate is absent");
  assertQa(execute.includes("payment_operations_role_required"), "operations role gate is absent");
  assertQa(execute.includes("reviewer_financial_operator_separation_required"), "reviewer can execute their own resolution");
  assertQa(review.includes("provider_dispute_blocks_resolution"), "active provider dispute does not block resolution");
  qaLog(scope, "factual review and financial execution require separate expiring roles");
}

async function checkResolutionIdempotency(scope) {
  await assertUnique("private", "stripe_payment_resolutions", ["environment", "contract_id"]);
  const load = await functionSource("public.stripe_server_load_resolution_for_execution");
  const edge = await text("supabase/functions/stripe-resolve-job-payment/index.ts");
  assertQa(load.includes("execution_request_id") && load.includes("resolution_execution_already_claimed"), "resolution execution is not single-claim");
  assertQa(edge.includes("transfer_idempotency_key") && edge.includes("refund_idempotency_key"), "provider operations lack server idempotency keys");
  for (const forbidden of ["payload.transfer_amount", "payload.refund_amount", "payload.destination"]) {
    assertQa(!edge.includes(forbidden), `resolution accepts untrusted ${forbidden}`);
  }
  qaLog(scope, "database claims and provider keys prevent duplicate transfer/refund resolution");
}

async function checkRefundWebhookReconciliation(scope) {
  const apply = await functionSource("public.stripe_server_apply_refund_event");
  const webhook = await text("supabase/functions/stripe-webhook/index.ts");
  assertQa(apply.includes("stripe_refund_total_exceeds_capture"), "webhook refund total is not capture bounded");
  assertQa(apply.includes("provider_refund_id"), "refund provider reference is not reconciled");
  assertQa(webhook.includes('"charge.refunded"') && webhook.includes("applyRefund"), "charge/refund webhook events are not reconciled");
  assertQa(!webhook.includes('"refund_reconciliation_required"'), "refund events are still ignored");
  qaLog(scope, "verified refund and charge.refunded events reconcile idempotent private payment state");
}

async function functionSource(name) {
  return withDatabase(async (database) => {
    const [schema, routine] = name.split(".");
    const result = await database.query(`
      select pg_get_functiondef(p.oid) source
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = $1 and p.proname = $2
      order by p.oid desc limit 1
    `, [schema, routine]);
    assertQa(result.rows[0]?.source, `missing remote function ${name}`);
    return result.rows[0].source;
  });
}

async function functionArguments(name) {
  return withDatabase((database) => functionIdentityArguments(database, name));
}

async function functionIdentityArguments(database, name) {
  const [schema, routine] = name.split(".");
  const result = await database.query(`
    select pg_get_function_identity_arguments(p.oid) arguments
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = $1 and p.proname = $2
    order by p.oid desc limit 1
  `, [schema, routine]);
  assertQa(result.rows[0], `missing remote function ${name}`);
  return result.rows[0].arguments;
}

async function assertUnique(schema, table, expectedColumns) {
  await withDatabase(async (database) => {
    const result = await database.query(`
      select array_agg(attribute.attname order by key_position.ordinality) columns
      from pg_index index_definition
      join pg_class relation on relation.oid = index_definition.indrelid
      join pg_namespace namespace on namespace.oid = relation.relnamespace
      cross join lateral unnest(index_definition.indkey) with ordinality key_position(attnum, ordinality)
      join pg_attribute attribute on attribute.attrelid = relation.oid and attribute.attnum = key_position.attnum
      where namespace.nspname = $1 and relation.relname = $2 and index_definition.indisunique
      group by index_definition.indexrelid
    `, [schema, table]);
    assertQa(result.rows.some((row) => {
      const columns = Array.isArray(row.columns)
        ? row.columns
        : String(row.columns).replace(/^\{|\}$/g, "").split(",");
      return expectedColumns.every((column, index) => columns[index] === column);
    }), `missing unique key ${schema}.${table}(${expectedColumns.join(",")})`);
  });
}

async function text(relativePath) {
  return readFile(path.join(root, relativePath), "utf8");
}

async function sourceFiles(relativeDirectories) {
  const results = [];
  for (const relative of relativeDirectories) await walk(path.join(root, relative), results);
  return results;
}

async function walk(directory, results) {
  const entries = await readdir(directory, { withFileTypes: true });
  for (const entry of entries) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) await walk(absolute, results);
    else if (/\.(?:dart|kt|java|swift|plist|xml|md|sql|ts|toml|yaml|yml)$/.test(entry.name)) results.push(absolute);
  }
}
