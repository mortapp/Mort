import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const corpusPath = join(root, "docs", "legal-research", "MORT_LEGAL_CORPUS_INDEX.json");
const reportPath = join(root, "docs", "legal-research", "MORT_LEGAL_CORPUS_VALIDATION_REPORT.md");
const corpus = JSON.parse(readFileSync(corpusPath, "utf8"));
const records = corpus.records;
const errors = [];

const requiredFields = [
  "record_id", "organization", "document_title", "official_source", "official_domain",
  "retrieval_date", "jurisdiction", "category", "applicable_role", "source_access_status",
  "access_method", "source_content_sha256", "summary", "safety_approach", "payment_approach",
  "dispute_approach", "minor_user_approach", "privacy_approach", "location_approach",
  "verification_approach", "limitation_of_liability_approach", "arbitration_status",
  "class_action_status", "indemnification_status", "lessons_applicable_to_mort",
  "clauses_inappropriate_for_mort",
];

if (!Array.isArray(records)) errors.push("records must be an array");
if (records.length !== 300) errors.push(`exact corpus count is ${records.length}; expected 300`);

const urls = new Map();
const organizationDocuments = new Map();
for (const [index, record] of records.entries()) {
  const label = record.record_id ?? `row ${index + 1}`;
  for (const field of requiredFields) {
    if (record[field] === null || record[field] === undefined || String(record[field]).trim() === "") errors.push(`${label}: missing ${field}`);
  }
  if (!/^MORT-LR-\d{4}$/.test(record.record_id ?? "")) errors.push(`${label}: invalid record_id`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(record.retrieval_date ?? "")) errors.push(`${label}: invalid retrieval date`);
  if (!/^https:\/\//.test(record.official_source ?? "")) errors.push(`${label}: official source must use HTTPS`);
  if (!/^[a-f0-9]{64}$/.test(record.source_content_sha256 ?? "")) errors.push(`${label}: invalid source hash`);
  if (!record.source_access_status?.startsWith("reviewed_")) errors.push(`${label}: inaccessible source marked as corpus research`);
  if (record.source_access_status === "reviewed_direct" && !(record.direct_http_status >= 200 && record.direct_http_status < 400)) errors.push(`${label}: direct review lacks successful HTTP evidence`);
  if (record.source_access_status.includes("tracked") && (!record.archive_version_url || !record.declaration_url)) errors.push(`${label}: tracked source lacks declaration/version provenance`);
  if (record.source_access_status === "reviewed_browser_verified") {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(record.browser_verification_date ?? "")) errors.push(`${label}: browser-verified source lacks a verification date`);
    if (!record.browser_review_evidence || record.browser_review_evidence.length < 80) errors.push(`${label}: browser-verified source lacks an evidence note`);
    if (!record.access_method.includes("normal-browser")) errors.push(`${label}: browser-verified source has an inconsistent access method`);
  } else if (record.browser_verification_date || record.browser_review_evidence) {
    errors.push(`${label}: browser evidence is present without browser-verified status`);
  }
  if (record.summary.length < 120 || record.summary.length > 700) errors.push(`${label}: summary length is outside 120-700 characters`);
  if (record.copied_source_excerpt !== null) errors.push(`${label}: copied source excerpt must remain null`);
  if (record.legal_review_required !== true) errors.push(`${label}: legal_review_required must be true`);
  if (!Array.isArray(record.clause_categories) || record.clause_categories.length === 0) errors.push(`${label}: clause categories missing`);

  const normalized = new URL(record.official_source);
  normalized.hash = "";
  normalized.hostname = normalized.hostname.toLowerCase();
  const key = normalized.toString();
  if (urls.has(key)) errors.push(`${label}: duplicate official URL also used by ${urls.get(key)}`);
  urls.set(key, label);

  const docKey = `${record.organization.toLowerCase()}::${record.document_title.toLowerCase()}`;
  if (organizationDocuments.has(docKey)) errors.push(`${label}: organization is counted repeatedly without a distinct document (${organizationDocuments.get(docKey)})`);
  organizationDocuments.set(docKey, label);

  const serialized = JSON.stringify(record).toLowerCase();
  if (/lorem ipsum|placeholder|invented document|example\.com/.test(serialized)) errors.push(`${label}: placeholder or invented-source marker detected`);
  if (/(reviewed|audited|analyzed)[^.!?]{0,80}(1[,.]?900[,.]?000|1\.9\s*million)/i.test(serialized)) errors.push(`${label}: prohibited 1.9-million review claim detected`);
  if (/"[^"\n]{220,}"/.test(record.summary)) errors.push(`${label}: possible copied long passage in summary`);
}

for (const [category, minimum] of Object.entries(corpus.category_targets ?? {})) {
  const count = records.filter((record) => record.category === category).length;
  if (count < minimum) errors.push(`${category}: ${count} records, minimum ${minimum}`);
}

const wholeCorpus = readFileSync(corpusPath, "utf8");
if (/(reviewed|audited|analyzed)[^.!?]{0,80}(1[,.]?900[,.]?000|1\.9\s*million)/i.test(wholeCorpus)) errors.push("corpus contains a prohibited 1.9-million review claim");

const status = errors.length === 0 ? "PASS" : "FAIL";
const report = `# MORT Legal Research Corpus Validation\n\n- Status: **${status}**\n- Exact records: ${records.length}\n- Distinct official URLs: ${urls.size}\n- Distinct organizations: ${new Set(records.map((record) => record.organization)).size}\n- Duplicate URLs: ${records.length - urls.size}\n- Validation errors: ${errors.length}\n\n${errors.length ? errors.map((error) => `- ${error}`).join("\n") : "All category floors, provenance, uniqueness, summary, access-evidence, no-excerpt, and prohibited-claim checks passed."}\n`;
writeFileSync(reportPath, report);

if (errors.length) {
  console.error(`[legal-corpus-validator] FAIL: ${errors.length} error(s). See ${reportPath}`);
  process.exit(1);
}
console.log(`[legal-corpus-validator] PASS: ${records.length} records, ${urls.size} unique official URLs, ${new Set(records.map((record) => record.organization)).size} organizations.`);
