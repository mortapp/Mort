import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL(".", import.meta.url)), "..");
const retiredProjectRef = "rakjydmgwwgtdislanbt";
const currentProjectRef = "jxbnrkasktbhtiujkhay";
const activeFiles = [
  "scripts/audit-supabase-advisors.mjs",
  "scripts/stripe-pre-provider-runtime-status.mjs",
  "scripts/stripe-pre-provider-test-gate.ps1",
  "scripts/stripe-connect-webhook-preflight.ps1",
  "scripts/stripe-sandbox-e2e.ps1",
  "scripts/qa-stripe-pre-provider-gate.mjs",
  "docs/MORT_RELEASE_RUNBOOK.md",
  "docs/MORT_RELEASE_READINESS.md",
  "docs/MORT_GOOGLE_AUTH_EXTERNAL_SETUP.md",
  "docs/MORT_FIREBASE_PUSH_OWNER_SETUP.md",
  "docs/MORT_ACTIVE_CLIENTS.md",
  "docs/EXTERNAL_SETUP.md",
  "docs/IDENTITY_VERIFICATION_PROVIDER_ARCHITECTURE.md",
];
const workflowEntries = await readdir(resolve(root, ".github/workflows"), { withFileTypes: true });
for (const entry of workflowEntries) {
  if (entry.isFile() && /\.ya?ml$/i.test(entry.name)) {
    activeFiles.push(`.github/workflows/${entry.name}`);
  }
}
const currentTargetFiles = [
  ".github/workflows/mort-ci.yml",
  "scripts/audit-supabase-advisors.mjs",
  "scripts/stripe-pre-provider-runtime-status.mjs",
  "scripts/stripe-pre-provider-test-gate.ps1",
  "scripts/stripe-connect-webhook-preflight.ps1",
  "scripts/stripe-sandbox-e2e.ps1",
  "scripts/qa-stripe-pre-provider-gate.mjs",
  "docs/MORT_RELEASE_RUNBOOK.md",
  "docs/MORT_GOOGLE_AUTH_EXTERNAL_SETUP.md",
];

for (const relativePath of activeFiles) {
  const contents = await readFile(resolve(root, relativePath), "utf8");
  const encodedProjectRefs = [...contents.matchAll(/\beyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+\b/g)]
    .map((match) => {
      try {
        return Buffer.from(match[1], "base64url").toString("utf8");
      } catch {
        return "";
      }
    });
  assert.equal(
    contents.includes(retiredProjectRef) || encodedProjectRefs.some((claims) => claims.includes(retiredProjectRef)),
    false,
    `${relativePath} still references the deleted Supabase project`,
  );
  if (currentTargetFiles.includes(relativePath)) {
    assert.equal(
      contents.includes(currentProjectRef),
      true,
      `${relativePath} must explicitly target the current Supabase project`,
    );
  }
}

console.log(JSON.stringify({ status: "PASS", checked_files: activeFiles.length }));

