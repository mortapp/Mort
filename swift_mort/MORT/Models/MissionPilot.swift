import Foundation

struct ClosedPilotEligibility: Codable, Hashable, Sendable {
    let allowed: Bool
    let code: String?
    let missingRequirements: [String]?
    let reasonCodes: [String]?
    let policyVersion: Int?
    let pilotModeEnabled: Bool?
    let unrestrictedPublicAccessEnabled: Bool?
    let realDocumentCollectionEnabled: Bool?
    let guardianModeOptional: Bool?
    let guardianConnectionRequired: Bool?
    let permanentAddressRequired: Bool?
    let housingStatusCollected: Bool?
    let supportCircleAffectsEligibility: Bool?

    enum CodingKeys: String, CodingKey {
        case allowed, code
        case missingRequirements = "missing_requirements"
        case reasonCodes = "reason_codes"
        case policyVersion = "policy_version"
        case pilotModeEnabled = "pilot_mode_enabled"
        case unrestrictedPublicAccessEnabled = "unrestricted_public_access_enabled"
        case realDocumentCollectionEnabled = "real_document_collection_enabled"
        case guardianModeOptional = "guardian_mode_optional"
        case guardianConnectionRequired = "guardian_connection_required"
        case permanentAddressRequired = "permanent_address_required"
        case housingStatusCollected = "housing_status_collected"
        case supportCircleAffectsEligibility = "support_circle_affects_eligibility"
    }
}

struct MissionPilotDashboard: Codable, Hashable, Sendable {
    let ok: Bool
    let mission: String
    let pilotEligibility: ClosedPilotEligibility
    let discreetMode: DiscreetModeState
    let supportCircle: SupportCircleState
    let activeGoalCount: Int
    let reviewedResourceCount: Int
    let documentReview: DocumentCollectionReadiness
    let mortHoldsPayments: Bool
    let runawayGuidanceProvided: Bool

    enum CodingKeys: String, CodingKey {
        case ok, mission
        case pilotEligibility = "pilot_eligibility"
        case discreetMode = "discreet_mode"
        case supportCircle = "support_circle"
        case activeGoalCount = "active_goal_count"
        case reviewedResourceCount = "reviewed_resource_count"
        case documentReview = "document_review"
        case mortHoldsPayments = "mort_holds_payments"
        case runawayGuidanceProvided = "runaway_guidance_provided"
    }
}

struct DiscreetModeState: Codable, Hashable, Sendable {
    let enabled: Bool
    let genericNotificationTitle: Bool?
    let hideNotificationContent: Bool?
    let appLockEnabled: Bool?
    let automaticLockMinutes: Int?
    let quickExitDestination: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case genericNotificationTitle = "generic_notification_title"
        case hideNotificationContent = "hide_notification_content"
        case appLockEnabled = "app_lock_enabled"
        case automaticLockMinutes = "automatic_lock_minutes"
        case quickExitDestination = "quick_exit_destination"
    }
}

struct SupportCircleState: Codable, Hashable, Sendable {
    let enabled: Bool
    let memberCount: Int
    let optional: Bool
    let affectsEligibility: Bool

    enum CodingKeys: String, CodingKey {
        case enabled, optional
        case memberCount = "member_count"
        case affectsEligibility = "affects_eligibility"
    }
}

struct DocumentCollectionReadiness: Codable, Hashable, Sendable {
    let ready: Bool
    let realDocumentCollectionEnabled: Bool
    let clientCanEnable: Bool
    let collectionStatus: String
    let requiredGateCount: Int
    let passedGateCount: Int
    let remainingGateKeys: [String]
    let truthStatement: String

    enum CodingKeys: String, CodingKey {
        case ready
        case realDocumentCollectionEnabled = "real_document_collection_enabled"
        case clientCanEnable = "client_can_enable"
        case collectionStatus = "collection_status"
        case requiredGateCount = "required_gate_count"
        case passedGateCount = "passed_gate_count"
        case remainingGateKeys = "remaining_gate_keys"
        case truthStatement = "truth_statement"
    }
}

struct MissionPilotActionResult: Codable, Hashable, Sendable {
    let ok: Bool
    let code: String?
    let status: String?
    let message: String?
    let enrollmentID: UUID?
    let manualApprovalRequired: Bool?
    let guardianModeOptional: Bool?
    let permanentAddressRequired: Bool?
    let enabled: Bool?
    let optional: Bool?
    let affectsMarketplaceEligibility: Bool?

    enum CodingKeys: String, CodingKey {
        case ok, code, status, message, enabled, optional
        case enrollmentID = "enrollment_id"
        case manualApprovalRequired = "manual_approval_required"
        case guardianModeOptional = "guardian_mode_optional"
        case permanentAddressRequired = "permanent_address_required"
        case affectsMarketplaceEligibility = "affects_marketplace_eligibility"
    }
}

struct PartnerAttestationItem: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let factType: String
    let version: Int
    let status: String
    let statement: String
    let whatWasNotEstablished: String
    let effectiveAt: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case id, version, status, statement
        case factType = "fact_type"
        case whatWasNotEstablished = "what_was_not_established"
        case effectiveAt = "effective_at"
        case expiresAt = "expires_at"
    }
}

struct PartnerAttestationsResponse: Codable, Hashable, Sendable {
    let ok: Bool
    let identityVerified: Bool
    let governmentIDVerified: Bool
    let attestations: [PartnerAttestationItem]

    enum CodingKeys: String, CodingKey {
        case ok, attestations
        case identityVerified = "identity_verified"
        case governmentIDVerified = "government_id_verified"
    }
}

struct DocumentReviewCaseSummary: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let evidenceCategory: String
    let status: String
    let publicLabel: String
    let whatWasEstablished: String
    let whatWasNotEstablished: String
    let finalDecisionAt: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case evidenceCategory = "evidence_category"
        case publicLabel = "public_label"
        case whatWasEstablished = "what_was_established"
        case whatWasNotEstablished = "what_was_not_established"
        case finalDecisionAt = "final_decision_at"
        case expiresAt = "expires_at"
    }
}

struct IndependenceGoal: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let goalType: String
    let title: String
    let targetAmountCents: Int?
    let currentAmountCents: Int
    let targetDate: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case goalType = "goal_type"
        case targetAmountCents = "target_amount_cents"
        case currentAmountCents = "current_amount_cents"
        case targetDate = "target_date"
    }
}

struct ResourceDirectoryEntry: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let organizationName: String
    let category: String
    let sourceURL: String
    let sourceStatus: String
    let organizationVerificationStatus: String
    let city: String?
    let state: String?
    let summary: String
    let emergencyLimitations: String
    let availabilityClaimed: Bool

    enum CodingKeys: String, CodingKey {
        case id, category, city, state, summary
        case organizationName = "organization_name"
        case sourceURL = "source_url"
        case sourceStatus = "source_status"
        case organizationVerificationStatus = "organization_verification_status"
        case emergencyLimitations = "emergency_limitations"
        case availabilityClaimed = "availability_claimed"
    }
}

struct PrivateWorkSummary: Codable, Hashable, Sendable {
    let ok: Bool
    let totalSelfRecordedEarningsCents: Int
    let completedJobCount: Int
    let skillCount: Int
    let referenceCount: Int
    let mortHoldsPayments: Bool
    let mortGuaranteesPayments: Bool
    let privateByDefault: Bool

    enum CodingKeys: String, CodingKey {
        case ok
        case totalSelfRecordedEarningsCents = "total_self_recorded_earnings_cents"
        case completedJobCount = "completed_job_count"
        case skillCount = "skill_count"
        case referenceCount = "reference_count"
        case mortHoldsPayments = "mort_holds_payments"
        case mortGuaranteesPayments = "mort_guarantees_payments"
        case privateByDefault = "private_by_default"
    }
}
