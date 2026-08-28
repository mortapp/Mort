import Foundation

struct BusinessRegistrySearchResult: Codable, Hashable, Sendable {
    let jurisdiction: String
    let legalBusinessName: String
    let registrationNumber: String
    let entityType: String?
    let registrationStatus: String
    let formationDate: Date?
    let registeredOfficePresent: Bool?
    let officialSourceURL: URL
    let snapshotAt: Date

    enum CodingKeys: String, CodingKey {
        case jurisdiction
        case legalBusinessName = "legal_business_name"
        case registrationNumber = "registration_number"
        case entityType = "entity_type"
        case registrationStatus = "registration_status"
        case formationDate = "formation_date"
        case registeredOfficePresent = "registered_office_present"
        case officialSourceURL = "official_source_url"
        case snapshotAt = "snapshot_at"
    }
}

struct BusinessRegistryMatch: Codable, Hashable, Sendable {
    let checkID: UUID
    let result: BusinessRegistrySearchResult
    let status: String
    let matchConfidence: Decimal?
    let mismatchExplanation: String?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case result, status
        case checkID = "check_id"
        case matchConfidence = "match_confidence"
        case mismatchExplanation = "mismatch_explanation"
        case expiresAt = "expires_at"
    }
}

struct BusinessRepresentativeClaim: Codable, Hashable, Sendable {
    let claimID: UUID
    let checkID: UUID
    let relationship: String
    let status: String
    let identityVerified: Bool
    let attestedAt: Date

    enum CodingKeys: String, CodingKey {
        case relationship, status
        case claimID = "claim_id"
        case checkID = "check_id"
        case identityVerified = "identity_verified"
        case attestedAt = "attested_at"
    }
}

struct BusinessVerificationDecision: Codable, Hashable, Sendable {
    let status: String
    let registryRecordMatched: Bool
    let representativeAuthorityVerified: Bool
    let grantsMarketplaceAccess: Bool
    let publicLabel: String?
    let explanation: String

    enum CodingKeys: String, CodingKey {
        case status, explanation
        case registryRecordMatched = "registry_record_matched"
        case representativeAuthorityVerified = "representative_authority_verified"
        case grantsMarketplaceAccess = "grants_marketplace_access"
        case publicLabel = "public_label"
    }
}
