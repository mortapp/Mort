import Foundation

enum IdentityEvidenceRoute: String, CaseIterable, Identifiable, Codable, Sendable {
    case schoolPhotoID = "school_photo_id"
    case governmentID = "government_id"
    case verifiedSchoolAccount = "verified_school_account"
    case approvedProgramID = "approved_program_id"
    case manualException = "manual_exception"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .schoolPhotoID: "School photo ID"
        case .governmentID: "Government ID"
        case .verifiedSchoolAccount: "Verified school account"
        case .approvedProgramID: "Approved program ID"
        case .manualException: "Manual exception review"
        }
    }
}

enum IdentityEvidenceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case schoolPhotoID = "school_photo_id"
    case driversLicense = "drivers_license"
    case stateID = "state_id"
    case learnerPermit = "learner_permit"
    case passport = "passport"
    case passportCard = "passport_card"
    case otherGovernmentID = "other_government_id"
    case schoolAccountAssertion = "school_account_assertion"
    case accreditedProgramID = "accredited_program_id"
    case youthOrganizationID = "youth_organization_id"
    case homeschoolDocument = "homeschool_document"
    case supportingDocument = "supporting_document"
    case ownershipSelfie = "ownership_selfie"
    case addressDocument = "address_document"

    var id: String { rawValue }
    var title: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
}

struct IdentityEvidenceSummary: Codable, Hashable, Sendable {
    let type: String
    let status: String
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case type, status
        case submittedAt = "submitted_at"
    }
}

struct IdentityVerificationSummary: Codable, Hashable, Sendable {
    let ok: Bool
    let code: String?
    let id: UUID?
    let role: String?
    let status: String
    let evidenceRoute: String?
    let verificationLevel: Int
    let ageBand: String?
    let submittedAt: String?
    let reviewedAt: String?
    let expiresAt: String?
    let appealStatus: String?
    let rejectionCode: String?
    let marketplaceEnabled: Bool
    let guardianModeOptional: Bool
    let evidenceTypes: [IdentityEvidenceSummary]?
    let rawDocumentsVisibleToMarketplaceUsers: Bool?
    let verificationMode: String?
    let environment: String?
    let provider: String?
    let providerReference: String?
    let decisionSource: String?
    let verifiedAt: String?
    let productionVerified: Bool?
    let sandboxEligible: Bool?
    let testMode: Bool?
    let submissionsEnabled: Bool?
    let productionProviderAvailable: Bool?
    let publicMessage: String?

    enum CodingKeys: String, CodingKey {
        case ok, code, id, role, status
        case evidenceRoute = "evidence_route"
        case verificationLevel = "verification_level"
        case ageBand = "age_band"
        case submittedAt = "submitted_at"
        case reviewedAt = "reviewed_at"
        case expiresAt = "expires_at"
        case appealStatus = "appeal_status"
        case rejectionCode = "rejection_code"
        case marketplaceEnabled = "marketplace_enabled"
        case guardianModeOptional = "guardian_mode_optional"
        case evidenceTypes = "evidence_types"
        case rawDocumentsVisibleToMarketplaceUsers = "raw_documents_visible_to_marketplace_users"
        case verificationMode = "verification_mode"
        case environment, provider
        case providerReference = "provider_reference"
        case decisionSource = "decision_source"
        case verifiedAt = "verified_at"
        case productionVerified = "production_verified"
        case sandboxEligible = "sandbox_eligible"
        case testMode = "test_mode"
        case submissionsEnabled = "submissions_enabled"
        case productionProviderAvailable = "production_provider_available"
        case publicMessage = "public_message"
    }
}

struct TrustSafetyActionResult: Codable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let id: UUID?
    let status: String?
    let incidentID: UUID?
    let caseNumber: String?
    let agreementVersion: Int?
    let arrivalCode: String?
    let qrPayload: String?
    let expiresAt: String?
    let shareID: UUID?
    let marketplaceEnabled: Bool?
    let inviteCode: String?
    let environment: String?
    let provider: String?
    let providerReference: String?
    let testMode: Bool?
    let documentsAllowed: Bool?
    let productionEligible: Bool?

    enum CodingKeys: String, CodingKey {
        case ok, code, message, id, status
        case incidentID = "incident_id"
        case caseNumber = "case_number"
        case agreementVersion = "agreement_version"
        case arrivalCode = "arrival_code"
        case qrPayload = "qr_payload"
        case expiresAt = "expires_at"
        case shareID = "share_id"
        case marketplaceEnabled = "marketplace_enabled"
        case inviteCode = "invite_code"
        case environment, provider
        case providerReference = "provider_reference"
        case testMode = "test_mode"
        case documentsAllowed = "documents_allowed"
        case productionEligible = "production_eligible"
    }

    func requireSuccess(defaultMessage: String) throws -> TrustSafetyActionResult {
        guard ok else { throw MortError.backend(code: code ?? "unknown_permission_failure", message: message ?? defaultMessage) }
        return self
    }
}

struct IncidentCaseSummary: Codable, Hashable, Identifiable, Sendable {
    let incidentID: UUID
    let caseNumber: String
    let category: String
    let severity: String
    let status: String
    let publicStatusNote: String?
    let createdAt: String
    let updatedAt: String
    let appealStatus: String

    var id: UUID { incidentID }

    enum CodingKeys: String, CodingKey {
        case category, severity, status
        case incidentID = "incident_id"
        case caseNumber = "case_number"
        case publicStatusNote = "public_status_note"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case appealStatus = "appeal_status"
    }
}

struct SafetyCircleMember: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let teenID: UUID
    let contactID: UUID?
    let relationshipLabel: String
    let status: String
    let receiveSafetyPing: Bool
    let receiveMissedCheckin: Bool
    let receiveJobSummary: Bool
    let receiveJobStatus: Bool
    let receiveEmergencyRequest: Bool
    let viewLimitedSafetyPlan: Bool
    let receiveCompletion: Bool

    enum CodingKeys: String, CodingKey {
        case id, status
        case teenID = "teen_id"
        case contactID = "contact_id"
        case relationshipLabel = "relationship_label"
        case receiveSafetyPing = "receive_safety_ping"
        case receiveMissedCheckin = "receive_missed_checkin"
        case receiveJobSummary = "receive_job_summary"
        case receiveJobStatus = "receive_job_status"
        case receiveEmergencyRequest = "receive_emergency_request"
        case viewLimitedSafetyPlan = "view_limited_safety_plan"
        case receiveCompletion = "receive_completion"
    }
}

struct JobSafetyAgreement: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let applicationID: UUID
    let jobID: UUID
    let teenID: UUID
    let adultID: UUID
    let agreementVersion: Int
    let termsSnapshot: [String: JSONValue]
    let status: String
    let teenConfirmedAt: String?
    let adultConfirmedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case applicationID = "application_id"
        case jobID = "job_id"
        case teenID = "teen_id"
        case adultID = "adult_id"
        case agreementVersion = "agreement_version"
        case termsSnapshot = "terms_snapshot"
        case teenConfirmedAt = "teen_confirmed_at"
        case adultConfirmedAt = "adult_confirmed_at"
    }
}

struct AuthorizedLocationShare: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let applicationID: UUID
    let ownerID: UUID
    let recipientUserID: UUID?
    let mode: String
    let coarseLocation: String?
    let latitude: Double?
    let longitude: Double?
    let status: String
    let expiresAt: String
    let lastLocationAt: String?

    enum CodingKeys: String, CodingKey {
        case id, mode, latitude, longitude, status
        case applicationID = "application_id"
        case ownerID = "owner_id"
        case recipientUserID = "recipient_user_id"
        case coarseLocation = "coarse_location"
        case expiresAt = "expires_at"
        case lastLocationAt = "last_location_at"
    }
}

struct ActiveAccountSession: Codable, Hashable, Identifiable, Sendable {
    let sessionReference: String
    let createdAt: String?
    let updatedAt: String?
    let refreshedAt: String?
    let userAgent: String?
    let assuranceLevel: String?
    let isCurrent: Bool

    var id: String { sessionReference }

    enum CodingKeys: String, CodingKey {
        case sessionReference = "session_reference"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case refreshedAt = "refreshed_at"
        case userAgent = "user_agent"
        case assuranceLevel = "assurance_level"
        case isCurrent = "is_current"
    }
}
