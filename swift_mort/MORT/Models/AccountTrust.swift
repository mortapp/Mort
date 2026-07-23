import Foundation

enum AccountTrustLevel: Int, Codable, CaseIterable, Sendable {
    case basic = 0
    case secured = 1
    case affiliation = 2
    case digitalGovernmentCredential = 3
    case providerIdentity = 4
    case enhancedAdultScreening = 5

    var key: String { "TRUST_LEVEL_\(rawValue)" }

    var title: String {
        switch self {
        case .basic: "Basic account"
        case .secured: "Account secured"
        case .affiliation: "Affiliation verified"
        case .digitalGovernmentCredential: "Government digital ID verified"
        case .providerIdentity: "Provider identity verified"
        case .enhancedAdultScreening: "Enhanced adult screening"
        }
    }
}

struct TrustIndicator: Codable, Hashable, Identifiable, Sendable {
    let key: String
    let category: String
    let label: String
    let status: String
    let whatWasChecked: String
    let whatWasNotChecked: String
    let checkedAt: String?
    let expiresAt: String?
    let grantsMarketplaceAccess: Bool
    let doesNotGuaranteeSafety: Bool
    let environment: String?

    var id: String { "\(key)-\(environment ?? "current")" }

    enum CodingKeys: String, CodingKey {
        case key, category, label, status, environment
        case whatWasChecked = "what_was_checked"
        case whatWasNotChecked = "what_was_not_checked"
        case checkedAt = "checked_at"
        case expiresAt = "expires_at"
        case grantsMarketplaceAccess = "grants_marketplace_access"
        case doesNotGuaranteeSafety = "does_not_guarantee_safety"
    }
}

struct MarketplaceTrustEligibility: Codable, Hashable, Sendable {
    let allowed: Bool
    let action: String?
    let requiredLevel: Int
    let currentLevel: Int
    let missingRequirements: [String]
    let reasonCodes: [String]
    let retryAfter: String?
    let supportRoute: String
    let policyVersion: Int?
    let productionMarketplaceEnabled: Bool?
    let guardianModeOptional: Bool?
    let testMode: Bool?

    enum CodingKeys: String, CodingKey {
        case allowed, action
        case requiredLevel = "required_level"
        case currentLevel = "current_level"
        case missingRequirements = "missing_requirements"
        case reasonCodes = "reason_codes"
        case retryAfter = "retry_after"
        case supportRoute = "support_route"
        case policyVersion = "policy_version"
        case productionMarketplaceEnabled = "production_marketplace_enabled"
        case guardianModeOptional = "guardian_mode_optional"
        case testMode = "test_mode"
    }
}

struct AccountTrustContactStatus: Codable, Hashable, Sendable {
    let emailVerified: Bool
    let phoneVerified: Bool
    let phoneVerificationAvailable: Bool
    let emailOrPhoneIsLegalIdentity: Bool

    enum CodingKeys: String, CodingKey {
        case emailVerified = "email_verified"
        case phoneVerified = "phone_verified"
        case phoneVerificationAvailable = "phone_verification_available"
        case emailOrPhoneIsLegalIdentity = "email_or_phone_is_legal_identity"
    }
}

struct AccountSecuritySummary: Codable, Hashable, Sendable {
    let passkeyCount: Int
    let passkeysEnabledByServer: Bool
    let deviceBiometricsAreLocalAccountSecurityOnly: Bool
    let suspiciousSessionMonitoringEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case passkeyCount = "passkey_count"
        case passkeysEnabledByServer = "passkeys_enabled_by_server"
        case deviceBiometricsAreLocalAccountSecurityOnly = "device_biometrics_are_local_account_security_only"
        case suspiciousSessionMonitoringEnabled = "suspicious_session_monitoring_enabled"
    }
}

struct AccountRiskSummary: Codable, Hashable, Sendable {
    let riskLevel: String
    let riskReasons: [String]
    let recommendedAction: String
    let humanReviewRequired: Bool
    let notACriminalAccusation: Bool

    enum CodingKeys: String, CodingKey {
        case riskLevel = "risk_level"
        case riskReasons = "risk_reasons"
        case recommendedAction = "recommended_action"
        case humanReviewRequired = "human_review_required"
        case notACriminalAccusation = "not_a_criminal_accusation"
    }
}

struct AccountTrustAvailability: Codable, Hashable, Sendable {
    let productionMarketplaceEnabled: Bool
    let identityDocumentCollectionEnabled: Bool
    let providerIdentityAvailable: Bool
    let appleWalletEnabled: Bool
    let androidDigitalCredentialsEnabled: Bool
    let manualAffiliationEvidenceCollectionEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case productionMarketplaceEnabled = "production_marketplace_enabled"
        case identityDocumentCollectionEnabled = "identity_document_collection_enabled"
        case providerIdentityAvailable = "provider_identity_available"
        case appleWalletEnabled = "apple_wallet_enabled"
        case androidDigitalCredentialsEnabled = "android_digital_credentials_enabled"
        case manualAffiliationEvidenceCollectionEnabled = "manual_affiliation_evidence_collection_enabled"
    }
}

struct AccountTrustProfile: Codable, Hashable, Sendable {
    let ok: Bool
    let currentLevel: Int
    let levelKey: String
    let levelTitle: String
    let signalEnvironment: String
    let indicators: [TrustIndicator]
    let contactStatus: AccountTrustContactStatus
    let accountSecurity: AccountSecuritySummary
    let identityStatus: String
    let marketplaceEligibility: MarketplaceTrustEligibility
    let riskProfile: AccountRiskSummary
    let availability: AccountTrustAvailability
    let guardianModeOptional: Bool
    let schoolNamePublicByDefault: Bool
    let residentialAddressPublic: Bool
    let emailOrPhonePublic: Bool
    let peopleSearchUsed: Bool
    let safetyGuarantee: Bool
    let policyVersion: Int
    let calculatedAt: String?

    var level: AccountTrustLevel { AccountTrustLevel(rawValue: currentLevel) ?? .basic }

    enum CodingKeys: String, CodingKey {
        case ok, indicators
        case currentLevel = "current_level"
        case levelKey = "level_key"
        case levelTitle = "level_title"
        case signalEnvironment = "signal_environment"
        case contactStatus = "contact_status"
        case accountSecurity = "account_security"
        case identityStatus = "identity_status"
        case marketplaceEligibility = "marketplace_eligibility"
        case riskProfile = "risk_profile"
        case availability
        case guardianModeOptional = "guardian_mode_optional"
        case schoolNamePublicByDefault = "school_name_public_by_default"
        case residentialAddressPublic = "residential_address_public"
        case emailOrPhonePublic = "email_or_phone_public"
        case peopleSearchUsed = "people_search_used"
        case safetyGuarantee = "safety_guarantee"
        case policyVersion = "policy_version"
        case calculatedAt = "calculated_at"
    }
}

struct AccountTrustActionResult: Codable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let status: String?
    let requestID: UUID?
    let signalID: UUID?
    let membershipID: UUID?
    let checkID: UUID?
    let claimID: UUID?
    let appealID: UUID?
    let affiliationVerified: Bool?
    let identityVerified: Bool?
    let governmentIDVerified: Bool?
    let businessRecordMatched: Bool?
    let representativeIdentityVerified: Bool?
    let providerRequired: Bool?
    let grantsMarketplaceAccess: Bool?
    let publicVisibility: Bool?

    enum CodingKeys: String, CodingKey {
        case ok, code, message, status
        case requestID = "request_id"
        case signalID = "signal_id"
        case membershipID = "membership_id"
        case checkID = "check_id"
        case claimID = "claim_id"
        case appealID = "appeal_id"
        case affiliationVerified = "affiliation_verified"
        case identityVerified = "identity_verified"
        case governmentIDVerified = "government_id_verified"
        case businessRecordMatched = "business_record_matched"
        case representativeIdentityVerified = "representative_identity_verified"
        case providerRequired = "provider_required"
        case grantsMarketplaceAccess = "grants_marketplace_access"
        case publicVisibility = "public_visibility"
    }

    func requireSuccess(defaultMessage: String) throws -> AccountTrustActionResult {
        guard ok else { throw MortError.backend(code: code ?? "account_trust_action_failed", message: message ?? defaultMessage) }
        return self
    }
}

struct TrustAdminQueueResponse: Codable, Sendable {
    let ok: Bool
    let code: String?
    let queue: String?
    let items: [[String: JSONValue]]?
    let rawIdentityEvidenceIncluded: Bool?

    enum CodingKeys: String, CodingKey {
        case ok, code, queue, items
        case rawIdentityEvidenceIncluded = "raw_identity_evidence_included"
    }
}
