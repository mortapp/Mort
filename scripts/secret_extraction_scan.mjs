import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";

const syntheticFixtureTokens = new Set([
  "sk_test_1234567890abcdef",
  "whsec_1234567890abcdef",
  "pk_live_1234567890abcdef",
  "pi_123_secret_1234567890abcdef",
]);

const providerTokenPattern = /\b(?:sk_(?:test|live)|rk_(?:test|live)|whsec_|pk_live_|sb_secret_)[A-Za-z0-9_-]{8,}\b/g;
const clientSecretPattern = /\b(?:pi|seti|src)_[A-Za-z0-9]+_secret_[A-Za-z0-9_-]{8,}\b/g;
const jwtPattern = /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g;
const privateKeyPattern = /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g;

function decodeJwtPayload(token) {
  try {
    const segment = token.split(".")[1].replaceAll("-", "+").replaceAll("_", "/");
    const padding = "=".repeat((4 - (segment.length % 4)) % 4);
    return JSON.parse(Buffer.from(segment + padding, "base64").toString("utf8"));
  } catch {
    return null;
  }
}

function isSyntheticFixture(pathname, token) {
  return pathname.replaceAll("\\", "/").startsWith("scripts/qa-stripe-") &&
    syntheticFixtureTokens.has(token);
}

export function scanText(pathname, content) {
  const findings = [];
  for (const token of content.match(providerTokenPattern) ?? []) {
    if (!isSyntheticFixture(pathname, token)) findings.push("provider_credential_pattern");
  }
  providerTokenPattern.lastIndex = 0;
  for (const token of content.match(clientSecretPattern) ?? []) {
    if (!isSyntheticFixture(pathname, token)) findings.push("stripe_client_secret_pattern");
  }
  clientSecretPattern.lastIndex = 0;
  for (const token of content.match(jwtPattern) ?? []) {
    const payload = decodeJwtPayload(token);
    if (payload?.role === "service_role") findings.push("service_role_jwt");
  }
  jwtPattern.lastIndex = 0;
  if (privateKeyPattern.test(content)) findings.push("private_key_material");
  privateKeyPattern.lastIndex = 0;
  return [...new Set(findings)];
}

function runGit(args) {
  const result = spawnSync("git", args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`git ${args.join(" ")} failed`);
  return result.stdout;
}

function textualFile(pathname) {
  try {
    const stat = statSync(pathname);
    if (!stat.isFile() || stat.size > 5 * 1024 * 1024) return false;
    const sample = readFileSync(pathname).subarray(0, Math.min(stat.size, 8192));
    return !sample.includes(0);
  } catch {
    return false;
  }
}

function generatedFiles(root) {
  const roots = ["artifacts", "build", path.join("flutter_mort", "build"), "dist"];
  const files = [];
  const walk = (absolute, relative) => {
    if (!statSync(absolute).isDirectory()) return;
    for (const entry of readdirSync(absolute, { withFileTypes: true })) {
      const childAbs = path.join(absolute, entry.name);
      const childRel = path.join(relative, entry.name);
      if (entry.isDirectory()) walk(childAbs, childRel);
      else if (textualFile(childAbs)) files.push(childRel);
    }
  };
  for (const relative of roots) {
    const absolute = path.join(root, relative);
    try {
      walk(absolute, relative);
    } catch {
      // Generated root is optional.
    }
  }
  return files;
}

function selfTest() {
  const b64 = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  const anon = `${b64({ alg: "HS256", typ: "JWT" })}.${b64({ role: "anon" })}.signature12345678`;
  const service = `${b64({ alg: "HS256", typ: "JWT" })}.${b64({ role: "service_role" })}.signature12345678`;
  assert.deepEqual(scanText(".github/workflows/x.yml", anon), []);
  assert(scanText("app/x.ts", service).includes("service_role_jwt"));
  assert.deepEqual(scanText("scripts/qa-stripe-example.mjs", "sk_test_1234567890abcdef"), []);
  assert.deepEqual(
    scanText("ios/MORTIOSV8Tests/HostedWireDTOTests.swift", "pi_12345_secret_shortlived"),
    [],
  );
  assert.deepEqual(
    scanText(
      "supabase/functions/_tests/stripe_webhook_verification_test.ts",
      'const platformSecret = "whsec_platform"; const stripe = new Stripe("sk_test_placeholder");',
    ),
    [],
  );
  assert.deepEqual(
    scanText(
      "supabase/functions/send-push/index.ts",
      'pem.replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "")',
    ),
    [],
  );
  assert(scanText("app/x.ts", "sk_test_REALLOOKINGVALUE123").includes("provider_credential_pattern"));
  assert(scanText("app/x.ts", "pk_live_REALLOOKINGVALUE123").includes("provider_credential_pattern"));
  assert(scanText("app/x.ts", "pi_123_secret_REALLOOKINGVALUE123").includes("stripe_client_secret_pattern"));
  console.log(JSON.stringify({ status: "PASS", mode: "self_test", secret_values_printed: false }));
}

if (process.argv.includes("--self-test")) {
  selfTest();
  process.exit(0);
}

const root = process.cwd();
const tracked = runGit(["ls-files", "-z"]).split("\0").filter(Boolean);
const files = new Set([...tracked, ...generatedFiles(root)]);
const findings = [];

for (const relative of files) {
  const absolute = path.join(root, relative);
  if (!textualFile(absolute)) continue;
  const content = readFileSync(absolute, "utf8");
  for (const type of scanText(relative, content)) {
    findings.push({ path: relative.replaceAll("\\", "/"), type });
  }
}

if (findings.length > 0) {
  console.error(JSON.stringify({
    status: "FAIL",
    files_scanned: files.size,
    findings,
    secret_values_printed: false,
  }));
  process.exit(1);
}

console.log(JSON.stringify({
  status: "PASS",
  files_scanned: files.size,
  findings: 0,
  secret_values_printed: false,
}));
