import { spawnSync } from "node:child_process";

const secretNames = [
  "SUPABASE_SERVICE_ROLE_KEY",
  "SUPABASE_ACCESS_TOKEN",
  "SUPABASE_DB_PASSWORD",
  "STRIPE_TEST_SECRET_KEY",
  "STRIPE_LIVE_SECRET_KEY",
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
  "s(k|b)_?(live|test|secret|restricted|publishable|p)_[A-Za-z0-9_-]{12,}",
  "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----",
].join("|");

for (const commit of commits) {
  if (exactSecrets.length > 0) {
    const exact = runGit(["grep", "-I", "-l", "-F", "-f", "-", commit], {
      input: `${exactSecrets.join("\n")}\n`,
    });
    if (![0, 1].includes(exact.status)) throw new Error("Git exact-value history scan failed.");
    for (const path of exact.stdout.split(/\r?\n/).filter(Boolean)) {
      findings.add(`${path}:exact_environment_value`);
    }
  }

  const candidates = runGit(["grep", "-I", "-l", "-E", candidatePattern, commit]);
  if (![0, 1].includes(candidates.status)) throw new Error("Git token-pattern history scan failed.");
  for (const path of candidates.stdout.split(/\r?\n/).filter(Boolean)) {
    candidateFiles.add(path);
  }
}

const jwtPattern = /eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/g;
const providerSecretPattern = /\b(?:sk_(?:live|test|restricted)|rk_(?:live|test)|sb_secret|sbp)_[A-Za-z0-9_-]{12,}\b/g;
const privateKeyPattern = /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g;

for (const reference of candidateFiles) {
  const separator = reference.indexOf(":");
  const commit = reference.slice(0, separator);
  const path = reference.slice(separator + 1);
  const blob = runGit(["show", `${commit}:${path}`]);
  if (blob.status !== 0) throw new Error("Could not inspect a candidate Git blob.");
  const content = blob.stdout;

  if (providerSecretPattern.test(content)) findings.add(`${reference}:provider_secret_pattern`);
  providerSecretPattern.lastIndex = 0;
  if (privateKeyPattern.test(content)) findings.add(`${reference}:private_key_pattern`);
  privateKeyPattern.lastIndex = 0;

  for (const token of content.match(jwtPattern) ?? []) {
    try {
      const payloadSegment = token.split(".")[1].replaceAll("-", "+").replaceAll("_", "/");
      const payload = JSON.parse(Buffer.from(payloadSegment, "base64").toString("utf8"));
      if (payload?.role === "service_role") {
        findings.add(`${reference}:service_role_jwt`);
      }
    } catch {
      // A JWT-shaped string that cannot be decoded is not classified as a credential.
    }
  }
}

const trackedEnvironmentFiles = runGit(["ls-files", ".env", ".env.*"])
  .stdout.split(/\r?\n/)
  .filter((path) => path && !/^\.env\.(example|sample|template)$/.test(path));
for (const path of trackedEnvironmentFiles) findings.add(`tracked:${path}:environment_file`);

if (findings.size > 0) {
  console.error(
    JSON.stringify({
      status: "FAIL",
      commits_scanned: commits.length,
      configured_secret_values_scanned: exactSecrets.length,
      findings: [...findings].sort(),
      secret_values_printed: false,
    }),
  );
  process.exit(1);
}

console.log(
  JSON.stringify({
    status: "PASS",
    commits_scanned: commits.length,
    configured_secret_values_scanned: exactSecrets.length,
    candidate_blobs_inspected: candidateFiles.size,
    findings: 0,
    secret_values_printed: false,
  }),
);
