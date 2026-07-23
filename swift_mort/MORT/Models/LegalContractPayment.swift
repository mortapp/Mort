import Foundation

struct LegalRequirementsResponse: Codable, Sendable {
    let ok: Bool
    let guardianModeOptional: Bool
    let acceptanceInferredFromBrowsing: Bool
    let requirements: [LegalRequirementItem]

    enum CodingKeys: String, CodingKey {
        case ok, requirements
        case guardianModeOptional = "guardian_mode_optional"
        case acceptanceInferredFromBrowsing = "acceptance_inferred_from_browsing"
    }
}

struct LegalRequirementItem: Codable, Hashable, Identifiable, Sendable {
    let documentKey: String
    let title: String
    let required: Bool
    let documentID: UUID
    let versionID: UUID
    let versionLabel: String
    let contentHash: String
    let effectiveAt: String
    let languageCode: String
    let jurisdictionPolicy: String
    let acceptanceUIVersion: String
    let requiresElectronicSignature: Bool
    let acceptanceID: UUID?
    let acceptedAt: String?
    let reacceptanceRequirementID: UUID?

    var id: UUID { versionID }
    var needsAcceptance: Bool { acceptanceID == nil || reacceptanceRequirementID != nil }

    enum CodingKeys: String, CodingKey {
        case title, required
        case documentKey = "document_key"
        case documentID = "document_id"
        case versionID = "version_id"
        case versionLabel = "version_label"
        case contentHash = "content_hash"
        case effectiveAt = "effective_at"
        case languageCode = "language_code"
        case jurisdictionPolicy = "jurisdiction_policy"
        case acceptanceUIVersion = "acceptance_ui_version"
        case requiresElectronicSignature = "requires_electronic_signature"
        case acceptanceID = "acceptance_id"
        case acceptedAt = "accepted_at"
        case reacceptanceRequirementID = "reacceptance_requirement_id"
    }
}

struct PublishedLegalVersion: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let documentID: UUID
    let versionLabel: String
    let contentHash: String
    let contentMarkdown: String
    let effectiveAt: String
    let publicationStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case documentID = "document_id"
        case versionLabel = "version_label"
        case contentHash = "content_hash"
        case contentMarkdown = "content_markdown"
        case effectiveAt = "effective_at"
        case publicationStatus = "publication_status"
    }
}

struct LegalAcceptanceResult: Codable, Sendable {
    let ok: Bool
    let code: String?
    let acceptanceID: UUID?
    let documentVersionID: UUID?
    let contentHash: String?
    let acceptedAt: String?

    enum CodingKeys: String, CodingKey {
        case ok, code
        case acceptanceID = "acceptance_id"
        case documentVersionID = "document_version_id"
        case contentHash = "content_hash"
        case acceptedAt = "accepted_at"
    }
}

struct JobContractRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let jobID: UUID
    let applicationID: UUID
    let teenID: UUID
    let adultID: UUID
    let status: String
    let activeVersionID: UUID?
    let classificationStatus: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case jobID = "job_id"
        case applicationID = "application_id"
        case teenID = "teen_id"
        case adultID = "adult_id"
        case activeVersionID = "active_version_id"
        case classificationStatus = "classification_status"
        case createdAt = "created_at"
    }
}

struct JobContractVersionRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let contractID: UUID
    let versionNumber: Int
    let status: String
    let contentHash: String
    let teenPublicIdentifier: String
    let adultPublicIdentifier: String
    let agreedScope: String
    let excludedWork: [String]
    let locationType: String
    let exactLocationReleaseState: String
    let serviceDate: String
    let startWindow: String?
    let expectedEndWindow: String?
    let amountType: String
    let hourlyRateCents: Int?
    let maximumApprovedHours: Double?
    let fixedTotalCents: Int?
    let currencyCode: String
    let paymentPreference: String
    let paymentDueRule: String
    let authorizedExpenses: [String]
    let equipment: String
    let hazards: String
    let expectedPeoplePresent: String
    let supervision: String
    let proofRequirements: String
    let completionRequirements: String
    let cancellationTerms: String
    let materialChangeProcess: String
    let disputeProcess: String
    let safetyAgreementVersion: String

    var amountDisplay: String {
        if let fixedTotalCents { return Self.money(fixedTotalCents, code: currencyCode) }
        if let hourlyRateCents { return "\(Self.money(hourlyRateCents, code: currencyCode))/hour" }
        return "Amount unavailable"
    }

    private static func money(_ cents: Int, code: String) -> String {
        (Double(cents) / 100).formatted(.currency(code: code))
    }

    enum CodingKeys: String, CodingKey {
        case id, status, equipment, hazards, supervision
        case contractID = "contract_id"
        case versionNumber = "version_number"
        case contentHash = "content_hash"
        case teenPublicIdentifier = "teen_public_identifier"
        case adultPublicIdentifier = "adult_public_identifier"
        case agreedScope = "agreed_scope"
        case excludedWork = "excluded_work"
        case locationType = "location_type"
        case exactLocationReleaseState = "exact_location_release_state"
        case serviceDate = "service_date"
        case startWindow = "start_window"
        case expectedEndWindow = "expected_end_window"
        case amountType = "amount_type"
        case hourlyRateCents = "hourly_rate_cents"
        case maximumApprovedHours = "maximum_approved_hours"
        case fixedTotalCents = "fixed_total_cents"
        case currencyCode = "currency_code"
        case paymentPreference = "payment_preference"
        case paymentDueRule = "payment_due_rule"
        case authorizedExpenses = "authorized_expenses"
        case expectedPeoplePresent = "expected_people_present"
        case proofRequirements = "proof_requirements"
        case completionRequirements = "completion_requirements"
        case cancellationTerms = "cancellation_terms"
        case materialChangeProcess = "material_change_process"
        case disputeProcess = "dispute_process"
        case safetyAgreementVersion = "safety_agreement_version"
    }
}

struct JobContractAcceptanceRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let contractVersionID: UUID
    let userID: UUID
    let partyRole: String
    let contentHash: String
    let acceptedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case contractVersionID = "contract_version_id"
        case userID = "user_id"
        case partyRole = "party_role"
        case contentHash = "content_hash"
        case acceptedAt = "accepted_at"
    }
}

struct JobContractChangeRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let contractID: UUID
    let requestedBy: UUID
    let changeCategories: [String]
    let proposedTerms: [String: JSONValue]
    let proposedContentHash: String
    let reason: String
    let status: String
    let requestedAt: String

    enum CodingKeys: String, CodingKey {
        case id, reason, status
        case contractID = "contract_id"
        case requestedBy = "requested_by"
        case changeCategories = "change_categories"
        case proposedTerms = "proposed_terms"
        case proposedContentHash = "proposed_content_hash"
        case requestedAt = "requested_at"
    }
}

struct PaymentObligationRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let contractID: UUID
    let amountCents: Int
    let currencyCode: String
    let paymentPreference: String
    let dueRule: String
    let dueAt: String?
    let status: String
    let becameDueAt: String?
    let satisfiedAt: String?
    let disputedAt: String?

    var amountDisplay: String { (Double(amountCents) / 100).formatted(.currency(code: currencyCode)) }

    enum CodingKeys: String, CodingKey {
        case id, status
        case contractID = "contract_id"
        case amountCents = "amount_cents"
        case currencyCode = "currency_code"
        case paymentPreference = "payment_preference"
        case dueRule = "due_rule"
        case dueAt = "due_at"
        case becameDueAt = "became_due_at"
        case satisfiedAt = "satisfied_at"
        case disputedAt = "disputed_at"
    }
}

struct PaymentDisputeRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let obligationID: UUID
    let contractID: UUID
    let status: String
    let guiltDetermined: Bool
    let classificationStatus: String
    let workerStatement: String
    let posterStatement: String?
    let retaliationReviewActive: Bool
    let publicationPaused: Bool
    let openedAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case obligationID = "obligation_id"
        case contractID = "contract_id"
        case guiltDetermined = "guilt_determined"
        case classificationStatus = "classification_status"
        case workerStatement = "worker_statement"
        case posterStatement = "poster_statement"
        case retaliationReviewActive = "retaliation_review_active"
        case publicationPaused = "publication_paused"
        case openedAt = "opened_at"
    }
}

struct PaymentDisputeTimelineRecord: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let eventType: String
    let eventSummary: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case eventSummary = "event_summary"
        case createdAt = "created_at"
    }
}

struct FirstPartyTrustStatus: Codable, Hashable, Sendable {
    let realDocumentCollectionEnabled: Bool
    let externalWebReuseEnabled: Bool
    let realLivePresenceEnabled: Bool
    let realAppearanceReviewEnabled: Bool
    let syntheticQAOnly: Bool
    let authoritativeIdentityProviderConnected: Bool
    let publicMarketplaceOpen: Bool
    let documentQualityIsIdentity: Bool
    let webReuseIsAuthenticity: Bool
    let livenessIsLegalIdentity: Bool
    let deviceBiometricIsLegalIdentity: Bool
    let guardianModeOptional: Bool

    enum CodingKeys: String, CodingKey {
        case realDocumentCollectionEnabled = "real_document_collection_enabled"
        case externalWebReuseEnabled = "external_web_reuse_enabled"
        case realLivePresenceEnabled = "real_live_presence_enabled"
        case realAppearanceReviewEnabled = "real_appearance_review_enabled"
        case syntheticQAOnly = "synthetic_qa_only"
        case authoritativeIdentityProviderConnected = "authoritative_identity_provider_connected"
        case publicMarketplaceOpen = "public_marketplace_open"
        case documentQualityIsIdentity = "document_quality_is_identity"
        case webReuseIsAuthenticity = "web_reuse_is_authenticity"
        case livenessIsLegalIdentity = "liveness_is_legal_identity"
        case deviceBiometricIsLegalIdentity = "device_biometric_is_legal_identity"
        case guardianModeOptional = "guardian_mode_optional"
    }
}

struct TeamRoleAssignmentRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let userID: UUID
    let roleKey: String
    let environmentScope: String
    let accessStatus: String
    let approvalReason: String
    let accessReason: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case roleKey = "role_key"
        case environmentScope = "environment_scope"
        case accessStatus = "access_status"
        case approvalReason = "approval_reason"
        case accessReason = "access_reason"
        case expiresAt = "expires_at"
    }
}

struct AppearanceReviewCaseRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let subjectUserID: UUID
    let reviewState: String
    let finalResult: String?
    let syntheticQA: Bool
    let containsRealFaceData: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case subjectUserID = "subject_user_id"
        case reviewState = "review_state"
        case finalResult = "final_result"
        case syntheticQA = "synthetic_qa"
        case containsRealFaceData = "contains_real_face_data"
    }
}
