import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptsDir = dirname(fileURLToPath(import.meta.url));
const result = spawnSync(
  process.execPath,
  [join(scriptsDir, "qa-complete-multi-user-isolation.mjs")],
  { stdio: "inherit", env: process.env },
);

if (result.error) {
  console.error(`[qa-flutter-data-isolation] FAIL: ${result.error.message}`);
  process.exit(1);
}
if (result.status !== 0) process.exit(result.status ?? 1);
console.log("[qa-flutter-data-isolation] PASS: hosted data contracts used by Flutter passed isolated multi-user QA.");
