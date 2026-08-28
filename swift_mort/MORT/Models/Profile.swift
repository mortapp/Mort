import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case teen
    case adult
    case guardian
    case admin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teen: "Teen"
        case .adult: "Adult / Business"
        case .guardian: "Guardian"
        case .admin: "Admin"
        }
    }
}

struct Profile: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let role: UserRole?
    let displayName: String?
    let username: String?
    let dob: String?
    let city: String?
    let state: String?
    let locationSetupMode: String?
    let onboardingCompleted: Bool
    let accountStatus: String
    let verificationStatus: String
    let paymentPreference: String
    let guardianSetupStatus: String
    let avatarPath: String?
    let avatarModerationStatus: String
    let bio: String?
    let availability: String?
    let preferredJobCategories: [String]
    let approximateArea: String?
    let goals: String?

    enum CodingKeys: String, CodingKey {
        case id, role, username, dob, city, state, bio, availability, goals
        case locationSetupMode = "location_setup_mode"
        case displayName = "display_name"
        case onboardingCompleted = "onboarding_completed"
        case accountStatus = "account_status"
        case verificationStatus = "verification_status"
        case paymentPreference = "payment_preference"
        case guardianSetupStatus = "guardian_setup_status"
        case avatarPath = "avatar_path"
        case avatarModerationStatus = "avatar_moderation_status"
        case preferredJobCategories = "preferred_job_categories"
        case approximateArea = "approximate_area"
    }

    var isActive: Bool { accountStatus == "active" }
    var isOnboarded: Bool { onboardingCompleted && role != nil }
    var name: String { displayName?.nilIfBlank ?? username?.nilIfBlank ?? "MORT member" }

    var completionRatio: Double {
        let checks = [
            displayName?.nilIfBlank != nil,
            username?.nilIfBlank != nil,
            avatarPath?.nilIfBlank != nil,
            bio?.nilIfBlank != nil,
            availability?.nilIfBlank != nil,
            !preferredJobCategories.isEmpty,
            locationSetupMode != "city_state" || (city?.nilIfBlank != nil && state?.nilIfBlank != nil),
            paymentPreference != "none",
            onboardingCompleted,
        ]
        return Double(checks.filter { $0 }.count) / Double(checks.count)
    }
}

struct ProfileSummary: Codable, Hashable, Sendable {
    let id: UUID?
    let displayName: String?
    let username: String?
    let verificationStatus: String?
    let avatarPath: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case verificationStatus = "verification_status"
        case avatarPath = "avatar_path"
    }

    var name: String { displayName?.nilIfBlank ?? username?.nilIfBlank ?? "MORT member" }
}

struct AdultBusinessProfile: Codable, Hashable, Sendable {
    let userID: UUID
    let businessName: String?
    let businessType: String?
    let verificationNotes: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case businessName = "business_name"
        case businessType = "business_type"
        case verificationNotes = "verification_notes"
    }
}

struct EmergencyContact: Codable, Hashable, Sendable {
    let userID: UUID
    let name: String?
    let phone: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case name = "emergency_contact_name"
        case phone = "emergency_contact_phone"
    }
}

struct ProfileUpsert: Encodable, Sendable {
    let id: UUID
    let role: UserRole
    let displayName: String
    let dob: String
    let city: String?
    let state: String?
    let locationSetupMode: String
    let paymentPreference: String
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, role, dob, city, state
        case locationSetupMode = "location_setup_mode"
        case displayName = "display_name"
        case paymentPreference = "payment_preference"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct ProfileDetailsUpdate: Encodable, Sendable {
    let displayName: String
    let bio: String?
    let availability: String?
    let preferredJobCategories: [String]
    let approximateArea: String?
    let goals: String?

    enum CodingKeys: String, CodingKey {
        case bio, availability, goals
        case displayName = "display_name"
        case preferredJobCategories = "preferred_job_categories"
        case approximateArea = "approximate_area"
    }
}

struct PaymentPreferenceInput: Encodable, Sendable {
    let userID: UUID
    let preference: String
    let cashAppTag: String?
    let squareURL: String?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case preference, note
        case userID = "user_id"
        case cashAppTag = "cash_app_tag"
        case squareURL = "square_url"
    }
}

struct RoleProfileInput: Encodable, Sendable {
    let userID: UUID

    enum CodingKeys: String, CodingKey { case userID = "user_id" }
}

struct UsernameChangeStatus: Codable, Hashable, Sendable {
    let currentUsername: String?
    let freeChangesUsed: Int
    let freeChangesRemaining: Int
    let tokenCredits: Int
    let adminCredits: Int
    let plusAllowanceAvailable: Bool
    let plusChangesUsed: Int
    let plusPeriodStart: String?

    enum CodingKeys: String, CodingKey {
        case currentUsername = "current_username"
        case freeChangesUsed = "free_changes_used"
        case freeChangesRemaining = "free_changes_remaining"
        case tokenCredits = "token_credits"
        case adminCredits = "admin_credits"
        case plusAllowanceAvailable = "plus_allowance_available"
        case plusChangesUsed = "plus_changes_used"
        case plusPeriodStart = "plus_period_start"
    }

    static let empty = UsernameChangeStatus(
        currentUsername: nil,
        freeChangesUsed: 0,
        freeChangesRemaining: 3,
        tokenCredits: 0,
        adminCredits: 0,
        plusAllowanceAvailable: false,
        plusChangesUsed: 0,
        plusPeriodStart: nil
    )
}
