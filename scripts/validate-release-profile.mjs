import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const matrixPath = join(root, "config", "mort-release-profiles.json");
const matrix = JSON.parse(readFileSync(matrixPath, "utf8"));
const expectedProfiles = [
  "development",
  "automated_test",
  "reviewer_demo",
  "closed_test",
  "production_candidate",
  "production",
];
const requiredKeys = [
  "releaseStage",
  "operationalMode",
  "googleAuthEnabled",
  "publicMarketplaceEnabled",
  "marketplacePaymentsEnabled",
  "paymentProviderMode",
  "identityVerificationEnabled",
  "remotePushEnabled",
  "crashReportingEnabled",
  "chatbotAiEnabled",
  "deterministicChatbotFallbackEnabled",
  "adsEnabled",
  "iapEnabled",
  "reviewerModeEnabled",
  "productionActivationApproved",
  "supportRoute",
  "adminRoute",
  "termsVersion",
  "privacyVersion",
  "communityGuidelinesVersion",
  "safetyRulesVersion",
  "minimumSupportedAppVersion",
  "maintenanceMode",
  "debugEndpointsEnabled",
];
const secretKeyPattern =
  /(secret|password|service.?role|access.?token|refresh.?token|private.?key|webhook)/i;

function fail(message) {
  console.error(`[release-profile] ${message}`);
  process.exit(1);
}

if (matrix.schemaVersion !== 1 || typeof matrix.profiles !== "object") {
  fail("unsupported or malformed profile matrix");
}
const names = Object.keys(matrix.profiles).sort();
if (JSON.stringify(names) !== JSON.stringify([...expectedProfiles].sort())) {
  fail(`expected exactly these profiles: ${expectedProfiles.join(", ")}`);
}

for (const [name, profile] of Object.entries(matrix.profiles)) {
  const keys = Object.keys(profile);
  for (const key of requiredKeys) {
    if (!(key in profile)) fail(`${name} is missing ${key}`);
  }
  for (const key of keys) {
    if (!requiredKeys.includes(key)) fail(`${name} has unknown key ${key}`);
    if (secretKeyPattern.test(key)) fail(`${name} contains forbidden secret key ${key}`);
  }
  if (profile.deterministicChatbotFallbackEnabled !== true) {
    fail(`${name} must retain deterministic support`);
  }
  if (profile.marketplacePaymentsEnabled === false && profile.paymentProviderMode !== "disabled") {
    fail(`${name} selects a payment provider while payments are disabled`);
  }
  if (profile.publicMarketplaceEnabled && name !== "production") {
    fail(`${name} cannot enable the public marketplace`);
  }
  if (profile.productionActivationApproved && name !== "production") {
    fail(`${name} cannot contain production approval`);
  }
  if (profile.reviewerModeEnabled !== (name === "reviewer_demo")) {
    fail(`${name} has an invalid reviewer-mode boundary`);
  }
  if (["reviewer_demo", "closed_test", "production_candidate", "production"].includes(name) && profile.debugEndpointsEnabled) {
    fail(`${name} cannot compile debug endpoints`);
  }
  if (["reviewer_demo", "closed_test", "production_candidate", "production"].includes(name) && (profile.adsEnabled || profile.iapEnabled)) {
    fail(`${name} cannot enable unapproved ads or IAP`);
  }
}

const selectedIndex = process.argv.indexOf("--profile");
const selectedName = selectedIndex >= 0 ? process.argv[selectedIndex + 1] : null;
if (selectedName) {
  const selected = matrix.profiles[selectedName];
  if (!selected) fail(`unknown profile ${selectedName}`);
  process.stdout.write(JSON.stringify({ name: selectedName, ...selected }));
} else {
  console.log(`[release-profile] PASS: ${expectedProfiles.length} safe profiles validated.`);
}
