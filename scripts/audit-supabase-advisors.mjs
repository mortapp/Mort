const projectRef = "rakjydmgwwgtdislanbt";
const accessToken = process.env.SUPABASE_ACCESS_TOKEN;

if (!accessToken) {
  throw new Error("Missing SUPABASE_ACCESS_TOKEN. The value is never printed.");
}

const foundationTerms = [
  "legal_accept",
  "legal_document",
  "job_contract",
  "payment_dispute",
  "payment_obligation",
  "poster_payment",
  "document_web_reuse",
  "live_presence",
  "appearance_review",
  "team_role",
  "team_training",
  "team_access",
];

function findingsFrom(payload) {
  if (Array.isArray(payload)) return payload;
  for (const key of ["lints", "findings", "advisors", "data"]) {
    if (Array.isArray(payload?.[key])) return payload[key];
  }
  throw new Error("Supabase advisor response did not contain a recognized findings array.");
}

function levelOf(finding) {
  return String(finding.level ?? finding.severity ?? finding.category ?? "unknown").toLowerCase();
}

function typeOf(finding) {
  return String(finding.name ?? finding.title ?? finding.id ?? "unknown");
}

function countTypes(findings) {
  return findings.reduce((counts, finding) => {
    const type = typeOf(finding);
    counts[type] = (counts[type] ?? 0) + 1;
    return counts;
  }, {});
}

async function loadAdvisor(kind) {
  const response = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/advisors/${kind}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok) {
    throw new Error(`Supabase ${kind} advisor request failed with HTTP ${response.status}.`);
  }
  return findingsFrom(await response.json());
}

const output = {};
let errorCount = 0;
for (const kind of ["security", "performance"]) {
  const findings = await loadAdvisor(kind);
  const levels = {};
  for (const finding of findings) {
    const level = levelOf(finding);
    levels[level] = (levels[level] ?? 0) + 1;
    if (level === "error") errorCount += 1;
  }
  const foundationFindings = findings.filter((finding) => {
    const searchable = JSON.stringify(finding).toLowerCase();
    return foundationTerms.some((term) => searchable.includes(term));
  });
  const leakedPasswordFindings = findings.filter((finding) => /leaked.password|haveibeenpwned/i.test(JSON.stringify(finding)));

  output[kind] = {
    total: findings.length,
    levels,
    finding_types: countTypes(findings),
    legal_trust_foundation_findings: foundationFindings.length,
    legal_trust_foundation_types: countTypes(foundationFindings),
    legal_trust_foundation_levels: foundationFindings.reduce((counts, finding) => {
      const level = levelOf(finding);
      counts[level] = (counts[level] ?? 0) + 1;
      return counts;
    }, {}),
    legal_trust_unindexed_foreign_keys: foundationFindings
      .filter((finding) => typeOf(finding) === "unindexed_foreign_keys")
      .map((finding) => ({
        title: finding.title ?? null,
        description: finding.description ?? null,
        metadata: finding.metadata ?? null,
      })),
    leaked_password_findings: leakedPasswordFindings.length,
  };
}

output.project_ref = projectRef;
output.status = errorCount === 0 ? "PASS_NO_ERROR_LEVEL_FINDINGS" : "FAIL_ERROR_LEVEL_FINDINGS";
output.leaked_password_classification = "DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT";
output.secrets_printed = false;

console.log(JSON.stringify(output));
if (errorCount > 0) process.exitCode = 1;
