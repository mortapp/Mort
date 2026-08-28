class IdentityVerificationStatus {
  const IdentityVerificationStatus({
    required this.status,
    required this.verificationLevel,
    required this.marketplaceEnabled,
    required this.guardianModeOptional,
    required this.verificationMode,
    required this.productionVerified,
    required this.sandboxEligible,
    required this.testMode,
    required this.submissionsEnabled,
    required this.productionProviderAvailable,
    required this.canRetry,
    required this.supportEscalationAvailable,
    required this.documentsCollectedByMort,
    this.id,
    this.role,
    this.evidenceRoute,
    this.environment,
    this.provider,
    this.providerReference,
    this.decisionSource,
    this.expiresAt,
    this.rejectionCode,
    this.publicMessage,
    this.failureCode,
    this.privacyNoticeVersion,
    this.evidenceTypes = const [],
  });

  factory IdentityVerificationStatus.fromMap(Map<String, dynamic> map) {
    return IdentityVerificationStatus(
      id: map['id'] as String?,
      role: map['role'] as String?,
      status: map['status'] as String? ?? 'unverified',
      evidenceRoute: map['evidence_route'] as String?,
      verificationLevel: (map['verification_level'] as num?)?.toInt() ?? 0,
      marketplaceEnabled: map['marketplace_enabled'] == true,
      guardianModeOptional: map['guardian_mode_optional'] != false,
      verificationMode: map['verification_mode'] as String? ?? 'disabled',
      productionVerified: map['production_verified'] == true,
      sandboxEligible: map['sandbox_eligible'] == true,
      testMode: map['test_mode'] == true,
      submissionsEnabled: map['submissions_enabled'] == true,
      productionProviderAvailable: map['production_provider_available'] == true,
      canRetry: map['can_retry'] == true,
      supportEscalationAvailable: map['support_escalation_available'] != false,
      documentsCollectedByMort: map['documents_collected_by_mort'] == true,
      environment: map['environment'] as String?,
      provider: map['provider'] as String?,
      providerReference: map['provider_reference'] as String?,
      decisionSource: map['decision_source'] as String?,
      expiresAt: map['expires_at'] as String?,
      rejectionCode: map['rejection_code'] as String?,
      publicMessage: map['public_message'] as String?,
      failureCode: map['failure_code'] as String?,
      privacyNoticeVersion: map['privacy_notice_version'] as String?,
      evidenceTypes: List<Map<String, dynamic>>.from(
        map['evidence_types'] as List? ?? const [],
      ),
    );
  }

  final String? id;
  final String? role;
  final String status;
  final String? evidenceRoute;
  final int verificationLevel;
  final bool marketplaceEnabled;
  final bool guardianModeOptional;
  final String verificationMode;
  final bool productionVerified;
  final bool sandboxEligible;
  final bool testMode;
  final bool submissionsEnabled;
  final bool productionProviderAvailable;
  final bool canRetry;
  final bool supportEscalationAvailable;
  final bool documentsCollectedByMort;
  final String? environment;
  final String? provider;
  final String? providerReference;
  final String? decisionSource;
  final String? expiresAt;
  final String? rejectionCode;
  final String? publicMessage;
  final String? failureCode;
  final String? privacyNoticeVersion;
  final List<Map<String, dynamic>> evidenceTypes;
}

class SafetyIncidentSummary {
  const SafetyIncidentSummary({
    required this.id,
    required this.caseNumber,
    required this.category,
    required this.severity,
    required this.status,
    this.publicStatusNote,
    this.appealStatus = 'none',
  });

  factory SafetyIncidentSummary.fromMap(Map<String, dynamic> map) {
    return SafetyIncidentSummary(
      id: map['incident_id'] as String,
      caseNumber: map['case_number'] as String,
      category: map['category'] as String,
      severity: map['severity'] as String,
      status: map['status'] as String,
      publicStatusNote: map['public_status_note'] as String?,
      appealStatus: map['appeal_status'] as String? ?? 'none',
    );
  }

  final String id;
  final String caseNumber;
  final String category;
  final String severity;
  final String status;
  final String? publicStatusNote;
  final String appealStatus;
}

class SafetyCircleContact {
  const SafetyCircleContact({
    required this.id,
    required this.teenId,
    required this.relationshipLabel,
    required this.status,
    required this.permissions,
    this.contactId,
  });

  factory SafetyCircleContact.fromMap(Map<String, dynamic> map) {
    return SafetyCircleContact(
      id: map['id'] as String,
      teenId: map['teen_id'] as String,
      contactId: map['contact_id'] as String?,
      relationshipLabel: map['relationship_label'] as String,
      status: map['status'] as String,
      permissions: {
        'receive_safety_ping': map['receive_safety_ping'] == true,
        'receive_missed_checkin': map['receive_missed_checkin'] == true,
        'receive_job_summary': map['receive_job_summary'] == true,
        'receive_job_status': map['receive_job_status'] == true,
        'receive_emergency_request': map['receive_emergency_request'] == true,
        'view_limited_safety_plan': map['view_limited_safety_plan'] == true,
        'receive_completion': map['receive_completion'] == true,
      },
    );
  }

  final String id;
  final String teenId;
  final String? contactId;
  final String relationshipLabel;
  final String status;
  final Map<String, bool> permissions;
}

class JobSafetyAgreement {
  const JobSafetyAgreement({
    required this.id,
    required this.applicationId,
    required this.jobId,
    required this.teenId,
    required this.adultId,
    required this.version,
    required this.status,
    required this.terms,
  });

  factory JobSafetyAgreement.fromMap(Map<String, dynamic> map) {
    return JobSafetyAgreement(
      id: map['id'] as String,
      applicationId: map['application_id'] as String,
      jobId: map['job_id'] as String,
      teenId: map['teen_id'] as String,
      adultId: map['adult_id'] as String,
      version: (map['agreement_version'] as num).toInt(),
      status: map['status'] as String,
      terms: Map<String, dynamic>.from(map['terms_snapshot'] as Map),
    );
  }

  final String id;
  final String applicationId;
  final String jobId;
  final String teenId;
  final String adultId;
  final int version;
  final String status;
  final Map<String, dynamic> terms;
}

class AuthorizedLocationShare {
  const AuthorizedLocationShare({
    required this.id,
    required this.applicationId,
    required this.ownerId,
    required this.mode,
    required this.status,
    this.recipientUserId,
    this.coarseLocation,
    this.expiresAt,
  });

  factory AuthorizedLocationShare.fromMap(Map<String, dynamic> map) {
    return AuthorizedLocationShare(
      id: map['id'] as String,
      applicationId: map['application_id'] as String,
      ownerId: map['owner_id'] as String,
      recipientUserId: map['recipient_user_id'] as String?,
      mode: map['mode'] as String,
      status: map['status'] as String,
      coarseLocation: map['coarse_location'] as String?,
      expiresAt: map['expires_at'] as String?,
    );
  }

  final String id;
  final String applicationId;
  final String ownerId;
  final String? recipientUserId;
  final String mode;
  final String status;
  final String? coarseLocation;
  final String? expiresAt;
}

class AccountSessionSummary {
  const AccountSessionSummary({
    required this.reference,
    required this.userAgent,
    required this.assuranceLevel,
    required this.isCurrent,
  });

  factory AccountSessionSummary.fromMap(Map<String, dynamic> map) {
    return AccountSessionSummary(
      reference: map['session_reference'] as String,
      userAgent: map['user_agent'] as String? ?? 'Unknown device',
      assuranceLevel: map['assurance_level'] as String? ?? 'unknown',
      isCurrent: map['is_current'] == true,
    );
  }

  final String reference;
  final String userAgent;
  final String assuranceLevel;
  final bool isCurrent;
}
