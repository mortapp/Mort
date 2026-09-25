import { readFileSync } from "node:fs";
import { relative } from "node:path";
import { listFiles, repoRoot } from "./revenuecat-common.mjs";

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
  /REVENUECAT_PLAY_WEBHOOK_AUTH_HEADER\s*=/i,
  /REVENUECAT_TEST_WEBHOOK_AUTH_HEADER\s*=/i,
  /SUPABASE_SERVICE_ROLE_KEY\s*=/i,
  /SUPABASE_ACCESS_TOKEN\s*=/i,
  /SUPABASE_DB_PASSWORD\s*=/i,
  /SEND_PUSH_INVOKE_SECRET\s*=/i,
];

for (const file of files) {
  const text = readFileSync(file, "utf8");
  for (const pattern of forbiddenAssignmentPatterns) {
    const assignment = text.match(pattern);
    const remainder = assignment == null ? "" : text.slice(
      text.lastIndexOf("\n", assignment.index) + 1,
      text.indexOf("\n", assignment.index) < 0 ? undefined : text.indexOf("\n", assignment.index),
    );
    const safeRuntimeAssignment =
      /\[Environment\]::GetEnvironmentVariable\(/.test(remainder) ||
      /=\s*\$local\['SERVICE_ROLE_KEY'\]/.test(remainder) ||
      /=\s*\$null\s*$/.test(remainder);
    if (assignment && !safeRuntimeAssignment) {
      fail(`Forbidden secret assignment-like text in ${relative(repoRoot, file)}.`);
    }
  }
}
pass("No server secret assignments found in source/docs/scripts.");

const flutterConfig = readFileSync(`${repoRoot}\\flutter_mort\\lib\\core\\config\\app_config.dart`, "utf8");
for (const variable of [
  "REVENUECAT_TEST_STORE_API_KEY",
  "REVENUECAT_ANDROID_API_KEY",
  "REVENUECAT_IOS_API_KEY",
]) {
  if (!flutterConfig.includes("'"+variable+"'")) {
    fail(`Flutter RevenueCat configuration is missing ${variable}.`);
  }
}
if (!flutterConfig.includes("RevenueCat Test Store key is forbidden in release builds")) {
  fail("Release configuration does not reject Test Store keys.");
}
pass("Flutter RevenueCat keys use Dart defines and release Test Store keys fail closed.");

const publicKeyHits = [];
for (const file of files) {
  const text = readFileSync(file, "utf8");
  if (/\btest_[A-Za-z0-9]{20,}\b/.test(text)) {
    publicKeyHits.push(relative(repoRoot, file).replace(/\\/g, "/"));
  }
}
if (publicKeyHits.length > 0) {
  fail(`RevenueCat Test Store SDK key appears in tracked source/docs: ${publicKeyHits.join(", ")}`);
}
pass("No RevenueCat Test Store SDK key is embedded in tracked source/docs.");

console.log("[qa-revenuecat-config] RevenueCat config QA passed.");
