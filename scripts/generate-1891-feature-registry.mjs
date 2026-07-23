import {
  CATEGORY_QUOTAS,
  REJECTED_CANDIDATES,
  buildRegistry,
  countBy,
  writeRegistryArtifacts,
} from "./feature-registry-core.mjs";

const records = buildRegistry();
writeRegistryArtifacts(records);

const categoryCounts = countBy(records, "category");
const quotaSummary = [...CATEGORY_QUOTAS.entries()]
  .map(([category, expected]) => category + "=" + (categoryCounts.get(category) || 0) + "/" + expected)
  .join("; ");

console.log("Generated " + records.length + " accepted MORT feature records.");
console.log("Category quotas: " + quotaSummary);
console.log("Duplicate candidates removed: " + REJECTED_CANDIDATES.filter((item) => item.status === "duplicate_removed").length + ".");
console.log("Unsafe or invalid candidates rejected: " + REJECTED_CANDIDATES.filter((item) => item.status === "rejected").length + ".");
