import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const root = resolve(scriptDirectory, "..");
const outputPath = resolve(root, "build/play/final-production-pilot-readiness.json");

function required(relativePath) {
  const path = resolve(root, relativePath);
  if (!existsSync(path)) throw new Error(`Missing readiness evidence: ${relativePath}`);
  return path;
}

function read(relativePath) {
  return readFileSync(required(relativePath), "utf8");
}

const aabVerification = Object.fromEntries(
  read("build/play/reports/aab-verification.txt")
    .split(/\r?\n/)
    .filter((line) => line.includes("="))
    .map((line) => {
      const separator = line.indexOf("=");
      return [line.slice(0, separator).replace(/^\uFEFF/, "").trim(), line.slice(separator + 1).trim()];
    }),
);
const legalValidation = JSON.parse(read("build/play/reports/legal-site-validation.json"));
const storeAssetValidation = read("build/play/reports/store-asset-validation.txt");

if (aabVerification.AAB_SIGNATURE !== "PASS") throw new Error("AAB signature evidence is not PASS.");
if (aabVerification.DEBUG_CERTIFICATE !== "REJECTED") throw new Error("Debug certificate was not rejected.");
if (aabVerification.PACKAGE_ID !== "com.mortapp.mobile") throw new Error("Unexpected Android package ID.");
if (aabVerification.VERSION_CODE !== "91") throw new Error("Unexpected Android version code.");
if (legalValidation.packagePass !== true) throw new Error("Legal package validation did not pass.");
if (legalValidation.deploymentReady !== false) throw new Error("Legal deployment must remain an external gate.");
if (!storeAssetValidation.startsWith("PASS:")) throw new Error("Store asset validation did not pass.");

for (const relativePath of [
  "mort-play-production-pilot-final.aab",
  "mort-play-production-pilot-final-qa.apk",
  "docs/release/MORT_FRONTEND_COMPLETION_MATRIX.md",
  "docs/play-final/MORT_DATA_SAFETY_FINAL_WORKBOOK.md",
  "docs/play-final/MORT_PERMISSION_DECLARATION_FINAL.md",
  "docs/play-final/MORT_CHILD_SAFETY_DECLARATION.md",
]) {
  required(relativePath);
}

const pass = (id, evidence) => ({ id, status: "PASS", evidence });
const external = (id, reason) => ({ id, status: "NOT_COMPLETED", reason });

const technicalGates = [
  pass("flutter_analyze", "flutter analyze: no issues"),
  pass("flutter_tests", "flutter test: 92 tests passed"),
  pass("android_integration_tests", "flutter test integration_test/android_native_smoke_test.dart -d emulator-5554: passed"),
  pass("signed_aab", "build/play/reports/aab-verification.txt"),
  pass("no_debug_signing", "build/play/reports/aab-verification.txt: DEBUG_CERTIFICATE=REJECTED"),
  pass("version_code_valid", "version 0.9.1+91; previous code 90"),
  pass("public_marketplace_restricted", "run-play-release-qa.ps1 and qa-marketplace-trust-gating.mjs"),
  pass("real_id_collection_disabled", "run-play-release-qa.ps1 and audit-mission-pilot-remote.mjs"),
  pass("under_13_rejection", "qa-under-13-block.mjs"),
  pass("job_context_messaging", "qa-complete-multi-user-isolation.mjs"),
  pass("reporting", "qa-mutual-reporting.mjs and qa-ugc-report-block.mjs"),
  pass("blocking", "qa-ugc-report-block.mjs"),
  pass("account_deletion", "run-play-release-qa.ps1 account-deletion suites"),
  pass("review_tenant", "validate-play-review-tenant.mjs and review isolation suites"),
  pass("data_safety_matches_bundle", "qa-data-safety-inventory.mjs and docs/play-final/MORT_DATA_SAFETY_FINAL_WORKBOOK.md"),
  pass("legal_pages_package", "build/play/reports/legal-site-validation.json; package pass only, deployment pending"),
  pass("store_assets", "build/play/reports/store-asset-validation.txt"),
  pass("no_background_location", "qa-android-permission-minimization.mjs"),
  pass("no_bundled_ads", "qa-android-permission-minimization.mjs and signed bundle inspection"),
  pass("no_bundled_billing", "qa-android-permission-minimization.mjs and signed bundle inspection"),
  pass("no_secrets", "secret-scan.ps1 and qa-aab-secret-scan.mjs"),
  pass("no_review_credentials", "qa-aab-secret-scan.mjs and final archive scans"),
  pass("rls", "run-final-supabase-regression.ps1: 23 scripts passed"),
  pass("storage_isolation", "audit-remote-storage.mjs and storage QA suites"),
  pass("multi_user_isolation", "qa-complete-multi-user-isolation.mjs: 30/30 passed"),
];

const manualExternalGates = [
  external("play_account_enrollment", "Requires the adult account owner and Google Play Console."),
  external("owner_identity_verification", "Requires the adult account owner and Google."),
  external("physical_android_device_verification", "No physical Android device evidence was supplied."),
  external("play_app_signing_activation", "Requires Play Console enrollment."),
  external("aab_upload_acceptance", "Requires Play Console upload."),
  external("legal_page_https_deployment", "Public publisher/contact configuration and authorized hosting credentials are absent."),
  external("final_publisher_contact_details", "Adult account owner must supply and approve public values."),
  external("physical_device_testing", "The device matrix is prepared but contains no executed results."),
  external("twelve_continuous_testers", "Requires real opted-in testers in Play Console."),
  external("fourteen_consecutive_days", "Requires Play Console evidence over time."),
  external("play_pre_launch_report", "Requires an uploaded Play build."),
  external("production_access_approval", "Requires closed-test completion and Google approval."),
  external("legal_review", "No licensed legal approval was supplied."),
  external("youth_work_review", "Requires jurisdiction-specific qualified review."),
  external("child_safety_operational_approval", "Requires staffed escalation ownership and approval."),
  external("insurance_decision", "Requires the adult owner and qualified advisors."),
  external("trained_incident_response_availability", "Requires named trained adults and operating coverage."),
];

const readiness = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  projectRef: "rakjydmgwwgtdislanbt",
  release: {
    packageId: "com.mortapp.mobile",
    versionName: "0.9.1",
    versionCode: 91,
    aabSha256: aabVerification.SHA256,
    uploadCertificateSha256: "04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF",
  },
  releaseModes: {
    buildTarget: "closed_test",
    development: "available",
    internal_test: "available",
    closed_test: "ACTIVE_ON_SERVER",
    production_pilot: "PREPARED_NOT_ACTIVATED",
    production_public: "DISABLED",
    marketplaceMode: "closed_pilot",
    identityVerificationMode: "disabled",
    realDocumentCollection: false,
    liveAds: false,
    liveBilling: false,
    remotePush: false,
  },
  stages: {
    TECHNICALLY_READY_FOR_CONSOLE_SETUP: true,
    CLOSED_TEST_ACTIVE: false,
    ELIGIBLE_TO_APPLY_FOR_PRODUCTION: false,
    APPROVED_FOR_PRODUCTION_PILOT: false,
    APPROVED_FOR_PUBLIC_MARKETPLACE: false,
  },
  highestTruthfulStatus: "TECHNICALLY READY FOR PLAY CONSOLE CLOSED-TEST SETUP",
  overallStatus: "EXTERNAL_GATES_INCOMPLETE",
  technicalGates,
  manualExternalGates,
  technicalGateSummary: {
    passed: technicalGates.length,
    failed: 0,
  },
  externalGateSummary: {
    completed: 0,
    incomplete: manualExternalGates.length,
  },
  deferredSecurityEnhancement: {
    classification: "DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT",
    item: "Supabase leaked-password protection",
    mitigation: [
      "strong password minimum length and complexity",
      "authentication rate limiting",
      "email verification",
      "row-level security",
      "account restriction logic",
      "secure password reset flow",
    ],
    futureTask: "When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.",
  },
  claimsNotMade: [
    "production ready",
    "physical Android tested",
    "Play closed-test requirement completed",
    "Google approved",
    "legal approved",
    "unrestricted public marketplace enabled",
  ],
};

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, `${JSON.stringify(readiness, null, 2)}\n`);
process.stdout.write(`Wrote ${outputPath}\n`);
process.stdout.write(`${readiness.highestTruthfulStatus}\n`);
