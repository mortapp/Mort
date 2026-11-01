const productionGuardianLinksTable = 'guardian_links';
const productionUserBlocksTable = 'user_blocks';
const productionSafetyReportsTable = 'safety_reports';

Map<String, dynamic> mapProductionGuardianLink(Map<String, dynamic> row) {
  final mapped = Map<String, dynamic>.from(row);
  final status = mapped['status'];
  if (status == 'pending') mapped['status'] = 'invited';
  mapped['accepted_at'] = status == 'active'
      ? mapped['guardian_consent_at'] ?? mapped['teen_consent_at']
      : null;
  return mapped;
}

Map<String, dynamic> mapProductionSafetyReport(Map<String, dynamic> row) {
  final mapped = Map<String, dynamic>.from(row);
  mapped['reason'] ??= mapped['category'];
  return mapped;
}
