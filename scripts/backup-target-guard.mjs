const authoritativeProductionRef = "jxbnrkasktbhtiujkhay";

export function resolveBackupTarget(projectRef) {
  const selectedRef = projectRef?.trim() || authoritativeProductionRef;
  if (selectedRef !== authoritativeProductionRef) {
    throw new Error("Backup target must be the authoritative production project.");
  }
  return authoritativeProductionRef;
}
