import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifestMode = process.argv.includes("--regression-manifest");

const forbiddenEvidencePatterns = [
  /\bsk_(?:test|live)_[A-Za-z0-9_-]{8,}\b/i,
  /\bpk_(?:test|live)_[A-Za-z0-9_-]{8,}\b/i,
  /\bwhsec_[A-Za-z0-9_-]{8,}\b/i,
  /\bpi_[A-Za-z0-9]+_secret_[A-Za-z0-9_-]+\b/i,
  /\b\d{12,19}\b/,
];

export function validateSandboxEvidence(payload) {
  assert(payload && typeof payload === "object" && !Array.isArray(payload));
  assert.equal(payload.environment, "test");
  assert.notEqual(payload.mode, "live");
  assert.equal(payload.live_mode_detected ?? false, false);
  const serialized = JSON.stringify(payload);
  for (const pattern of forbiddenEvidencePatterns) {
    assert.equal(pattern.test(serialized), false, `unsafe evidence matched ${pattern}`);
  }
  if (payload.complete === true) {
    const required = [
      "capture_success", "capture_decline", "requires_action", "processing_or_pending",
      "network_ambiguity", "duplicate_submission", "webhook_duplicate", "webhook_out_of_order",
      "webhook_lease_retry", "full_refund", "partial_refund", "exact_transfer", "transfer_reversal",
      "transfer_reversal_failure", "tip_success", "tip_failure", "dispute_won", "dispute_lost",
      "payout_separation", "minor_account_restricted", "minor_account_ready", "cross_user_denial",
    ];
    const ids = new Set((payload.scenarios ?? []).filter((x) => x?.status === "pass").map((x) => x.id));
    for (const id of required) assert(ids.has(id), `missing sandbox evidence scenario ${id}`);
  }
  return true;
}

async function validateRegressionManifest() {
  const runner = await readFile(path.join(root, "scripts", "run-mort-stripe-regression.ps1"), "utf8");
  const finalRegression = await readFile(path.join(root, "scripts", "run-final-supabase-regression.ps1"), "utf8");
  const workflow = await readFile(path.join(root, ".github", "workflows", "mort-ci.yml"), "utf8");

  const requiredRunnerTokens = [
    "local-supabase-start.ps1",
    "local-supabase-reset.ps1",
    "supabase migration list --local",
    "run-final-supabase-regression.ps1",
    "qa-stripe-pre-provider-gate.mjs",
    "deno test --allow-read --allow-env supabase/functions/_tests",
    "audit-supabase-advisors.mjs",
    "dart format --output=none --set-exit-if-changed lib test integration_test",
    "flutter analyze --no-pub",
    "flutter test --no-pub",
    "secret-scan.ps1",
    "secret_extraction_scan.mjs",
    "secret-scan-git-history.mjs",
    "provider_e2e_executed = $false",
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
  "qa-stripe-settlement-policy.mjs"

  "qa-stripe-activation-gates.mjs",
  "qa-stripe-financial-access.mjs",
  "qa-stripe-financial-documents.mjs",
  "qa-stripe-financial-history.mjs",
  "qa-stripe-observability.mjs",];
  for (const token of requiredStripeQa) {
    assert(finalRegression.includes(token), `final Supabase regression missing ${token}`);
  }

  for (const token of [
    "stripe-contracts:",
    "qa-stripe-pre-provider-gate.mjs",
    "deno test --allow-read --allow-env supabase/functions/_tests",
    "stripe-hosted-regression:",
    "workflow_dispatch",
    "run-mort-stripe-regression.ps1",
  ]) {
    assert(workflow.includes(token), `CI workflow missing ${token}`);
  }
  assert(!/stripe-sandbox-e2e\.ps1/.test(workflow), "provider sandbox E2E must not run in ordinary CI manifest");
  return true;
}

if (manifestMode) {
  await validateRegressionManifest();
  console.log(JSON.stringify({ status: "PASS", mode: "regression_manifest", provider_e2e_executed: false }));
} else {
  validateSandboxEvidence({
    environment: "test",
    mode: "sandbox",
    live_mode_detected: false,
    complete: false,
    scenarios: [],
  });
  assert.throws(() => validateSandboxEvidence({ environment: "test", mode: "sandbox", leaked: "sk_test_1234567890abcdef" }));
  assert.throws(() => validateSandboxEvidence({ environment: "test", mode: "live" }));
  console.log(JSON.stringify({ status: "PASS", mode: "evidence_fixture", provider_e2e_executed: false }));
}
