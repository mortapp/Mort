import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const branch = execFileSync("git", ["branch", "--show-current"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const commit = execFileSync("git", ["rev-parse", "HEAD"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const raw = execFileSync("git", ["status", "--porcelain=v1", "-z"], {
  cwd: root,
  encoding: "utf8",
  maxBuffer: 16 * 1024 * 1024,
});
const records = raw.split("\0").filter(Boolean);
const entries = [];
for (let index = 0; index < records.length; index += 1) {
  const record = records[index];
  const status = record.slice(0, 2);
  let path = record.slice(3);
  if (status.includes("R") || status.includes("C")) {
    const destination = records[index + 1];
    if (destination) {
      path = `${path} -> ${destination}`;
      index += 1;
    }
  }
  entries.push({ status, path: path.replaceAll("\\", "/") });
}
entries.sort((left, right) => left.path.localeCompare(right.path));

const phaseFiles = [
  ".github/workflows/mort-backup-metadata.yml",
  ".github/workflows/mort-ci.yml",
  ".github/workflows/mort-signed-closed-test.yml",
  "docs/MORT_SUPREME_ACCESSIBILITY_REVIEW.md",
  "docs/MORT_SUPREME_ANDROID_EMULATOR_REPORT.md",
  "docs/MORT_SUPREME_ARCHITECTURE.md",
  "docs/MORT_SUPREME_CHANGED_FILES.md",
  "docs/MORT_SUPREME_CONTINUATION_PROMPT.md",
  "docs/MORT_SUPREME_FINAL_READINESS_REPORT.md",
  "docs/MORT_SUPREME_PERFORMANCE_REPORT.md",
  "docs/MORT_SUPREME_PRIVACY_REVIEW.md",
  "docs/MORT_SUPREME_PRODUCTION_GATES.md",
  "docs/MORT_SUPREME_PROGRESS_LEDGER.md",
  "docs/MORT_SUPREME_RELEASE_CHECKLIST.md",
  "docs/MORT_SUPREME_SECURITY_REVIEW.md",
  "docs/MORT_SUPREME_TEST_REPORT.md",
  "docs/MORT_SUPREME_OWNER_ACTIONS.md",
  "docs/ios/MORT_APP_STORE_SUBMISSION_PACKET.md",
  "docs/ios/MORT_MAC_BUILD_AND_TEST_TASK.md",
  "docs/ios/MORT_TESTFLIGHT_RELEASE_CHECKLIST.md",
  "docs/operations/MORT_BACKUP_AND_DR_REPORT.md",
  "docs/operations/MORT_BREACH_NOTIFICATION_CHECKLIST.md",
  "docs/operations/MORT_COMPROMISED_KEY_PROCEDURE.md",
  "docs/operations/MORT_DATABASE_RESTORE_DRILL.md",
  "docs/operations/MORT_INCIDENT_RESPONSE_PLAN.md",
  "docs/operations/MORT_OUTAGE_COMMUNICATION_TEMPLATES.md",
  "docs/operations/MORT_RELEASE_ROLLBACK_RUNBOOK.md",
  "docs/qa/MORT_ANDROID_E2E_RESULTS.md",
  "docs/qa/MORT_ANDROID_EMULATOR_MATRIX.md",
  "docs/qa/MORT_PERFORMANCE_BASELINES.md",
  "flutter_mort/android/app/src/main/AndroidManifest.xml",
  "flutter_mort/integration_test/android_native_smoke_test.dart",
  "flutter_mort/ios/Runner/Info.plist",
  "flutter_mort/l10n.yaml",
  "flutter_mort/lib/app.dart",
  "flutter_mort/lib/core/utils/formatters.dart",
  "flutter_mort/lib/core/widgets/auth_startup_gate.dart",
  "flutter_mort/lib/core/widgets/mort_design_components.dart",
  "flutter_mort/lib/l10n/app_en.arb",
  "flutter_mort/lib/l10n/app_es.arb",
  "flutter_mort/lib/l10n/app_localizations.dart",
  "flutter_mort/lib/l10n/app_localizations_en.dart",
  "flutter_mort/lib/l10n/app_localizations_es.dart",
  "flutter_mort/lib/l10n/mort_l10n.dart",
  "flutter_mort/pubspec.lock",
  "flutter_mort/pubspec.yaml",
  "flutter_mort/test/accessibility_localization_reliability_test.dart",
  "package.json",
  "pnpm-lock.yaml",
  "scripts/build-public-legal-site.mjs",
  "scripts/generate-release-sbom.mjs",
  "scripts/package-supreme-release.ps1",
  "scripts/qa-android-16kb-alignment.ps1",
  "scripts/qa-android-api36-launch.ps1",
  "scripts/qa-android-permission-minimization.mjs",
  "scripts/qa-release-network-security.mjs",
  "scripts/run-android-native-integration.ps1",
  "scripts/validate-public-legal-site.mjs",
  "scripts/verify-play-aab.ps1",
  "scripts/write-supreme-changed-files.mjs",
  "web/public/_headers",
  "web/public/account-deletion/index.html",
  "web/public/assets/account-deletion.js",
  "web/public/assets/supabase.js",
  "web/public/release-status.json",
];

const lines = [
  "# MORT Supreme Changed Files",
  "",
  `Branch: \`${branch}\`  `,
  `Baseline commit: \`${commit}\`  `,
  `Dirty paths at snapshot: ${entries.length}`,
  "",
  "The repository already contained a large inherited dirty working tree. No",
  "pre-existing work was reverted. The first list is the exact Phase 14-16 set",
  "created or intentionally edited in this continuation. The second list is the",
  "complete Git working-tree inventory and therefore also includes inherited",
  "changes from earlier MORT phases.",
  "",
  "## Phase 14-16 Files",
  "",
  ...phaseFiles.sort().map((path) => `- \`${path}\``),
  "",
  "## Complete Working-Tree Inventory",
  "",
  ...entries.map(({ status, path }) => `- \`${status}\` \`${path}\``),
  "",
];

writeFileSync(
  join(root, "docs", "MORT_SUPREME_CHANGED_FILES.md"),
  lines.join("\n"),
  "utf8",
);
console.log(
  `[supreme-changed-files] Wrote ${phaseFiles.length} phase paths and ${entries.length} dirty paths.`,
);
