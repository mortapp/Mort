import Foundation
import Supabase

protocol ProfileRepositoryProtocol: Sendable {
    func currentProfile() async throws -> Profile?
    func profile(id: UUID) async throws -> Profile?
    func saveProfile(role: UserRole, displayName: String, dob: Date, city: String?, state: String?, locationSetupMode: String, paymentPreference: String, completeOnboarding: Bool) async throws -> Profile
    func saveDetails(_ input: ProfileDetailsUpdate) async throws -> Profile
    func adultBusinessProfile() async throws -> AdultBusinessProfile?
    func saveAdultBusinessProfile(name: String?, type: String) async throws
    func savePaymentPreference(preference: String, cashAppTag: String?, squareURL: String?, note: String?) async throws
    func completeOnboarding() async throws
    func setAvatarPath(_ path: String?) async throws
    func usernameChangeStatus() async throws -> UsernameChangeStatus
    func requestUsernameChange(_ username: String) async throws -> UsernameChangeRPCResult
}

final class ProfileRepository: SupabaseRepository, ProfileRepositoryProtocol {
    private static let directorySelect = "id,role,display_name,verification_status,username,avatar_path,avatar_moderation_status,bio,availability,preferred_job_categories,approximate_area,goals,onboarding_completed,account_status,payment_preference,guardian_setup_status,dob,city,state,location_setup_mode"

    func currentProfile() async throws -> Profile? {
        try await translated {
            let rows: [Profile] = try await client.rpc("get_my_profile").execute().value
            return rows.first
        }
    }

    func profile(id: UUID) async throws -> Profile? {
        try await translated {
            let rows: [Profile] = try await client
                .from("profiles")
                .select(Self.directorySelect)
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value
            return rows.first
        }
    }

    func saveProfile(
        role: UserRole,
        displayName: String,
        dob: Date,
        city: String?,
        state: String?,
        locationSetupMode: String = "city_state",
        paymentPreference: String = "none",
        completeOnboarding: Bool = false
    ) async throws -> Profile {
        try await translated {
            let id = try await currentUserID()
            let allowedLocationModes = ["city_state", "partner_supported", "location_deferred"]
            guard allowedLocationModes.contains(locationSetupMode) else {
                throw MortError.invalidInput("Choose a valid location setup option.")
            }
            if role != .teen && locationSetupMode != "city_state" {
                throw MortError.invalidInput("Adult and guardian profiles require city and state.")
            }
            let storesCityState = locationSetupMode == "city_state"
            let input = ProfileUpsert(
                id: id,
                role: role,
                displayName: displayName.trimmed,
                dob: DateOfBirthRules.isoDate(dob),
                city: storesCityState ? city?.nilIfBlank : nil,
                state: storesCityState ? state?.nilIfBlank?.uppercased() : nil,
                locationSetupMode: locationSetupMode,
                paymentPreference: paymentPreference,
                onboardingCompleted: completeOnboarding
            )
            try await client.from("profiles").upsert(input).execute()

            let table = switch role {
            case .teen: "teen_profiles"
            case .adult: "adult_profiles"
            case .guardian: "guardian_profiles"
            case .admin: throw MortError.invalidInput("Admin accounts cannot be created in onboarding.")
            }
            try await client.from(table).upsert(RoleProfileInput(userID: id)).execute()

            guard let profile = try await currentProfile() else { throw MortError.invalidResponse }
            return profile
        }
    }

    func saveDetails(_ input: ProfileDetailsUpdate) async throws -> Profile {
        try await translated {
            let id = try await currentUserID()
            try await client.from("profiles").update(input).eq("id", value: id).execute()
            guard let profile = try await currentProfile() else { throw MortError.invalidResponse }
            return profile
        }
    }

    func adultBusinessProfile() async throws -> AdultBusinessProfile? {
        try await translated {
            let rows: [AdultBusinessProfile] = try await client.from("adult_profiles")
                .select("user_id,business_name,business_type,verification_notes")
                .eq("user_id", value: try await currentUserID()).limit(1).execute().value
            return rows.first
        }
    }

    func saveAdultBusinessProfile(name: String?, type: String) async throws {
        struct Input: Encodable {
            let user_id: UUID
            let business_name: String?
            let business_type: String
        }
        let allowed = ["individual", "business", "nonprofit"]
        guard allowed.contains(type) else { throw MortError.invalidInput("Choose a valid adult or business account type.") }
        try await translated {
            try await client.from("adult_profiles").upsert(Input(
                user_id: try await currentUserID(),
                business_name: name?.nilIfBlank,
                business_type: type
            )).execute()
        }
    }

    func savePaymentPreference(preference: String, cashAppTag: String?, squareURL: String?, note: String?) async throws {
        try await translated {
            let id = try await currentUserID()
            try await client.from("payment_preferences").upsert(PaymentPreferenceInput(
                userID: id,
                preference: preference,
                cashAppTag: cashAppTag?.nilIfBlank,
                squareURL: squareURL?.nilIfBlank,
                note: note?.nilIfBlank
            )).execute()
            try await client.from("profiles").update(["payment_preference": preference]).eq("id", value: id).execute()
        }
    }

    func completeOnboarding() async throws {
        try await translated {
            try await client.from("profiles")
                .update(["onboarding_completed": true])
                .eq("id", value: try await currentUserID())
                .execute()
        }
    }

    func setAvatarPath(_ path: String?) async throws {
        struct Input: Encodable { let avatar_path: String?; let avatar_moderation_status: String; let avatar_updated_at: String }
        try await translated {
            let input = Input(
                avatar_path: path,
                avatar_moderation_status: path == nil ? "removed" : "active",
                avatar_updated_at: Date().iso8601String
            )
            try await client.from("profiles").update(input).eq("id", value: try await currentUserID()).execute()
        }
    }

    func usernameChangeStatus() async throws -> UsernameChangeStatus {
        try await translated {
            let rows: [UsernameChangeStatus] = try await client.rpc("get_username_change_status").execute().value
            return rows.first ?? .empty
        }
    }

    func requestUsernameChange(_ username: String) async throws -> UsernameChangeRPCResult {
        struct Params: Encodable { let p_new_username: String }
        return try await translated {
            let result: UsernameChangeRPCResult = try await client
                .rpc("request_username_change", params: Params(p_new_username: username.trimmed))
                .execute()
                .value
            guard result.ok else { throw MortError.backend(code: result.code ?? "unknown_permission_failure", message: result.message) }
            return result
        }
    }
}
