const authoritativeProductionRef = "jxbnrkasktbhtiujkhay";

export function resolveBackupTarget(projectRef) {
  if (!projectRef?.trim()) {
    throw new Error("Set MORT_BACKUP_PROJECT_REF to the authoritative production project reference.");
  }
  if (projectRef.trim() !== authoritativeProductionRef) {
    throw new Error("Backup target must be the authoritative production project.");
  }
  return authoritativeProductionRef;
}
