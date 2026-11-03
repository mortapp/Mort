import { readFileSync } from "node:fs";
import { relative } from "node:path";
import { expectedFlutterSdkKey, listFiles, repoRoot } from "./revenuecat-common.mjs";

function fail(message) {
  console.error(`[qa-revenuecat-config] FAIL: ${message}`);
  process.exit(1);
}

function pass(message) {
  console.log(`[qa-revenuecat-config] PASS: ${message}`);
}

const excludedFragments = [
  "\\node_modules\\",
  "\\.expo\\",
  "\\.dart_tool\\",
  "\\build\\",
  "\\dist\\",
  "\\backups\\",
  "\\outputs\\",
  "\\.git\\",
  "\\.worktrees\\",
  "\\supabase\\.temp\\",
];
const files = listFiles(repoRoot, excludedFragments).filter((file) => {
  if (/\.(png|jpe?g|gif|webp|heic|zip|jar|wasm)$/i.test(file)) return false;
  if (/\.env($|\.|local$)/i.test(file)) return false;
  return true;
});

const forbiddenAssignmentPatterns = [
  /REVENUECAT_V2_SECRET_API_KEY\s*=/i,
  /REVENUECAT_V1_SECRET_API_KEY\s*=/i,
  /REVENUECAT_WEBHOOK_AUTH_HEADER\s*=/i,
  /SUPABASE_SERVICE_ROLE_KEY\s*=/i,
  /SUPABASE_ACCESS_TOKEN\s*=/i,
  /SUPABASE_DB_PASSWORD\s*=/i,
  /SEND_PUSH_INVOKE_SECRET\s*=/i,
];

for (const file of files) {
  const text = readFileSync(file, "utf8").replace(
    /\$env:([A-Z][A-Z0-9_]*)\s*=\s*\[Environment\]::GetEnvironmentVariable\(\s*'\1'\s*,\s*'User'\s*\)/gi,
    "",
  ).replace(/\$env:[A-Z][A-Z0-9_]*\s*=\s*\$null/gi, "");
  for (const pattern of forbiddenAssignmentPatterns) {
    if (pattern.test(text)) {
      fail(`Forbidden secret assignment-like text in ${relative(repoRoot, file)}.`);
    }
  }
}
pass("No server secret assignments found in source/docs/scripts.");

const flutterConfig = readFileSync(`${repoRoot}\\flutter_mort\\lib\\core\\config\\app_config.dart`, "utf8");
const revenueCatService = readFileSync(`${repoRoot}\\flutter_mort\\lib\\features\\monetization\\data\\revenuecat_service.dart`, "utf8");
const flutterPubspec = readFileSync(`${repoRoot}\\flutter_mort\\pubspec.yaml`, "utf8");
if (!flutterConfig.includes("static const nativeBillingCompiledIn = false")) {
  fail("Native billing compile boundary is not disabled.");
}
if (!/IAP_ENABLED[\s\S]{0,100}defaultValue: false/.test(flutterConfig)) {
  fail("IAP does not default disabled.");
}
if (!revenueCatService.includes("Purchase facade for builds where native billing is deliberately not linked") ||
    !revenueCatService.includes("Optional purchases are not available right now.")) {
  fail("RevenueCat facade does not fail closed in this release.");
}
if (/^\s*(?:purchases_flutter|purchases_ui_flutter)\s*:/m.test(flutterPubspec)) {
  fail("Native RevenueCat packages are linked in this release.");
}
pass("Native billing is unlinked, defaults disabled, and the RevenueCat facade fails closed.");

const publicKeyHits = [];
for (const file of files) {
  const text = readFileSync(file, "utf8");
  if (text.includes(expectedFlutterSdkKey)) {
    publicKeyHits.push(relative(repoRoot, file).replace(/\\/g, "/"));
  }
}

const allowedPublicKeyHits = new Set([
  "docs/FLUTTER_REVENUECAT_SETUP.md",
  "docs/MONETIZATION_PRICING_PLAN.md",
]);
const unexpectedPublicKeyHits = publicKeyHits.filter((hit) => !allowedPublicKeyHits.has(hit));
if (unexpectedPublicKeyHits.length > 0) {
  fail(`RevenueCat public/test SDK key appears outside intended docs: ${unexpectedPublicKeyHits.join(", ")}`);
}
pass(`RevenueCat public/test SDK key appears only in intended docs (${publicKeyHits.length} hit file(s)).`);

console.log("[qa-revenuecat-config] RevenueCat config QA passed.");
