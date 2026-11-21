import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { validateCurrentRunEvidence } from "./stripe-current-run-evidence.mjs";

const qa = "ckcxakhxqlkhppsxxjhv";
const context = {
  projectRef: qa,
  commitSha: "a".repeat(40),
  runId: "1234567",
  runAttempt: "2",
  notBefore: "2026-11-21T15:00:00.0000000+00:00",
};
const current = {
  project_ref: qa,
  environment: "test",
  mode: "sandbox",
  live_mode_detected: false,
  provider_e2e_executed: true,
  commit_sha: context.commitSha,
  workflow_run_id: context.runId,
  workflow_run_attempt: context.runAttempt,
  completed_at: "2026-11-21T15:01:00.000Z",
};
const now = Date.parse("2026-11-21T15:02:00Z");

test("same-run QA evidence matches without claiming a provider action", () => {
  assert.doesNotThrow(() => validateCurrentRunEvidence(current, context, now));
});

for (const [name, change] of Object.entries({
  stale: { completed_at: "2026-11-21T14:59:59Z" },
  future: { completed_at: "2026-11-21T15:02:01Z" },
  malformed: { completed_at: "Nov 21 15:00" },
  "other commit": { commit_sha: "b".repeat(40) },
  "other run": { workflow_run_id: "2345678" },
  "other attempt": { workflow_run_attempt: "1" },
  "other project": { project_ref: "another-project" },
  "live mode": { mode: "live" },
  "live mode detected": { live_mode_detected: true },
  "no provider evidence": { provider_e2e_executed: false },
})) {
  test(`rejects ${name} evidence`, () => {
    assert.throws(() => validateCurrentRunEvidence({ ...current, ...change }, context, now));
  });
}

test("rejects unavailable window or non-QA execution context", () => {
  assert.throws(() => validateCurrentRunEvidence(current, { ...context, notBefore: "" }, now));
  assert.throws(() => validateCurrentRunEvidence(current, { ...context, projectRef: "production" }, now));
});

test("checked-in September evidence cannot satisfy the current-run gate", async () => {
  const fixture = await readFile(new URL(
    "../docs/payments/MORT_STRIPE_TASK31_SANDBOX_EVIDENCE_2026-09-18.json",
    import.meta.url,
  ), "utf8");
  assert.throws(() => validateCurrentRunEvidence(JSON.parse(fixture), context, now));
});

test("manual workflow uses the QA endpoint and does not replay checked-in evidence", async () => {
  const workflow = await readFile(new URL("../.github/workflows/mort-ci.yml", import.meta.url), "utf8");
  const manualJob = workflow.split("\n  stripe-provider-e2e:\n")[1].split("\n  android-device-test-apk:\n")[0];
  assert.match(manualJob, /github\.event_name == 'workflow_dispatch'/);
  assert.match(manualJob, new RegExp(`https://${qa}\\.supabase\\.co/functions/v1/stripe-webhook\\b`));
  assert.doesNotMatch(manualJob, /stripe-assignment-webhook|docs\/payments/);
  assert.match(manualJob, /MORT_STRIPE_EVIDENCE_NOT_BEFORE/);
  assert.match(manualJob, /-ScenarioEvidencePath "\$env:MORT_STRIPE_SCENARIO_EVIDENCE_PATH"/);
  const wrapper = await readFile(new URL("./stripe-sandbox-e2e.ps1", import.meta.url), "utf8");
  assert(wrapper.indexOf("stripe-current-run-evidence.mjs") < wrapper.indexOf("stripe-pre-provider-test-gate.ps1"));
  assert.match(wrapper, /completed_at = \$scenarioEvidence\.completed_at/);
});
