import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  assertNoCredentialValues,
  evaluatePreProviderGate,
  extractAllowlistedSecretNames,
} from "./stripe-pre-provider-gate-core.mjs";

const projectRef = "rakjydmgwwgtdislanbt";
const webhookUrl = `https://${projectRef}.supabase.co/functions/v1/stripe-webhook`;
const fixedNow = new Date("2026-09-18T12:00:00.000Z");

function baseline(overrides = {}) {
  return {
    projectRef,
    linkedProjectRef: projectRef,
    runtimeMode: "sandbox",
    webhookEnvironment: "test",
    webhookUrl,
    functionNames: new Set(["stripe-webhook"]),
    secretNames: new Set([
      "STRIPE_TEST_SECRET_KEY",
      "STRIPE_TEST_PUBLISHABLE_KEY",
      "STRIPE_TEST_WEBHOOK_SECRET",
      "MORT_STRIPE_OPERATIONS_SECRET",
    ]),
    mutationTestEligible: true,
    ...overrides,
  };
}

function expectFailure(input, checkId) {
  const result = evaluatePreProviderGate(input, fixedNow);
  assert.equal(result.passed, false);
  assert.equal(result.provider_mutation_performed, false);
  const check = result.checks.find((entry) => entry.id === checkId);
  assert(check, `missing ${checkId}`);
  assert.equal(check.pass, false);
  return result;
}

expectFailure(
  baseline({ secretNames: new Set(["STRIPE_TEST_PUBLISHABLE_KEY", "STRIPE_TEST_WEBHOOK_SECRET"]) }),
  "test_secret_key_name",
);
expectFailure(
  baseline({ secretNames: new Set(["STRIPE_TEST_SECRET_KEY", "STRIPE_TEST_WEBHOOK_SECRET"]) }),
  "test_publishable_key_name",
);
expectFailure(baseline({ functionNames: new Set(), webhookUrl: "" }), "test_webhook_endpoint");
expectFailure(
  baseline({ secretNames: new Set(["STRIPE_TEST_SECRET_KEY", "STRIPE_TEST_PUBLISHABLE_KEY"]) }),
  "test_webhook_secret_name",
);
expectFailure(baseline({ linkedProjectRef: "wrong-project" }), "sandbox_project_and_mode");
expectFailure(baseline({ runtimeMode: "live" }), "sandbox_project_and_mode");
expectFailure(
  baseline({ secretNames: new Set([...baseline().secretNames, "STRIPE_LIVE_SECRET_KEY"]) }),
  "sandbox_project_and_mode",
);
expectFailure(baseline({ mutationTestEligible: false }), "sandbox_mutation_test_eligible");

assert.throws(
  () => assertNoCredentialValues("sk_test_1234567890abcdef"),
  /contains_credential_like_value/,
);
assert.throws(
  () => extractAllowlistedSecretNames("STRIPE_TEST_SECRET_KEY whsec_1234567890abcdef"),
  /contains_credential_like_value/,
);

const complete = evaluatePreProviderGate(baseline(), fixedNow);
assert.equal(complete.passed, true);
assert.equal(complete.provider_mutation_performed, false);
assert.equal(complete.project_ref, projectRef);
assert.deepEqual(complete.checks.map((entry) => entry.pass), [true, true, true, true, true, true]);
assert.equal(JSON.stringify(complete).includes("sk_"), false);
assert.equal(JSON.stringify(complete).includes("pk_"), false);
assert.equal(JSON.stringify(complete).includes("whsec_"), false);

const names = extractAllowlistedSecretNames(`NAME
STRIPE_TEST_SECRET_KEY
STRIPE_TEST_PUBLISHABLE_KEY
STRIPE_TEST_WEBHOOK_SECRET
`);
assert(names.has("STRIPE_TEST_SECRET_KEY"));
assert(names.has("STRIPE_TEST_PUBLISHABLE_KEY"));
assert(names.has("STRIPE_TEST_WEBHOOK_SECRET"));

const ps = await readFile(new URL("./stripe-pre-provider-test-gate.ps1", import.meta.url), "utf8");
assert(ps.includes("supabase','secrets','list"));
assert(ps.includes("supabase','functions','list"));
assert(ps.includes("stripe-pre-provider-runtime-status.mjs"));
assert(ps.includes("provider_mutation_performed = $false"));
assert(!/stripe\\s+(?:trigger|payment_intents|charges|refunds|transfers)/i.test(ps));
assert(!/api\\.stripe\\.com/i.test(ps));

console.log(JSON.stringify({ status: "PASS", cases: 17, provider_mutation_performed: false }));
