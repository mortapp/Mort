import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = new URL("..", import.meta.url).pathname.replace(/^\/(.:)/, "$1");
const files = [
  join(root, "docs", "mobile", "MORT_IOS_ANDROID_PARITY_MATRIX.md"),
  join(root, "docs", "mobile", "MORT_ANDROID_CATCHUP_REPORT.md"),
  join(root, "docs", "mobile", "MORT_PLATFORM_CAPABILITY_MATRIX.json"),
];
const text = files.map((file) => readFileSync(file, "utf8")).join("\n");
const forbiddenClaims = [
  /4[,.]?500[,.]?000 (apps|applications) (reviewed|researched|inspected)/i,
  /2[,.]?500[,.]?000 (features|capabilities) (implemented|built|validated|released)/i,
  /millions of (real )?features (implemented|built|validated|released)/i,
];
for (const claim of forbiddenClaims) {
  if (claim.test(text)) throw new Error(`Inflated feature claim matched ${claim}`);
}
const matrix = JSON.parse(readFileSync(files[2], "utf8"));
if (matrix.records.length !== 34) throw new Error("Audited parity record count changed without review");
console.log("PASS: parity artifacts make no million-scale research or implementation claim.");
