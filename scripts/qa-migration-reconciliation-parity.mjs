import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";

const migrationsDirectory = new URL("../supabase/migrations/", import.meta.url);

const mappings = [
  {
    hostedTimestamp: "20260818233800",
    canonicalFile: "20260818200000_quick_accept_job_v1.sql",
    semanticHash: "4ae72e06347fb9118e1576b3099a0e544359a7256739e574f741da41286da713",
    aliasFile: "20260818233800_compatibility_alias_quick_accept_job_v1.sql",
  },
  {
    hostedTimestamp: "20260819003851",
    canonicalFile: "20260818210000_quick_accept_job_opt_in.sql",
    semanticHash: "8bc4f080788408736e6ea532f9e263020be1d0515bbc2a6f26d12d7b99036fcf",
    aliasFile: "20260819003851_compatibility_alias_quick_accept_job_opt_in.sql",
  },
  {
    hostedTimestamp: "20260819004344",
    canonicalFile: "20260819000000_job_site_precise_location_and_distance.sql",
    semanticHash: "293a14370f27b2b892d82d8bddfc829265ab7ee6433b399b65db7fad59daefdd",
    aliasFile: "20260819004344_compatibility_alias_job_site_precise_location_and_distance.sql",
  },
  {
    hostedTimestamp: "20260819004628",
    canonicalFile: "20260819000100_fix_job_private_location_address_nullable.sql",
    semanticHash: "0c10a23b6cb2f35e3c52142e9e31e7489b0d38a9dd83fdc60d70a999614af9ab",
    aliasFile: "20260819004628_compatibility_alias_fix_job_private_location_address_nullable.sql",
  },
  {
    hostedTimestamp: "20260819025837",
    canonicalFile: "20260819010000_leaderboard_v1.sql",
    semanticHash: "b4c843a01d79f3ed2e4513ec23d0580674505c632dc85a8fa90038bfc9dedac4",
    aliasFile: "20260819025837_compatibility_alias_leaderboard_v1.sql",
  },
  {
    hostedTimestamp: "20260820113638",
    canonicalFile: "20260820000000_apple_identity_controls.sql",
    semanticHash: "d5e6943fb89f76596d75016e2e5c8d217c0b727871d52fb0b6fe0486202680d6",
    aliasFile: "20260820113638_compatibility_alias_apple_identity_controls.sql",
  },
  {
    hostedTimestamp: "20260820122024",
    canonicalFile: "20260820120000_mort_spark_rewarded_ads.sql",
    semanticHash: "b99c7b0c6eb615a2234711c801a2ed5c749a0aabc0a4d71c37312046caa900c0",
    aliasFile: "20260820122024_compatibility_alias_mort_spark_rewarded_ads.sql",
  },
];

function executableSql(value) {
  return value
    .replace(/\r\n/g, "\n")
    .split("\n")
    .map((line) => line.replace(/^\s*--.*$/, ""))
    .join("\n")
    .replace(/\s+/g, " ")
    .trim();
}

function semanticHash(value) {
  return createHash("sha256").update(executableSql(value)).digest("hex");
}

for (const mapping of mappings) {
  const canonicalSql = await readFile(
    new URL(mapping.canonicalFile, migrationsDirectory),
    "utf8",
  );
  assert.equal(
    semanticHash(canonicalSql),
    mapping.semanticHash,
    `${mapping.canonicalFile} no longer matches the verified hosted SQL`,
  );

  const aliasSql = await readFile(
    new URL(mapping.aliasFile, migrationsDirectory),
    "utf8",
  ).catch(() => null);
  assert.ok(aliasSql, `missing compatibility alias ${mapping.aliasFile}`);
  assert.equal(
    executableSql(aliasSql),
    "",
    `${mapping.aliasFile} must remain an executable SQL no-op`,
  );
  assert.match(aliasSql, new RegExp(`HOSTED_TIMESTAMP=${mapping.hostedTimestamp}`));
  assert.match(aliasSql, new RegExp(`CANONICAL_LOCAL_MIGRATION=${mapping.canonicalFile}`));
  assert.match(aliasSql, new RegExp(`SEMANTIC_SHA256=${mapping.semanticHash}`));
  assert.match(aliasSql, /COMPARISON_RESULT=SEMANTICALLY_EQUIVALENT/);
}

const aliasFiles = (await readdir(migrationsDirectory))
  .filter((file) => file.includes("_compatibility_alias_"))
  .sort();
assert.deepEqual(
  aliasFiles,
  mappings.map((mapping) => mapping.aliasFile).sort(),
  "the compatibility alias set must contain exactly the seven verified mappings",
);

console.log(
  "[qa-migration-reconciliation-parity] Seven canonical migrations match their verified hosted semantic hashes; all aliases are SQL no-ops.",
);
