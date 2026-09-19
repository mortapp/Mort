import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifestMode = process.argv.includes("--regression-manifest");
const evidencePath = process.argv.slice(2).find((argument) => !argument.startsWith("--"));

export const requiredSandboxScenarioIds = Object.freeze([
  "capture_success",
  "capture_decline",
  "requires_action",
  "processing_or_pending",
  "network_ambiguity",
  "duplicate_submission",
  "webhook_duplicate",
  "webhook_out_of_order",
  "webhook_lease_retry",
  "full_refund",
  "partial_refund",
  "exact_transfer",
  "transfer_reversal",
  "transfer_reversal_failure",
  "tip_success",
  "tip_failure",
  "dispute_won",
  "dispute_lost",
  "payout_separation",
  "minor_account_restricted",
  "minor_account_ready",
  "cross_user_denial",
]);

const forbiddenEvidencePatterns = [
  /\bsk_(?:test|live)_[A-Za-z0-9_-]{8,}\b/i,
  /\bpk_(?:test|live)_[A-Za-z0-9_-]{8,}\b/i,
  /\bwhsec_[A-Za-z0-9_-]{8,}\b/i,
  /\brk_(?:test|live)_[A-Za-z0-9_-]{8,}\b/i,
  /\bpi_[A-Za-z0-9]+_secret_[A-Za-z0-9_-]+\b/i,
  /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/,
  /\b\d{12,19}\b/,
  /\b(?:pi|ch|tr|re|dp|po|acct|evt|cus)_[A-Za-z0-9]{6,}\b/i,
];

const safeReferencePattern = /^[A-Za-z0-9_-]{4,16}$/;

function assertSafeReference(value, field) {
  if (value === null || value === undefined) return;
  assert.equal(typeof value, "string", `${field} must be a string or null`);
  assert(
    safeReferencePattern.test(value),
    `${field} must be a short opaque suffix, not a full provider or internal identifier`,
  );
}

export function validateSandboxEvidence(payload) {
  assert(payload && typeof payload === "object" && !Array.isArray(payload));
  assert.equal(payload.environment, "test");
  assert.equal(payload.mode, "sandbox");
  assert.equal(payload.live_mode_detected ?? false, false);

  const serialized = JSON.stringify(payload);
  for (const pattern of forbiddenEvidencePatterns) {
    assert.equal(pattern.test(serialized), false, `unsafe evidence matched ${pattern}`);
  }

  const scenarios = Array.isArray(payload.scenarios) ? payload.scenarios : [];
  const seen = new Set();
  for (const scenario of scenarios) {
    assert(scenario && typeof scenario === "object" && !Array.isArray(scenario));
    assert.equal(typeof scenario.id, "string");
    assert(!seen.has(scenario.id), `duplicate sandbox evidence scenario ${scenario.id}`);
    seen.add(scenario.id);
    assertSafeReference(scenario.request_ref, `${scenario.id}.request_ref`);
    assertSafeReference(scenario.trace_ref, `${scenario.id}.trace_ref`);
    assertSafeReference(
      scenario.provider_object_suffix,
      `${scenario.id}.provider_object_suffix`,
    );
  }

  if (payload.complete === true) {
    assert.equal(payload.gate_passed, true, "complete evidence requires a passing pre-provider gate");
    assert.equal(
      payload.connect_webhook_preflight_passed,
      true,
      "complete evidence requires the TEST Connect webhook signing preflight",
    );
    assert.equal(
      payload.provider_e2e_executed,
      true,
      "complete evidence requires actual sandbox provider execution",
    );

    const passed = new Set(
      scenarios
        .filter((scenario) => scenario.status === "pass")
        .map((scenario) => scenario.id),
    );
    for (const id of requiredSandboxScenarioIds) {
      assert(passed.has(id), `missing sandbox evidence scenario ${id}`);
    }

    assert.equal(
      Number(payload.reconciliation?.unreconciled_count),
      0,
      "complete evidence requires zero unreconciled provider objects",
    );
    assert.equal(
      Number(payload.no_live_money_proof?.live_objects_detected),
      0,
      "live Stripe objects were detected",
    );
    assert.equal(
      payload.no_live_money_proof?.live_credentials_detected,
      false,
      "live credentials were detected",
    );
    assert.equal(
      payload.no_live_money_proof?.real_card_data_used,
      false,
      "real card data must never be used",
    );
  }

  return true;
}

async function validateTask31SourceContracts() {
  const runner = await readFile(
    path.join(root, "scripts", "stripe-sandbox-e2e.ps1"),
    "utf8",
  );
  const connectPreflight = await readFile(
    path.join(root, "scripts", "stripe-connect-webhook-preflight.ps1"),
    "utf8",
  );
  const trigger = await readFile(
    path.join(root, "scripts", "stripe-trigger-test-events.ps1"),
    "utf8",
  );
  const listener = await readFile(
    path.join(root, "scripts", "stripe-listen-test.ps1"),
    "utf8",
  );
  const docs = await readFile(
    path.join(root, "docs", "payments", "MORT_STRIPE_CLI_TESTING.md"),
    "utf8",
  );

  assert(runner.includes("stripe-pre-provider-test-gate.ps1"));
  assert(runner.includes("stripe-connect-webhook-preflight.ps1"));
  assert(runner.includes("[switch]$ExecuteProvider"));
  assert(runner.includes("provider_e2e_executed = $false"));
  assert(runner.includes("live_mode_detected = $false"));
  assert(runner.includes("MORT_STRIPE_MODE must be sandbox"));
  assert(runner.includes("ScenarioEvidencePath"));

  for (const id of requiredSandboxScenarioIds) {
    assert(runner.includes(`'${id}'`), `sandbox runner missing scenario ${id}`);
  }

  const gateIndex = runner.indexOf("stripe-pre-provider-test-gate.ps1");
  const connectIndex = runner.indexOf("stripe-connect-webhook-preflight.ps1");
  const providerSwitchIndex = runner.indexOf("if (-not $ExecuteProvider)");
  assert(gateIndex >= 0 && connectIndex > gateIndex, "Connect preflight must follow the Task 30 gate");
  assert(providerSwitchIndex > connectIndex, "both read-only gates must run before provider execution is allowed");

  assert(connectPreflight.includes("STRIPE_TEST_CONNECT_WEBHOOK_SECRET"));
  assert(connectPreflight.includes("STRIPE_LIVE_CONNECT_WEBHOOK_SECRET"));
  assert(!/stripe\s+(?:trigger|payment_intents|charges|refunds|transfers)/i.test(connectPreflight));

  assert(trigger.includes("[switch]$Execute"));
  assert(trigger.includes("if (-not $Execute)"));
  assert(trigger.includes("payment_intent.requires_action"));
  assert(/diagnostic only/i.test(trigger));
  assert(/do not count as MORT sandbox E2E evidence|do not count as MORT end-to-end payment evidence|cannot satisfy MORT end-to-end payment evidence/i.test(trigger));

  assert(listener.includes("[switch]$Execute"));
  assert(listener.includes("if (-not $Execute)"));
  assert(listener.includes("payment_intent.requires_action"));
  assert(listener.includes("MORT_STRIPE_MODE must be sandbox"));

  assert(/generic CLI fixtures/i.test(docs));
  assert(/MORT.*sandbox/i.test(docs));
  return true;
}

async function validateRegressionManifest() {
  const runner = await readFile(
    path.join(root, "scripts", "run-mort-stripe-regression.ps1"),
    "utf8",
  );
  const finalRegression = await readFile(
    path.join(root, "scripts", "run-final-supabase-regression.ps1"),
    "utf8",
  );
  const workflow = await readFile(
    path.join(root, ".github", "workflows", "mort-ci.yml"),
    "utf8",
  );

  const requiredRunnerTokens = [
    "local-supabase-start.ps1",
    "local-supabase-reset.ps1",
    "supabase migration list --local",
    "run-final-supabase-regression.ps1",
    "qa-stripe-pre-provider-gate.mjs",
    "deno test --node-modules-dir=auto --allow-read --allow-env supabase/functions/_tests",
    "audit-supabase-advisors.mjs",
    "dart format --output=none --set-exit-if-changed lib test integration_test",
    "flutter analyze --no-pub",
    "flutter test --no-pub test/features/payment_os_integration_test.dart",
    "flutter test --no-pub",
    "secret-scan.ps1",
    "secret_extraction_scan.mjs",
    "secret-scan-git-history.mjs",
    "provider_e2e_executed = $false",
    "mort_stripe_policy_and_funding_v1",
    "mort_stripe_funding_attempts_and_state_v1",
    "mort_stripe_webhook_lease_v1",
    "mort_stripe_settlement_ledger_v1",
    "mort_financial_documents_history_v1",
    "mort_stripe_financial_access_hardening_v1",
    "evidence_matrix",
    "command",
    "commit",
    "timestamp",
    "result",
    "environment",
  ];
  for (const token of requiredRunnerTokens) {
    assert(runner.includes(token), `regression runner missing ${token}`);
  }

  const requiredStripeQa = [
    "qa-stripe-mode-isolation.mjs",
    "qa-stripe-secret-boundary.mjs",
    "qa-stripe-connected-account-isolation.mjs",
    "qa-stripe-minor-guardian-status.mjs",
    "qa-stripe-onboarding-link-security.mjs",
    "qa-stripe-payment-amount-forgery.mjs",
    "qa-stripe-payment-idempotency.mjs",
    "qa-stripe-payment-sheet-contract.mjs",
    "qa-stripe-webhook-signature.mjs",
    "qa-stripe-webhook-replay.mjs",
    "qa-stripe-webhook-idempotency.mjs",
    "qa-stripe-job-funding.mjs",
    "qa-stripe-transfer-eligibility.mjs",
    "qa-stripe-transfer-duplication.mjs",
    "qa-stripe-refund.mjs",
    "qa-stripe-transfer-reversal.mjs",
    "qa-stripe-dispute-hold.mjs",
    "qa-stripe-payout-status.mjs",
    "qa-stripe-cashapp-boundary.mjs",
    "qa-stripe-public-profile-privacy.mjs",
    "qa-stripe-google-play-billing-boundary.mjs",
    "qa-stripe-saved-payment-consent.mjs",
    "qa-stripe-resolution-role-separation.mjs",
    "qa-stripe-resolution-idempotency.mjs",
    "qa-stripe-refund-webhook-reconciliation.mjs",
    "qa-stripe-policy-versioning.mjs",
    "qa-stripe-funding-quote.mjs",
    "qa-stripe-settlement-policy.mjs",
    "qa-stripe-activation-gates.mjs",
    "qa-stripe-financial-access.mjs",
    "qa-stripe-financial-documents.mjs",
    "qa-stripe-financial-history.mjs",
    "qa-stripe-observability.mjs",
  ];
  for (const token of requiredStripeQa) {
    assert(
      finalRegression.includes(token),
      `final Supabase regression missing ${token}`,
    );
  }

  for (const token of [
    "PLAY_REVIEW_TEEN_EMAIL",
    "PLAY_REVIEW_TEEN_PASSWORD",
    "PLAY_REVIEW_ADULT_EMAIL",
    "PLAY_REVIEW_ADULT_PASSWORD",
  ]) {
    assert(workflow.includes(token), `CI workflow missing protected QA variable ${token}`);
  }
  assert(
    finalRegression.includes("Process") &&
      finalRegression.includes("Set-MortPlayReviewEnvironment"),
    "final Supabase regression must support CI process environment with local fallback",
  );

  for (const token of [
    "stripe-contracts:",
    "qa-stripe-pre-provider-gate.mjs",
    "deno test --node-modules-dir=auto --allow-read --allow-env supabase/functions/_tests",
    "flutter test --no-pub test/features/payment_os_integration_test.dart",
    "stripe-hosted-regression:",
    "stripe-provider-e2e:",
    "workflow_dispatch",
    "run-mort-stripe-regression.ps1",
    "stripe-sandbox-e2e.ps1",
  ]) {
    assert(workflow.includes(token), `CI workflow missing ${token}`);
  }
  const ordinaryStripeJob = workflow.split("  stripe-contracts:")[1]?.split("\n  expo-reference:")[0] ?? "";
  assert(
    !/stripe-sandbox-e2e\.ps1/.test(ordinaryStripeJob),
    "provider sandbox E2E must not run in ordinary pull-request Stripe contracts",
  );
  const providerJob = workflow.split("  stripe-provider-e2e:")[1] ?? "";
  assert(
    providerJob.includes("github.event_name == 'workflow_dispatch'"),
    "provider sandbox E2E must be workflow_dispatch-only",
  );
  assert(
    providerJob.includes("stripe-sandbox-e2e.ps1"),
    "manual provider job must execute the Task 31 gated runner",
  );
  return true;
}

function completeFixture() {
  return {
    environment: "test",
    mode: "sandbox",
    gate_passed: true,
    connect_webhook_preflight_passed: true,
    provider_e2e_executed: true,
    live_mode_detected: false,
    complete: true,
    scenarios: requiredSandboxScenarioIds.map((id) => ({
      id,
      status: "pass",
      result_code: "verified",
      request_ref: "req1234",
      trace_ref: "trace5678",
      provider_object_suffix: "obj9012",
    })),
    reconciliation: { unreconciled_count: 0 },
    no_live_money_proof: {
      live_objects_detected: 0,
      live_credentials_detected: false,
      real_card_data_used: false,
    },
  };
}

if (manifestMode) {
  await validateRegressionManifest();
  console.log(
    JSON.stringify({
      status: "PASS",
      mode: "regression_manifest",
      provider_e2e_executed: false,
    }),
  );
} else if (evidencePath) {
  const payload = JSON.parse(await readFile(path.resolve(evidencePath), "utf8"));
  validateSandboxEvidence(payload);
  console.log(
    JSON.stringify({
      status: "PASS",
      mode: "sandbox_evidence",
      complete: payload.complete === true,
      provider_e2e_executed: payload.provider_e2e_executed === true,
    }),
  );
} else {
  await validateTask31SourceContracts();

  validateSandboxEvidence({
    environment: "test",
    mode: "sandbox",
    live_mode_detected: false,
    complete: false,
    scenarios: [],
  });
  validateSandboxEvidence(completeFixture());

  const missing = completeFixture();
  missing.scenarios = missing.scenarios.filter(
    (scenario) => scenario.id !== "requires_action",
  );
  assert.throws(() => validateSandboxEvidence(missing));

  assert.throws(() =>
    validateSandboxEvidence({
      environment: "test",
      mode: "sandbox",
      leaked: "sk_test_1234567890abcdef",
    })
  );
  assert.throws(() =>
    validateSandboxEvidence({
      environment: "test",
      mode: "live",
      live_mode_detected: true,
    })
  );
  assert.throws(() => {
    const unsafe = completeFixture();
    unsafe.scenarios[0].provider_object_suffix = "pi_1234567890";
    validateSandboxEvidence(unsafe);
  });

  console.log(
    JSON.stringify({
      status: "PASS",
      mode: "task31_fixture_and_source_contract",
      scenarios: requiredSandboxScenarioIds.length,
      provider_e2e_executed: false,
    }),
  );
}
