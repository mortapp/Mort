class ClosedPilotEligibility {
  const ClosedPilotEligibility({
    required this.allowed,
    required this.code,
    required this.missingRequirements,
    required this.reasonCodes,
    required this.guardianModeOptional,
    required this.permanentAddressRequired,
    required this.realDocumentCollectionEnabled,
  });

  final bool allowed;
  final String? code;
  final List<String> missingRequirements;
  final List<String> reasonCodes;
  final bool guardianModeOptional;
  final bool permanentAddressRequired;
  final bool realDocumentCollectionEnabled;

  factory ClosedPilotEligibility.fromMap(Map<String, dynamic> map) {
    return ClosedPilotEligibility(
      allowed: map['allowed'] == true,
      code: map['code']?.toString(),
      missingRequirements: _strings(map['missing_requirements']),
      reasonCodes: _strings(map['reason_codes']),
      guardianModeOptional: map['guardian_mode_optional'] != false,
      permanentAddressRequired: map['permanent_address_required'] == true,
      realDocumentCollectionEnabled:
          map['real_document_collection_enabled'] == true,
    );
  }
}

class MissionPilotDashboard {
  const MissionPilotDashboard({
    required this.mission,
    required this.eligibility,
    required this.discreetMode,
    required this.supportCircle,
    required this.activeGoalCount,
    required this.reviewedResourceCount,
    required this.documentReadiness,
  });

  final String mission;
  final ClosedPilotEligibility eligibility;
  final Map<String, dynamic> discreetMode;
  final Map<String, dynamic> supportCircle;
  final int activeGoalCount;
  final int reviewedResourceCount;
  final DocumentCollectionReadiness documentReadiness;

  factory MissionPilotDashboard.fromMap(Map<String, dynamic> map) {
    return MissionPilotDashboard(
      mission:
          map['mission']?.toString() ??
          'Help teenagers gain legitimate income, work experience, skills, references, and safe pathways toward adulthood.',
      eligibility: ClosedPilotEligibility.fromMap(
        _map(map['pilot_eligibility']),
      ),
      discreetMode: _map(map['discreet_mode']),
      supportCircle: _map(map['support_circle']),
      activeGoalCount: _integer(map['active_goal_count']),
      reviewedResourceCount: _integer(map['reviewed_resource_count']),
      documentReadiness: DocumentCollectionReadiness.fromMap(
        _map(map['document_review']),
      ),
    );
  }
}

class PartnerAttestation {
  const PartnerAttestation({
    required this.id,
    required this.factType,
    required this.version,
    required this.status,
    required this.statement,
    required this.whatWasNotEstablished,
  });

  final String id;
  final String factType;
  final int version;
  final String status;
  final String statement;
  final String whatWasNotEstablished;

  factory PartnerAttestation.fromMap(Map<String, dynamic> map) {
    return PartnerAttestation(
      id: map['id'].toString(),
      factType: map['fact_type']?.toString() ?? 'partner_relationship',
      version: _integer(map['version']),
      status: map['status']?.toString() ?? 'unknown',
      statement: map['statement']?.toString() ?? 'No statement available.',
      whatWasNotEstablished:
          map['what_was_not_established']?.toString() ??
          'Government identity was not established.',
    );
  }
}

class DocumentCollectionReadiness {
  const DocumentCollectionReadiness({
    required this.ready,
    required this.realDocumentCollectionEnabled,
    required this.clientCanEnable,
    required this.requiredGateCount,
    required this.passedGateCount,
    required this.remainingGateKeys,
    required this.truthStatement,
  });

  final bool ready;
  final bool realDocumentCollectionEnabled;
  final bool clientCanEnable;
  final int requiredGateCount;
  final int passedGateCount;
  final List<String> remainingGateKeys;
  final String truthStatement;

  factory DocumentCollectionReadiness.fromMap(Map<String, dynamic> map) {
    return DocumentCollectionReadiness(
      ready: map['ready'] == true,
      realDocumentCollectionEnabled:
          map['real_document_collection_enabled'] == true,
      clientCanEnable: map['client_can_enable'] == true,
      requiredGateCount: _integer(map['required_gate_count']),
      passedGateCount: _integer(map['passed_gate_count']),
      remainingGateKeys: _strings(map['remaining_gate_keys']),
      truthStatement:
          map['truth_statement']?.toString() ??
          'Visual review does not by itself prove document authenticity or legal identity.',
    );
  }
}

class IndependenceGoal {
  const IndependenceGoal({
    required this.id,
    required this.goalType,
    required this.title,
    required this.targetAmountCents,
    required this.currentAmountCents,
    required this.status,
  });

  final String id;
  final String goalType;
  final String title;
  final int? targetAmountCents;
  final int currentAmountCents;
  final String status;

  factory IndependenceGoal.fromMap(Map<String, dynamic> map) {
    return IndependenceGoal(
      id: map['id'].toString(),
      goalType: map['goal_type']?.toString() ?? 'custom',
      title: map['title']?.toString() ?? 'Private goal',
      targetAmountCents: map['target_amount_cents'] == null
          ? null
          : _integer(map['target_amount_cents']),
      currentAmountCents: _integer(map['current_amount_cents']),
      status: map['status']?.toString() ?? 'active',
    );
  }
}

class ResourceDirectoryEntry {
  const ResourceDirectoryEntry({
    required this.id,
    required this.organizationName,
    required this.category,
    required this.sourceUrl,
    required this.sourceStatus,
    required this.summary,
    required this.emergencyLimitations,
  });

  final String id;
  final String organizationName;
  final String category;
  final String sourceUrl;
  final String sourceStatus;
  final String summary;
  final String emergencyLimitations;

  factory ResourceDirectoryEntry.fromMap(Map<String, dynamic> map) {
    return ResourceDirectoryEntry(
      id: map['id'].toString(),
      organizationName: map['organization_name']?.toString() ?? 'Resource',
      category: map['category']?.toString() ?? 'community_organization',
      sourceUrl: map['source_url']?.toString() ?? '',
      sourceStatus: map['source_status']?.toString() ?? 'pending_review',
      summary: map['summary']?.toString() ?? '',
      emergencyLimitations:
          map['emergency_limitations']?.toString() ??
          'This listing does not replace emergency services.',
    );
  }
}

Map<String, dynamic> missionMap(Object? value) => _map(value);

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}

int _integer(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
