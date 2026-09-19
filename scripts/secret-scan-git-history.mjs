import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

const secretNames = [
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_ACCESS_TOKEN",
  "SUPABASE_DB_PASSWORD",
  "STRIPE_TEST_SECRET_KEY",
  "STRIPE_LIVE_SECRET_KEY",
  "STRIPE_TEST_PUBLISHABLE_KEY",
  "STRIPE_LIVE_PUBLISHABLE_KEY",
  "STRIPE_TEST_WEBHOOK_SECRET",
  "STRIPE_LIVE_WEBHOOK_SECRET",
  "MORT_STRIPE_OPERATIONS_SECRET",
  "REVENUECAT_V1_SECRET_API_KEY",
  "REVENUECAT_WEBHOOK_AUTH_HEADER",
  "REVENUECAT_WEBHOOK_SECRET",
  "SEND_PUSH_INVOKE_SECRET",
  "IDENTITY_VERIFICATION_WEBHOOK_SECRET",
  "OPENAI_API_KEY",
  "ANTHROPIC_API_KEY",
  "GEMINI_API_KEY",
  "MORT_UPLOAD_STORE_PASSWORD",
  "MORT_UPLOAD_KEY_PASSWORD",
];

const syntheticFixtureTokens = new Set([
  "sk_test_1234567890abcdef",
  "whsec_1234567890abcdef",
  "pk_live_1234567890abcdef",
  "pi_123_secret_1234567890abcdef",
]);
const providerCredentialPattern = /\b(?:sk_(?:live|test)|rk_(?:live|test)|whsec_|pk_live_|sb_secret_)[A-Za-z0-9_-]{8,}\b/g;
const clientSecretPattern = /\b(?:pi|seti|src)_[A-Za-z0-9]+_secret_[A-Za-z0-9_-]{8,}\b/g;
const jwtPattern = /eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g;
const privateKeyBlockPattern =
  /-----BEGIN ((?:RSA |EC |OPENSSH )?)PRIVATE KEY-----([\s\S]*?)-----END \1PRIVATE KEY-----/g;

function isSyntheticFixture(path, token) {
  return path.replaceAll("\\", "/").startsWith("scripts/qa-stripe-") &&
    syntheticFixtureTokens.has(token);
}

function decodeJwtPayload(token) {
  try {
    const segment = token.split(".")[1].replaceAll("-", "+").replaceAll("_", "/");
    const padding = "=".repeat((4 - (segment.length % 4)) % 4);
    return JSON.parse(Buffer.from(segment + padding, "base64").toString("utf8"));
  } catch {
    return null;
  }
}

function containsPrivateKeyMaterial(content) {
  privateKeyBlockPattern.lastIndex = 0;
  for (const match of content.matchAll(privateKeyBlockPattern)) {
    const body = match[2].replace(/\s/g, "");
    if (body.length >= 64 && /^[A-Za-z0-9+/=]+$/.test(body)) return true;
  }
  return false;
}

export function classifyHistoricalBlob(path, content) {
  const types = new Set();
  for (const token of content.match(providerCredentialPattern) ?? []) {
    if (!isSyntheticFixture(path, token)) types.add("provider_credential_pattern");
  }
  providerCredentialPattern.lastIndex = 0;
  for (const token of content.match(clientSecretPattern) ?? []) {
    if (!isSyntheticFixture(path, token)) types.add("stripe_client_secret_pattern");
  }
  clientSecretPattern.lastIndex = 0;
  if (containsPrivateKeyMaterial(content)) types.add("private_key_pattern");
  for (const token of content.match(jwtPattern) ?? []) {
    if (decodeJwtPayload(token)?.role === "service_role") types.add("service_role_jwt");
  }
  jwtPattern.lastIndex = 0;
  return [...types];
}

function selfTest() {
  const b64 = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const anon = `${b64({ alg: "HS256" })}.${b64({ role: "anon" })}.signature12345678`;
  const service = `${b64({ alg: "HS256" })}.${b64({ role: "service_role" })}.signature12345678`;
  assert.deepEqual(classifyHistoricalBlob(".github/workflows/mort-ci.yml", anon), []);
  assert(classifyHistoricalBlob("app/x.ts", service).includes("service_role_jwt"));
  assert.deepEqual(classifyHistoricalBlob("scripts/qa-stripe-example.mjs", "sk_test_1234567890abcdef"), []);
  assert.deepEqual(
    classifyHistoricalBlob("ios/MORTIOSV8Tests/HostedWireDTOTests.swift", "pi_12345_secret_shortlived"),
    [],
  );
  assert.deepEqual(
    classifyHistoricalBlob(
      "supabase/functions/_tests/stripe_webhook_verification_test.ts",
      'const platformSecret = "whsec_platform"; const stripe = new Stripe("sk_test_placeholder");',
    ),
    [],
  );
  assert.deepEqual(
    classifyHistoricalBlob(
      "supabase/functions/send-push/index.ts",
      'pem.replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "")',
    ),
    [],
  );
  assert(classifyHistoricalBlob("app/x.ts", "whsec_REALLOOKINGVALUE123").includes("provider_credential_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", "pk_live_REALLOOKINGVALUE123").includes("provider_credential_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", "pi_123_secret_REALLOOKINGVALUE123").includes("stripe_client_secret_pattern"));
  console.log(JSON.stringify({ status: "PASS", mode: "self_test", secret_values_printed: false }));
}

if (process.argv.includes("--self-test")) {
  selfTest();
  process.exit(0);
}

const runGit = (args, options = {}) => {
  const result = spawnSync("git", args, {
    cwd: process.cwd(),
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });
  if (result.error) throw result.error;
  return result;
};

const commitsResult = runGit(["rev-list", "--all"]);
if (commitsResult.status !== 0) throw new Error("Could not enumerate Git history.");
const commits = commitsResult.stdout.split(/\r?\n/).filter(Boolean);
const exactSecrets = secretNames
  .map((name) => process.env[name])
  .filter((value) => typeof value === "string" && value.length >= 8);

const findings = new Set();
const candidateFiles = new Set();
const candidatePattern = [
  "eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}",
  "sk_(test|live)_[A-Za-z0-9_-]{8,}",
  "rk_(test|live)_[A-Za-z0-9_-]{8,}",
  "whsec_[A-Za-z0-9_-]{8,}",
  "pk_live_[A-Za-z0-9_-]{8,}",
  "sb_secret_[A-Za-z0-9_-]{8,}",
  "(pi|seti|src)_[A-Za-z0-9]+_secret_[A-Za-z0-9_-]{8,}",
  "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----",
].join("|");

for (const commit of commits) {
  if (exactSecrets.length > 0) {
    const exact = runGit(["grep", "-I", "-l", "-F", "-f", "-", commit], {
      input: `${exactSecrets.join("\n")}\n`,
    });
    if (![0, 1].includes(exact.status)) throw new Error("Git exact-value history scan failed.");
    for (const reference of exact.stdout.split(/\r?\n/).filter(Boolean)) {
      findings.add(`${reference}:exact_environment_value`);
    }
  }

  const candidates = runGit(["grep", "-I", "-l", "-E", candidatePattern, commit]);
  if (![0, 1].includes(candidates.status)) throw new Error("Git token-pattern history scan failed.");
  for (const reference of candidates.stdout.split(/\r?\n/).filter(Boolean)) {
    candidateFiles.add(reference);
  }
}

for (const reference of candidateFiles) {
  const separator = reference.indexOf(":");
  const commit = reference.slice(0, separator);
  const filePath = reference.slice(separator + 1);
  const blob = runGit(["show", `${commit}:${filePath}`]);
  if (blob.status !== 0) throw new Error("Could not inspect a candidate Git blob.");
  for (const type of classifyHistoricalBlob(filePath, blob.stdout)) {
    findings.add(`${reference}:${type}`);
  }
}

const trackedEnvironmentFiles = runGit(["ls-files", ".env", ".env.*"])
  .stdout.split(/\r?\n/)
  .filter((path) => path && !/^\.env\.(example|sample|template)$/.test(path));
for (const filePath of trackedEnvironmentFiles) {
  findings.add(`tracked:${filePath}:environment_file`);
}

if (findings.size > 0) {
  console.error(JSON.stringify({
    status: "FAIL",
    commits_scanned: commits.length,
    configured_secret_values_scanned: exactSecrets.length,
    findings: [...findings].sort(),
    secret_values_printed: false,
  }));
  process.exit(1);
}

console.log(JSON.stringify({
  status: "PASS",
  commits_scanned: commits.length,
  configured_secret_values_scanned: exactSecrets.length,
  candidate_blobs_inspected: candidateFiles.size,
  findings: 0,
  secret_values_printed: false,
}));
