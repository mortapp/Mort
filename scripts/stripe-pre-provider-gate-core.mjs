const valueLikePatterns = [
  /\\bsk_(?:test|live)_[A-Za-z0-9_-]{8,}\\b/i,
  /\\bpk_(?:test|live)_[A-Za-z0-9_-]{8,}\\b/i,
  /\\bwhsec_[A-Za-z0-9_-]{8,}\\b/i,
  /\\brk_(?:test|live)_[A-Za-z0-9_-]{8,}\\b/i,
  /\\beyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\b/,
];

export const requiredTestSecretNames = Object.freeze([
  "STRIPE_TEST_SECRET_KEY",
  "STRIPE_TEST_PUBLISHABLE_KEY",
  "STRIPE_TEST_WEBHOOK_SECRET",
]);

export const forbiddenLiveSecretNames = Object.freeze([
  "STRIPE_LIVE_SECRET_KEY",
  "STRIPE_LIVE_PUBLISHABLE_KEY",
  "STRIPE_LIVE_WEBHOOK_SECRET",
]);

export function assertNoCredentialValues(text, label = "input") {
  const source = String(text ?? "");
  for (const pattern of valueLikePatterns) {
    if (pattern.test(source)) {
      throw new Error(`${label}_contains_credential_like_value`);
    }
  }
  return source;
}

export function extractAllowlistedSecretNames(text) {
  const safe = assertNoCredentialValues(text, "secret_listing");
  const names = new Set();
  for (const name of [...requiredTestSecretNames, ...forbiddenLiveSecretNames, "MORT_STRIPE_OPERATIONS_SECRET", "MORT_STRIPE_ALLOWED_REDIRECT_ORIGINS"]) {
    if (new RegExp(`(^|[^A-Z0-9_])${name}([^A-Z0-9_]|$)`).test(safe)) names.add(name);
  }
  return names;
}

function normalizeBoolean(value) {
  if (value === true || value === false) return value;
  if (typeof value === "string") {
    if (/^(?:1|true|yes|present|enabled)$/i.test(value.trim())) return true;
    if (/^(?:0|false|no|missing|disabled)$/i.test(value.trim())) return false;
  }
  return false;
}

function expectedWebhookUrl(projectRef) {
  return `https://${projectRef}.supabase.co/functions/v1/stripe-webhook`;
}

export function evaluatePreProviderGate(input, now = new Date()) {
  const projectRef = String(input.projectRef ?? "").trim();
  const linkedProjectRef = String(input.linkedProjectRef ?? "").trim();
  const runtimeMode = String(input.runtimeMode ?? "").trim().toLowerCase();
  const webhookEnvironment = String(input.webhookEnvironment ?? "").trim().toLowerCase();
  const webhookUrl = String(input.webhookUrl ?? "").trim();
  const secretNames = input.secretNames instanceof Set ? input.secretNames : new Set(input.secretNames ?? []);
  const functionNames = input.functionNames instanceof Set ? input.functionNames : new Set(input.functionNames ?? []);

  assertNoCredentialValues(projectRef, "project_ref");
  assertNoCredentialValues(linkedProjectRef, "linked_project_ref");
  assertNoCredentialValues(webhookUrl, "webhook_url");

  const liveNamesPresent = forbiddenLiveSecretNames.filter((name) => secretNames.has(name));
  const checks = [
    {
      id: "test_secret_key_name",
      pass: secretNames.has("STRIPE_TEST_SECRET_KEY"),
      detail: secretNames.has("STRIPE_TEST_SECRET_KEY") ? "present" : "missing",
    },
    {
      id: "test_publishable_key_name",
      pass: secretNames.has("STRIPE_TEST_PUBLISHABLE_KEY"),
      detail: secretNames.has("STRIPE_TEST_PUBLISHABLE_KEY") ? "present" : "missing",
    },
    {
      id: "test_webhook_endpoint",
      pass:
        webhookEnvironment === "test" &&
        functionNames.has("stripe-webhook") &&
        webhookUrl === expectedWebhookUrl(projectRef),
      detail:
        webhookEnvironment === "test" && functionNames.has("stripe-webhook") && webhookUrl === expectedWebhookUrl(projectRef)
          ? "configured"
          : "missing_or_mismatched",
    },
    {
      id: "test_webhook_secret_name",
      pass: secretNames.has("STRIPE_TEST_WEBHOOK_SECRET"),
      detail: secretNames.has("STRIPE_TEST_WEBHOOK_SECRET") ? "present" : "missing",
    },
    {
      id: "sandbox_project_and_mode",
      pass:
        projectRef.length > 0 &&
        linkedProjectRef === projectRef &&
        runtimeMode === "sandbox" &&
        liveNamesPresent.length === 0,
      detail:
        linkedProjectRef !== projectRef
          ? "project_mismatch"
          : runtimeMode !== "sandbox"
            ? "mode_not_sandbox"
            : liveNamesPresent.length > 0
              ? "live_secret_name_contamination"
              : "sandbox",
    },
    {
      id: "sandbox_mutation_test_eligible",
      pass: normalizeBoolean(input.mutationTestEligible),
      detail: normalizeBoolean(input.mutationTestEligible) ? "eligible" : "disabled",
    },
  ];

  const firstFailureIndex = checks.findIndex((check) => !check.pass);
  const safeChecks = checks.map((check, index) => ({
    id: check.id,
    evaluated: firstFailureIndex === -1 || index <= firstFailureIndex,
    pass: firstFailureIndex === -1 ? check.pass : index <= firstFailureIndex ? check.pass : false,
    detail: firstFailureIndex === -1 || index <= firstFailureIndex ? check.detail : "not_evaluated",
  }));

  return {
    schema_version: 1,
    gate: "mort_stripe_pre_provider_test",
    project_ref: projectRef,
    environment: "test",
    runtime_mode: runtimeMode || "unknown",
    passed: firstFailureIndex === -1,
    provider_mutation_performed: false,
    checked_at: now.toISOString(),
    checks: safeChecks,
  };
}
