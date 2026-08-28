import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  IMPLEMENTED_STATUSES,
  countBy,
  evidenceCheckPasses,
  resolveEvidencePath,
  writeRegistryArtifacts,
} from "./feature-registry-core.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const registryPath = join(root, "docs", "MORT_1891_FEATURE_REGISTRY.json");
const reportPath = join(root, "docs", "MORT_FEATURE_IMPLEMENTATION_AUDIT.md");
const records = JSON.parse(readFileSync(registryPath, "utf8"));
const audited = [];
const downgraded = [];

function placeholderNearSymbol(check) {
  const source = readFileSync(resolveEvidencePath(check.path), "utf8");
  const index = source.indexOf(check.symbol);
  if (index < 0) return false;
  const nearby = source.slice(Math.max(0, index - 250), Math.min(source.length, index + check.symbol.length + 500));
  return /TODO|FIXME|HACK|placeholder implementation|not implemented|UnimplementedError|fatalError\s*\(/i.test(nearby);
}

for (const record of records) {
  if (!IMPLEMENTED_STATUSES.has(record.implementation_status)) continue;
  const failures = [];
  if (!Array.isArray(record.evidence_checks) || record.evidence_checks.length === 0) {
    failures.push("no evidence checks");
  } else {
    for (const check of record.evidence_checks) {
      const result = evidenceCheckPasses(check);
      if (!result.passed) failures.push(check.path + ": " + result.reason);
      else if (placeholderNearSymbol(check)) failures.push(check.path + ": placeholder marker near " + check.symbol);
    }
  }
  if (failures.length > 0) {
    downgraded.push({ id: record.feature_id, title: record.title, failures });
    record.implementation_status = "accepted_roadmap";
    record.verification_evidence = "Implementation claim automatically downgraded by scripts/audit-feature-implementation.mjs.";
    record.test_status = "not_started";
    record.reason_deferred = "Evidence audit failed: " + failures.join("; ");
    record.evidence_checks = [];
  } else {
    audited.push(record);
  }
}

if (downgraded.length > 0) writeRegistryArtifacts(records);
const statusCounts = countBy(records, "implementation_status");
const lines = [
  "# MORT Feature Implementation Audit",
  "",
  "## Result",
  "",
  "- Evidence-backed implementation claims audited: " + (audited.length + downgraded.length),
  "- Claims retained: " + audited.length,
  "- Claims automatically downgraded: " + downgraded.length,
  "- Roadmap-only after audit: " + (statusCounts.get("accepted_roadmap") || 0),
  "- Mac/Xcode compile claimed: no",
  "- Physical iPhone verification claimed: no",
  "",
  "Each retained claim has an existing source or migration file, the expected symbol, route/repository evidence where applicable, backend and QA evidence where applicable, and no placeholder marker near the verified symbol.",
  "",
  "## Retained Claims",
  "",
  "| Feature | Status | Evidence checks | Test status |",
  "| --- | --- | ---: | --- |",
  ...audited.map((record) => "| " + record.feature_id + " " + record.title + " | " + record.implementation_status + " | " + record.evidence_checks.length + " | " + record.test_status.replaceAll("|", "\\|") + " |"),
  "",
  "## Downgraded Claims",
  "",
  ...(downgraded.length ? downgraded.map((item) => "- `" + item.id + "` " + item.title + ": " + item.failures.join("; ")) : ["- None."]),
  "",
];
writeFileSync(reportPath, lines.join("\n"));

if (downgraded.length > 0) {
  console.error("Feature implementation audit downgraded " + downgraded.length + " unsupported claim(s). See " + reportPath + ".");
  process.exitCode = 1;
} else {
  console.log("Feature implementation audit passed: " + audited.length + " claims retained and 0 downgraded.");
}
