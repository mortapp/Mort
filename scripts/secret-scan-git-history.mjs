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
  "GITHUB_TOKEN",
  "GITHUB_PAT",
  "AWS_ACCESS_KEY_ID",
  "AWS_SECRET_ACCESS_KEY",
  "AWS_SESSION_TOKEN",
  "SLACK_BOT_TOKEN",
  "GOOGLE_API_KEY",
  "SUPABASE_ACCESS_TOKEN",
];

const syntheticFixtureTokens = new Set([
  "sk_test_1234567890abcdef",
  "whsec_1234567890abcdef",
  "pk_live_1234567890abcdef",
  "pi_123_secret_1234567890abcdef",
  "pi_12345_secret_shortlived",
  "whsec_platform",
  "whsec_connect",
  "sk_test_placeholder",
  "sk_test_REALLOOKINGVALUE123",
  "whsec_REALLOOKINGVALUE123",
  "pk_live_REALLOOKINGVALUE123",
  "pi_123_secret_REALLOOKINGVALUE123",
  "sb_secret_" + "test-only",
]);
const providerCredentialPattern = /\b(?:sk_(?:live|test)|rk_(?:live|test)|whsec_|pk_live_|sb_secret_)[A-Za-z0-9_-]{8,}\b/g;
const clientSecretPattern = /\b(?:pi|seti|src)_[A-Za-z0-9]+_secret_[A-Za-z0-9_-]{8,}\b/g;
const jwtPattern = /eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g;
const privateKeyBlockPattern =
  /-----BEGIN ((?:RSA |EC |OPENSSH )?)PRIVATE KEY-----([\s\S]*?)-----END \1PRIVATE KEY-----/g;
const providerObjectIdPattern = /\b(?:pi|ch|tr|re|dp|po|acct|evt|cus)_[A-Za-z0-9]{6,}\b/g;
const additionalCredentialPatterns = [
  ["github_token_pattern", /\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b/g],
  ["aws_access_key_pattern", /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/g],
  ["slack_token_pattern", /\bxox[baprs]-[A-Za-z0-9-]{10,}\b/g],
  ["openai_api_key_pattern", /\bsk-proj-[A-Za-z0-9_-]{20,}\b/g],
  ["anthropic_api_key_pattern", /\bsk-ant-[A-Za-z0-9_-]{20,}\b/g],
  ["google_api_key_pattern", /\bAIza[0-9A-Za-z_-]{35}\b/g],
  ["supabase_access_token_pattern", /\bsbp_[A-Za-z0-9]{30,}\b/g],
];
const providerObjectTypePattern =
  /"object"\s*:\s*"(?:payment_intent|charge|transfer|refund|dispute|payout|account|customer|event)"/i;
const providerLivemodePattern = /"livemode"\s*:\s*(?:true|false)/i;

function isSyntheticFixture(path, token) {
  const normalized = path.replaceAll("\\", "/");
  const allowedFixturePath =
    normalized.startsWith("scripts/qa-stripe-") ||
    normalized === "scripts/qa-guardian-application-reader-api.test.mjs" ||
    normalized === "scripts/secret_extraction_scan.mjs" ||
    normalized === "scripts/secret-scan-git-history.mjs" ||
    normalized === "supabase/functions/_tests/stripe_webhook_verification_test.ts" ||
    normalized === "ios/MORTIOSV8Tests/HostedWireDTOTests.swift";
  return allowedFixturePath && syntheticFixtureTokens.has(token);
}

function allowsSyntheticProviderPayload(pathname) {
  const normalized = pathname.replaceAll("\\", "/");
  return normalized.startsWith("scripts/qa-stripe-") ||
    normalized === "scripts/secret_extraction_scan.mjs" ||
    normalized === "scripts/secret-scan-git-history.mjs" ||
    normalized.startsWith("supabase/functions/_tests/stripe_") ||
    normalized === "ios/MORTIOSV8Tests/HostedWireDTOTests.swift";
}

function containsCopiedProviderPayload(pathname, content) {
  providerObjectIdPattern.lastIndex = 0;
  const hasProviderId = providerObjectIdPattern.test(content);
  providerObjectIdPattern.lastIndex = 0;
  return !allowsSyntheticProviderPayload(pathname) &&
    hasProviderId &&
    providerObjectTypePattern.test(content) &&
    providerLivemodePattern.test(content);
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
  for (const [type, pattern] of additionalCredentialPatterns) {
    pattern.lastIndex = 0;
    if (pattern.test(content)) types.add(type);
    pattern.lastIndex = 0;
  }
  if (containsPrivateKeyMaterial(content)) types.add("private_key_pattern");
  for (const token of content.match(jwtPattern) ?? []) {
    if (decodeJwtPayload(token)?.role === "service_role") types.add("service_role_jwt");
  }
  jwtPattern.lastIndex = 0;
  if (containsCopiedProviderPayload(path, content)) types.add("copied_provider_payload");
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
  assert(classifyHistoricalBlob("app/x.ts", `github_pat_${"A".repeat(40)}`).includes("github_token_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", `ghp_${"A".repeat(40)}`).includes("github_token_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", `AKIA${"A".repeat(16)}`).includes("aws_access_key_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", `xoxb-${"A".repeat(30)}`).includes("slack_token_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", `sk-proj-${"A".repeat(30)}`).includes("openai_api_key_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", `sk-ant-${"A".repeat(30)}`).includes("anthropic_api_key_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", `AIza${"A".repeat(35)}`).includes("google_api_key_pattern"));
  assert(classifyHistoricalBlob("app/x.ts", `sbp_${"A".repeat(40)}`).includes("supabase_access_token_pattern"));
  assert(
    classifyHistoricalBlob(
      "artifacts/stripe/provider-dump.json",
      '{"id":"pi_SYNTHETICPAYLOAD123","object":"payment_intent","livemode":false,"amount":3240}',
    ).includes("copied_provider_payload"),
  );
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
const candidatePattern = [
  "eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}",
  "sk_(test|live)_[A-Za-z0-9_-]{8,}",
  "rk_(test|live)_[A-Za-z0-9_-]{8,}",
  "whsec_[A-Za-z0-9_-]{8,}",
  "pk_live_[A-Za-z0-9_-]{8,}",
  "sb_secret_[A-Za-z0-9_-]{8,}",
  "(pi|seti|src)_[A-Za-z0-9]+_secret_[A-Za-z0-9_-]{8,}",
  "(pi|ch|tr|re|dp|po|acct|evt|cus)_[A-Za-z0-9]{6,}",
  "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----",
  "github_pat_[A-Za-z0-9_]{20,}",
  "gh[pousr]_[A-Za-z0-9]{20,}",
  "(AKIA|ASIA)[A-Z0-9]{16}",
  "xox[baprs]-[A-Za-z0-9-]{10,}",
  "sk-proj-[A-Za-z0-9_-]{20,}",
  "sk-ant-[A-Za-z0-9_-]{20,}",
  "AIza[0-9A-Za-z_-]{35}",
  "sbp_[A-Za-z0-9]{30,}",
].join("|");
const candidateRegex = new RegExp(candidatePattern);

// Enumerate every (blob, path) pair ever introduced in history with a single
// `git log --raw` pass, then read each unique blob once. Grepping the full
// tree once per commit is quadratic in history size and exceeds the CI job
// time budget on this repository. `--raw` lists every (object, path) change,
// so the union of its entries covers every path a blob ever lived at.
const rawLogResult = runGit([
  "-c", "core.quotepath=false",
  "log", "--all", "--raw", "--no-renames", "--no-abbrev", "-m", "--format=%H",
]);
if (rawLogResult.status !== 0) throw new Error("Could not enumerate Git history contents.");
let currentCommit = "";
const pairIntroducer = new Map();
for (const line of rawLogResult.stdout.split(/\r?\n/)) {
  if (line.startsWith(":")) {
    const tabIndex = line.indexOf("\t");
    if (tabIndex === -1 || !currentCommit) continue;
    const filePath = line.slice(tabIndex + 1);
    const fields = line.slice(1, tabIndex).split(" ");
    if (fields.length < 4) continue;
    for (const sha of [fields[2], fields[3]]) {
      if (!/^[0-9a-f]{40}$/.test(sha)) continue;
      const key = `${sha}\n${filePath}`;
      if (!pairIntroducer.has(key)) pairIntroducer.set(key, currentCommit);
    }
  } else if (/^[0-9a-f]{40}$/.test(line)) {
    currentCommit = line;
  }
}

const objectType = new Map();
const objectSize = new Map();
const objectShas = [...new Set([...pairIntroducer.keys()].map((key) => key.slice(0, 40)))];
if (objectShas.length > 0) {
  const batchCheck = runGit(["cat-file", "--batch-check"], {
    input: `${objectShas.join("\n")}\n`,
  });
  if (batchCheck.status !== 0) throw new Error("Could not classify Git history objects.");
  for (const line of batchCheck.stdout.split(/\r?\n/)) {
    const [sha, type, size] = line.split(" ");
    if (sha && type) {
      objectType.set(sha, type);
      objectSize.set(sha, Number(size));
    }
  }
}

const pairsBySha = new Map();
for (const [key, introducer] of pairIntroducer) {
  const sha = key.slice(0, 40);
  if (objectType.get(sha) !== "blob") continue;
  const filePath = key.slice(41);
  if (!pairsBySha.has(sha)) pairsBySha.set(sha, []);
  pairsBySha.get(sha).push({ sha, filePath, introducer });
}

function readBlobChunk(shaList) {
  const batch = spawnSync("git", ["cat-file", "--batch"], {
    cwd: process.cwd(),
    input: `${shaList.join("\n")}\n`,
    maxBuffer: 128 * 1024 * 1024,
  });
  if (batch.error || batch.status !== 0) throw new Error("Could not read Git blob contents.");
  const contents = new Map();
  const output = batch.stdout;
  let offset = 0;
  while (offset < output.length) {
    const headerEnd = output.indexOf(0x0a, offset);
    if (headerEnd === -1) break;
    const [sha, , sizeText] = output.slice(offset, headerEnd).toString("utf8").split(" ");
    const size = Number(sizeText);
    if (!sha || !Number.isFinite(size)) throw new Error("Could not parse Git blob batch output.");
    const contentStart = headerEnd + 1;
    contents.set(sha, output.slice(contentStart, contentStart + size));
    offset = contentStart + size + 1;
  }
  return contents;
}

let candidateBlobsInspected = 0;
function scanBlobChunk(shaList) {
  for (const [sha, content] of readBlobChunk(shaList)) {
    if (content.subarray(0, 8000).includes(0)) continue; // binary blob, same skip as `git grep -I`
    const text = content.toString("utf8");
    const pairs = pairsBySha.get(sha) ?? [];
    if (exactSecrets.length > 0) {
      for (const secret of exactSecrets) {
        if (!text.includes(secret)) continue;
        for (const pair of pairs) {
          findings.add(`${pair.introducer}:${pair.filePath}:exact_environment_value`);
        }
      }
    }
    if (!candidateRegex.test(text)) continue;
    candidateBlobsInspected += 1;
    for (const pair of pairs) {
      for (const type of classifyHistoricalBlob(pair.filePath, text)) {
        findings.add(`${pair.introducer}:${pair.filePath}:${type}`);
      }
    }
  }
}

const chunkByteLimit = 48 * 1024 * 1024;
let chunk = [];
let chunkBytes = 0;
for (const sha of pairsBySha.keys()) {
  const size = objectSize.get(sha) ?? 0;
  if (chunk.length > 0 && chunkBytes + size > chunkByteLimit) {
    scanBlobChunk(chunk);
    chunk = [];
    chunkBytes = 0;
  }
  chunk.push(sha);
  chunkBytes += size;
}
if (chunk.length > 0) scanBlobChunk(chunk);

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
  candidate_blobs_inspected: candidateBlobsInspected,
  findings: 0,
  secret_values_printed: false,
}));
