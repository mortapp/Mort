import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  ALLOWED_ROLES,
  ALLOWED_STATUSES,
  CATEGORY_QUOTAS,
  IMPLEMENTED_STATUSES,
  REQUIRED_FIELDS,
  REJECTED_CANDIDATES,
  countBy,
  evidenceCheckPasses,
  normalizeFeatureTitle,
} from "./feature-registry-core.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const registryPath = join(root, "docs", "MORT_1891_FEATURE_REGISTRY.json");
const reportPath = join(root, "docs", "MORT_FEATURE_VALIDATION_REPORT.md");
const records = JSON.parse(readFileSync(registryPath, "utf8"));
const errors = [];
const warnings = [];

function fail(message) {
  errors.push(message);
}

function isEmpty(value) {
  return value === undefined || value === null || (typeof value === "string" && value.trim() === "") || (Array.isArray(value) && value.length === 0);
}

function duplicateValues(field, normalizer = (value) => value) {
  const seen = new Map();
  const duplicates = [];
  for (const record of records) {
    const value = normalizer(record[field]);
    if (seen.has(value)) duplicates.push([seen.get(value), record.feature_id, value]);
    else seen.set(value, record.feature_id);
  }
  return duplicates;
}

function roleParts(value) {
  return String(value).split(",").map((part) => part.trim()).filter(Boolean);
}

function tokens(value) {
  const ignored = new Set(["and", "the", "for", "with", "this", "that", "from", "into", "user", "users", "control", "workflow", "support"]);
  return new Set(normalizeFeatureTitle(value).split(" ").filter((token) => token.length > 2 && !ignored.has(token)));
}

function jaccard(left, right) {
  const intersection = [...left].filter((token) => right.has(token)).length;
  const union = new Set([...left, ...right]).size;
  return union === 0 ? 1 : intersection / union;
}

if (!Array.isArray(records)) fail("Registry JSON must be an array.");
if (records.length !== 1891) fail("Accepted feature count is " + records.length + "; expected 1891.");

records.forEach((record, index) => {
  const expectedId = "MORT-F-" + String(index + 1).padStart(4, "0");
  if (record.feature_id !== expectedId) fail("ID at index " + index + " is " + record.feature_id + "; expected " + expectedId + ".");
  for (const field of REQUIRED_FIELDS) {
    if (isEmpty(record[field])) fail(record.feature_id + " has an empty required field: " + field + ".");
  }
  for (const field of ["real_world_problem", "user_story", "detailed_behavior", "reason_users_value_it", "reason_users_return", "reason_it_is_different"]) {
    if (String(record[field] || "").trim().length < 35) fail(record.feature_id + " has an underspecified " + field + ".");
  }
  if (!ALLOWED_STATUSES.has(record.implementation_status)) fail(record.feature_id + " has invalid status " + record.implementation_status + ".");
  for (const role of [...roleParts(record.primary_user), ...roleParts(record.secondary_user)]) {
    if (!ALLOWED_ROLES.has(role)) fail(record.feature_id + " has invalid role " + role + ".");
  }
  if (!["free", "optional_paid"].includes(record.free_or_paid)) fail(record.feature_id + " has invalid free_or_paid value.");
  for (const score of ["retention_score", "safety_score", "accessibility_score", "growth_score", "revenue_score", "differentiation_score", "complexity_score", "risk_score"]) {
    if (!Number.isInteger(record[score]) || record[score] < 1 || record[score] > 5) fail(record.feature_id + " has invalid " + score + ".");
  }
  if (!Number.isInteger(record.implementation_priority)) fail(record.feature_id + " has a non-integer implementation priority.");

  const safetyMustBeFree = /report|block|safety ping|emergency guidance|safety scanner|basic guardian|basic job browsing|basic applying|accepted-job messaging|basic proof submission|account access|account deletion|privacy control|safety alert/i.test(record.title);
  if (safetyMustBeFree && record.free_or_paid !== "free") fail(record.feature_id + " attempts to monetize a mandatory-free capability.");
  if (/Safety, fraud|Accessibility, inclusion|Privacy, compliance/.test(record.category) && record.free_or_paid !== "free") fail(record.feature_id + " places a safety, accessibility, or privacy capability behind payment.");

  if (IMPLEMENTED_STATUSES.has(record.implementation_status)) {
    if (!Array.isArray(record.evidence_checks) || record.evidence_checks.length === 0) fail(record.feature_id + " claims implementation without evidence checks.");
    if (/^none\b/i.test(record.verification_evidence)) fail(record.feature_id + " claims implementation without verification evidence.");
    if (/not_started/i.test(record.test_status)) fail(record.feature_id + " claims implementation without test status.");
    for (const check of record.evidence_checks || []) {
      const result = evidenceCheckPasses(check);
      if (!result.passed) fail(record.feature_id + " evidence failed for " + check.path + ": " + result.reason + ".");
    }
  }
});

for (const [field, normalizer] of [["feature_id", (value) => value], ["unique_slug", (value) => value], ["title", normalizeFeatureTitle]]) {
  for (const [first, second, value] of duplicateValues(field, normalizer)) fail("Duplicate " + field + " between " + first + " and " + second + ": " + value + ".");
}

const categoryCounts = countBy(records, "category");
for (const [category, expected] of CATEGORY_QUOTAS) {
  const actual = categoryCounts.get(category) || 0;
  if (actual !== expected) fail("Category quota mismatch for " + category + ": " + actual + "/" + expected + ".");
}
for (const category of categoryCounts.keys()) {
  if (!CATEGORY_QUOTAS.has(category)) fail("Unexpected category: " + category + ".");
}

const tokenized = records.map((record) => ({ record, value: tokens(record.title + " " + record.detailed_behavior) }));
const nearDuplicates = [];
for (let left = 0; left < tokenized.length; left += 1) {
  for (let right = left + 1; right < tokenized.length; right += 1) {
    if (tokenized[left].record.category !== tokenized[right].record.category) continue;
    const similarity = jaccard(tokenized[left].value, tokenized[right].value);
    if (similarity >= 0.96) nearDuplicates.push([tokenized[left].record.feature_id, tokenized[right].record.feature_id, similarity]);
  }
}
if (nearDuplicates.length > 0) {
  for (const [first, second, similarity] of nearDuplicates.slice(0, 20)) fail("Semantic near-duplicate " + first + "/" + second + " at " + similarity.toFixed(3) + ".");
}

const statuses = countBy(records, "implementation_status");
const implementedCount = [...statuses.entries()].filter(([status]) => IMPLEMENTED_STATUSES.has(status)).reduce((sum, [, count]) => sum + count, 0);
const report = [
  "# MORT Feature Registry Validation",
  "",
  "## Result",
  "",
  "- Status: " + (errors.length === 0 ? "PASS" : "FAIL"),
  "- Accepted records: " + records.length,
  "- Sequential IDs: " + (errors.some((error) => error.startsWith("ID at index")) ? "FAIL" : "PASS"),
  "- Category quotas: " + (errors.some((error) => error.startsWith("Category quota")) ? "FAIL" : "PASS"),
  "- Exact/normalized duplicates: " + duplicateValues("title", normalizeFeatureTitle).length,
  "- Semantic near-duplicates at 0.96 threshold: " + nearDuplicates.length,
  "- Candidate duplicates removed before acceptance: " + REJECTED_CANDIDATES.filter((item) => item.status === "duplicate_removed").length,
  "- Rejected unsafe/invalid candidates: " + REJECTED_CANDIDATES.filter((item) => item.status === "rejected").length,
  "- Evidence-backed implemented records: " + implementedCount,
  "- Roadmap-only records: " + (statuses.get("accepted_roadmap") || 0),
  "",
  "## Status Counts",
  "",
  ...[...statuses.entries()].sort().map(([status, count]) => "- `" + status + "`: " + count),
  "",
  "## Errors",
  "",
  ...(errors.length ? errors.map((error) => "- " + error) : ["- None."]),
  "",
  "## Warnings",
  "",
  ...(warnings.length ? warnings.map((warning) => "- " + warning) : ["- None."]),
  "",
].join("\n");
writeFileSync(reportPath, report);

if (errors.length > 0) {
  console.error("MORT feature registry validation failed with " + errors.length + " error(s). See " + reportPath + ".");
  process.exitCode = 1;
} else {
  console.log("MORT feature registry validation passed: 1891 accepted, all quotas exact, no accepted duplicates, and " + implementedCount + " implementation claims verified.");
}
