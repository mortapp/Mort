import Foundation
import Supabase

protocol GuardianRepositoryProtocol: Sendable {
    func createInvite(email: String?) async throws -> GenericRPCResult
    func acceptInvite(code: String) async throws -> UUID
    func skipSetup() async throws
    func cancelInvite(linkID: UUID) async throws
    func resendInvite(linkID: UUID) async throws -> GenericRPCResult
    func unlink(linkID: UUID) async throws
    func policy() async throws -> GuardianPolicy
    func connections() async throws -> [GuardianConnection]
    func updatePreferences(_ preferences: GuardianPreferences) async throws
    func setTeenPause(teenID: UUID, paused: Bool, reason: String?) async throws
    func emergencyContact() async throws -> EmergencyContact?
    func saveEmergencyContact(name: String?, phone: String?) async throws
}

final class GuardianRepository: SupabaseRepository, GuardianRepositoryProtocol {
    func createInvite(email: String?) async throws -> GenericRPCResult {
        struct Params: Encodable { let p_invite_email: String? }
        return try await translated {
            let result: GenericRPCResult = try await client.rpc("create_guardian_invite_v2", params: Params(p_invite_email: email?.nilIfBlank)).execute().value
            return try result.requireSuccess(defaultMessage: "The guardian invitation could not be created.")
        }
    }

    func acceptInvite(code: String) async throws -> UUID {
        struct Params: Encodable { let p_invite_code: String }
        return try await translated {
            try await client.rpc("accept_guardian_invite", params: Params(p_invite_code: code.trimmed.uppercased())).execute().value
        }
    }

    func skipSetup() async throws {
        try await translated {
            let result: GenericRPCResult = try await client.rpc("set_guardian_setup_skipped").execute().value
            _ = try result.requireSuccess(defaultMessage: "Guardian Mode could not be skipped.")
        }
    }

    func cancelInvite(linkID: UUID) async throws {
        struct Params: Encodable { let p_link_id: UUID }
        try await translated {
            let result: GenericRPCResult = try await client.rpc("cancel_guardian_invite", params: Params(p_link_id: linkID)).execute().value
            _ = try result.requireSuccess(defaultMessage: "The guardian invitation could not be cancelled.")
        }
    }

    func resendInvite(linkID: UUID) async throws -> GenericRPCResult {
        struct Params: Encodable { let p_link_id: UUID }
        return try await translated {
            let result: GenericRPCResult = try await client.rpc("resend_guardian_invite", params: Params(p_link_id: linkID)).execute().value
            return try result.requireSuccess(defaultMessage: "The guardian invitation could not be resent.")
        }
    }

    func unlink(linkID: UUID) async throws {
        struct Params: Encodable { let p_link_id: UUID }
        try await translated {
            let result: GenericRPCResult = try await client.rpc("unlink_guardian", params: Params(p_link_id: linkID)).execute().value
            _ = try result.requireSuccess(defaultMessage: "Guardian Mode could not be unlinked.")
        }
    }

    func policy() async throws -> GuardianPolicy {
        try await translated { try await client.rpc("get_guardian_policy_for_user").execute().value }
    }

    func connections() async throws -> [GuardianConnection] {
        try await translated {
            _ = try await currentUserID()
            return try await client.from("guardian_connections")
                .select("*,guardian_preferences(*),teen:profiles!guardian_connections_teen_id_fkey(id,display_name,username,verification_status,avatar_path),guardian:profiles!guardian_connections_guardian_id_fkey(id,display_name,username,verification_status,avatar_path)")
                .order("created_at", ascending: false).execute().value
        }
    }

    func updatePreferences(_ preferences: GuardianPreferences) async throws {
        struct Update: Encodable {
            let safety_ping_alerts: Bool
            let job_checkin_alerts: Bool
            let accepted_job_summary: Bool
            let safety_warning_alerts: Bool
            let weekly_digest: Bool
            let optional_job_approval_enabled: Bool
        }
        struct IDRow: Decodable { let link_id: UUID }
        try await translated {
            let rows: [IDRow] = try await client.from("guardian_preferences").update(Update(
                safety_ping_alerts: preferences.safetyPingAlerts,
                job_checkin_alerts: preferences.jobCheckinAlerts,
                accepted_job_summary: preferences.acceptedJobSummary,
                safety_warning_alerts: preferences.safetyWarningAlerts,
                weekly_digest: preferences.weeklyDigest,
                optional_job_approval_enabled: preferences.optionalJobApprovalEnabled
            )).eq("link_id", value: preferences.linkID).select("link_id").execute().value
            guard !rows.isEmpty else { throw MortError.backend(code: "unknown_permission_failure", message: "These Guardian Mode preferences could not be updated.") }
        }
    }

    func setTeenPause(teenID: UUID, paused: Bool, reason: String?) async throws {
        struct Params: Encodable { let p_teen_id: UUID; let p_paused: Bool; let p_reason: String? }
        try await translated {
            let result: GenericRPCResult = try await client.rpc("set_teen_pause", params: Params(
                p_teen_id: teenID,
                p_paused: paused,
                p_reason: reason?.nilIfBlank
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The teen account pause could not be updated.")
        }
    }

    func emergencyContact() async throws -> EmergencyContact? {
        try await translated {
            let rows: [EmergencyContact] = try await client.from("guardian_profiles")
                .select("user_id,emergency_contact_name,emergency_contact_phone")
                .eq("user_id", value: try await currentUserID()).limit(1).execute().value
            return rows.first
        }
    }

    func saveEmergencyContact(name: String?, phone: String?) async throws {
        struct Input: Encodable {
            let user_id: UUID
            let emergency_contact_name: String?
            let emergency_contact_phone: String?
        }
        try await translated {
            try await client.from("guardian_profiles").upsert(Input(
                user_id: try await currentUserID(),
                emergency_contact_name: name?.nilIfBlank,
                emergency_contact_phone: phone?.nilIfBlank
            )).execute()
        }
    }
}
