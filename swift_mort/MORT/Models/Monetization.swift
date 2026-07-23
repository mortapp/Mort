import Foundation

enum MortEntitlement: String, CaseIterable, Codable, Sendable {
    case plus = "mort_plus"
    case adFree = "mort_ad_free"
    case adultPro = "mort_adult_pro"
    case guardianPlus = "mort_guardian_plus"
    case lifetime = "mort_lifetime"
    case profileStylePack = "mort_profile_style_pack"
    case usernameChangeToken = "mort_username_change_token"
    case jobBoost = "mort_job_boost"
}

struct EntitlementState: Equatable, Sendable {
    var active: Set<MortEntitlement> = []

    func has(_ entitlement: MortEntitlement) -> Bool { active.contains(entitlement) }
    var isPlus: Bool { has(.plus) || has(.lifetime) }
    var isAdFree: Bool { has(.adFree) || isPlus }
    var isAdultPro: Bool { has(.adultPro) }
    var isGuardianPlus: Bool { has(.guardianPlus) }
    var hasUsernameToken: Bool { has(.usernameChangeToken) }
    var hasJobBoost: Bool { has(.jobBoost) }
    var hasProfileStylePack: Bool { has(.profileStylePack) || isPlus }
}

struct FeatureAccess: Equatable, Sendable {
    let state: EntitlementState
    let adsEnabled: Bool

    var canShowAds: Bool { adsEnabled && !state.isAdFree }
    var canUsePremiumThemes: Bool { state.hasProfileStylePack }
    var canUseAdvancedFilters: Bool { state.isPlus }
    var canUseAdultApplicantSorting: Bool { state.isAdultPro }
    var canUseGuardianWeeklyDigest: Bool { state.isGuardianPlus }
    var safetyToolsFree: Bool { true }
    var basicApplyingFree: Bool { true }
    var basicGuardianModeFree: Bool { true }
    var proofUploadFree: Bool { true }
}

struct BackendEntitlements: Codable, Hashable, Sendable {
    let premiumActive: Bool
    let adFreeActive: Bool
    let adultProActive: Bool
    let businessBoostActive: Bool
    let guardianPlusActive: Bool
    let entitlements: [String]
    let refreshedAt: String?

    enum CodingKeys: String, CodingKey {
        case premiumActive = "premium_active"
        case adFreeActive = "ad_free_active"
        case adultProActive = "adult_pro_active"
        case businessBoostActive = "business_boost_active"
        case guardianPlusActive = "guardian_plus_active"
        case entitlements
        case refreshedAt = "refreshed_at"
    }

    static let empty = BackendEntitlements(
        premiumActive: false,
        adFreeActive: false,
        adultProActive: false,
        businessBoostActive: false,
        guardianPlusActive: false,
        entitlements: [],
        refreshedAt: nil
    )
}

struct JobBoostStatus: Codable, Hashable, Sendable {
    let availableCredits: Int
    let usedCredits: Int

    enum CodingKeys: String, CodingKey {
        case availableCredits = "available_credits"
        case usedCredits = "used_credits"
    }

    static let empty = JobBoostStatus(availableCredits: 0, usedCredits: 0)
}

struct AdEligibility: Codable, Hashable, Sendable {
    let allowed: Bool
    let reason: String
    let requestNonPersonalized: Bool

    enum CodingKeys: String, CodingKey {
        case allowed, reason
        case requestNonPersonalized = "request_non_personalized"
    }
}

struct SubscriptionStatus: Codable, Hashable, Sendable {
    let userID: UUID
    let premiumActive: Bool
    let adFreeActive: Bool
    let adultProActive: Bool
    let businessBoostActive: Bool
    let guardianPlusActive: Bool
    let currentProductID: String?
    let currentPeriodEndsAt: String?
    let source: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case source
        case userID = "user_id"
        case premiumActive = "premium_active"
        case adFreeActive = "ad_free_active"
        case adultProActive = "adult_pro_active"
        case businessBoostActive = "business_boost_active"
        case guardianPlusActive = "guardian_plus_active"
        case currentProductID = "current_product_id"
        case currentPeriodEndsAt = "current_period_ends_at"
        case updatedAt = "updated_at"
    }
}

struct AdPreferences: Codable, Hashable, Sendable {
    let userID: UUID
    var personalizedAdsAllowed: Bool
    var adsConsentReady: Bool
    var ageRestrictedAds: Bool
    let lastPromptedAt: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case personalizedAdsAllowed = "personalized_ads_allowed"
        case adsConsentReady = "ads_consent_ready"
        case ageRestrictedAds = "age_restricted_ads"
        case lastPromptedAt = "last_prompted_at"
    }
}

struct BoostedJob: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let jobID: UUID
    let userID: UUID
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case jobID = "job_id"
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

struct AdminRecord: Decodable, Hashable, Identifiable, Sendable {
    let id: String
    let payload: [String: JSONValue]

    init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer().decode([String: JSONValue].self)
        guard let idValue = values["id"] else { throw MortError.invalidResponse }
        switch idValue {
        case let .string(value): id = value
        case let .number(value): id = String(Int(value))
        default: throw MortError.invalidResponse
        }
        payload = values
    }

    func text(_ key: String) -> String? { payload[key]?.stringValue }
}
