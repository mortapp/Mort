import Foundation
import Supabase

protocol SafetyRepositoryProtocol: Sendable {
    func report(target: ReportTarget, reason: String, details: String?) async throws
    func block(userID: UUID) async throws
    func unblock(userID: UUID) async throws
    func blockedUsers() async throws -> [BlockRecord]
    func myReports() async throws -> [ReportSummary]
    func createSafetyPing(status: String, note: String?) async throws
    func visibleSafetyPings() async throws -> [SafetyPing]
    func incidentCases() async throws -> [IncidentCaseSummary]
    func submitIncidentAppeal(incidentID: UUID, reason: String) async throws
    func createSafetyCircleInvite(label: String, permissions: [String: Bool]) async throws -> String
    func acceptSafetyCircleInvite(code: String) async throws
    func safetyCircle() async throws -> [SafetyCircleMember]
    func updateSafetyCircle(id: UUID, permissions: [String: Bool]) async throws
    func unlinkSafetyCircle(id: UUID) async throws
    func safetyAgreement(applicationID: UUID) async throws -> JobSafetyAgreement?
    func saveSafetyPlan(applicationID: UUID, expectedPeople: String?, publicMeeting: Bool, daylight: Bool, transportation: String?, checkinMinutes: Int?) async throws
    func confirmSafetyAgreement(applicationID: UUID, version: Int) async throws
    func savePrivateJobLocation(jobID: UUID, address: String, arrivalInstructions: String?, accessNotes: String?) async throws
    func releasedJobLocation(applicationID: UUID) async throws -> [String: JSONValue]
    func generateArrivalCode(applicationID: UUID) async throws -> TrustSafetyActionResult
    func confirmArrival(applicationID: UUID, code: String, personMatches: Bool) async throws -> TrustSafetyActionResult
    func submitSafetyCancellation(applicationID: UUID, reason: String, details: String?) async throws
    func authorizedLocationShares() async throws -> [AuthorizedLocationShare]
    func startTemporaryLocationShare(applicationID: UUID, recipientID: UUID, mode: String, coarseLocation: String?) async throws -> TrustSafetyActionResult
    func stopTemporaryLocationShare(id: UUID) async throws
    func activeSessions() async throws -> [ActiveAccountSession]
    func reportAccountSecurityConcern(type: String, sessionReference: String?, details: String?) async throws
}

final class SafetyRepository: SupabaseRepository, SafetyRepositoryProtocol {
    func report(target: ReportTarget, reason: String, details: String?) async throws {
        struct Params: Encodable {
            let p_target_user_id: UUID?
            let p_target_job_id: UUID?
            let p_target_message_id: UUID?
            let p_target_review_id: UUID?
            let p_application_id: UUID?
            let p_category: String
            let p_severity: String
            let p_immediate_danger: Bool
            let p_details: String
            let p_occurred_at: String?
            let p_location_type: String?
            let p_desired_outcome: String?
            let p_confidential_safety_feedback: Bool
        }
        try await translated {
            _ = try await currentUserID()
            let category = Self.reportCategory(reason)
            let result: TrustSafetyActionResult = try await client.rpc("submit_safety_report", params: Params(
                p_target_user_id: target.userID,
                p_target_job_id: target.jobID,
                p_target_message_id: target.messageID,
                p_target_review_id: target.reviewID,
                p_application_id: nil,
                p_category: category,
                p_severity: ["child_safety_concern", "sexual_conduct", "threats"].contains(category) ? "high" : "moderate",
                p_immediate_danger: false,
                p_details: details?.nilIfBlank ?? "Safety concern reported for review.",
                p_occurred_at: nil,
                p_location_type: nil,
                p_desired_outcome: "Review the concern and apply proportionate safety action.",
                p_confidential_safety_feedback: ["child_safety_concern", "sexual_conduct"].contains(category)
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The safety report could not be submitted.")
        }
    }

    func block(userID: UUID) async throws {
        struct Input: Encodable { let blocker_id: UUID; let blocked_id: UUID }
        try await translated {
            try await client.from("blocks").upsert(Input(blocker_id: try await currentUserID(), blocked_id: userID)).execute()
        }
    }

    func unblock(userID: UUID) async throws {
        try await translated {
            try await client.from("blocks").delete()
                .eq("blocker_id", value: try await currentUserID()).eq("blocked_id", value: userID).execute()
        }
    }

    func blockedUsers() async throws -> [BlockRecord] {
        try await translated {
            try await client.from("blocks").select().eq("blocker_id", value: try await currentUserID())
                .order("created_at", ascending: false).execute().value
        }
    }

    func myReports() async throws -> [ReportSummary] {
        try await translated {
            try await client.from("reports").select("id,reason,status,created_at")
                .eq("reporter_id", value: try await currentUserID()).order("created_at", ascending: false).limit(50).execute().value
        }
    }

    func createSafetyPing(status: String = "needs_help", note: String?) async throws {
        struct Input: Encodable { let teen_id: UUID; let status: String; let note: String? }
        try await translated {
            try await client.from("safety_pings").insert(Input(
                teen_id: try await currentUserID(), status: status, note: note?.nilIfBlank
            )).execute()
        }
    }

    func visibleSafetyPings() async throws -> [SafetyPing] {
        try await translated {
            _ = try await currentUserID()
            return try await client.from("safety_pings")
                .select("id,teen_id,status,note,created_at,teen:profiles!safety_pings_teen_id_fkey(id,display_name,username,verification_status,avatar_path)")
                .order("created_at", ascending: false).limit(100).execute().value
        }
    }

    func incidentCases() async throws -> [IncidentCaseSummary] {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_my_incident_cases").execute().value
        }
    }

    func submitIncidentAppeal(incidentID: UUID, reason: String) async throws {
        struct Params: Encodable { let p_incident_id: UUID; let p_reason: String }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("submit_incident_appeal", params: Params(
                p_incident_id: incidentID, p_reason: reason.trimmed
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The incident appeal could not be submitted.")
        }
    }

    func createSafetyCircleInvite(label: String, permissions: [String: Bool]) async throws -> String {
        struct Params: Encodable { let p_relationship_label: String; let p_permissions: [String: Bool] }
        return try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("create_safety_circle_invite", params: Params(
                p_relationship_label: label.trimmed, p_permissions: permissions
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "A Safety Circle invitation could not be created.")
            guard let inviteCode = result.inviteCode else { throw MortError.invalidResponse }
            return inviteCode
        }
    }

    func acceptSafetyCircleInvite(code: String) async throws {
        struct Params: Encodable { let p_invite_code: String }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("accept_safety_circle_invite", params: Params(p_invite_code: code.trimmed)).execute().value
            _ = try result.requireSuccess(defaultMessage: "The Safety Circle invitation could not be accepted.")
        }
    }

    func safetyCircle() async throws -> [SafetyCircleMember] {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_my_safety_circle").execute().value
        }
    }

    func updateSafetyCircle(id: UUID, permissions: [String: Bool]) async throws {
        struct Params: Encodable { let p_circle_id: UUID; let p_permissions: [String: Bool] }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("update_safety_circle_permissions", params: Params(p_circle_id: id, p_permissions: permissions)).execute().value
            _ = try result.requireSuccess(defaultMessage: "Safety Circle permissions could not be updated.")
        }
    }

    func unlinkSafetyCircle(id: UUID) async throws {
        struct Params: Encodable { let p_circle_id: UUID }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("unlink_safety_circle_member", params: Params(p_circle_id: id)).execute().value
            _ = try result.requireSuccess(defaultMessage: "The Safety Circle link could not be removed.")
        }
    }

    func safetyAgreement(applicationID: UUID) async throws -> JobSafetyAgreement? {
        try await translated {
            let agreements: [JobSafetyAgreement] = try await client.from("job_safety_agreements").select()
                .eq("application_id", value: applicationID).limit(1).execute().value
            return agreements.first
        }
    }

    func saveSafetyPlan(applicationID: UUID, expectedPeople: String?, publicMeeting: Bool, daylight: Bool, transportation: String?, checkinMinutes: Int?) async throws {
        struct Params: Encodable {
            let p_application_id: UUID
            let p_expected_people: String?
            let p_public_or_visible_meeting: Bool
            let p_daylight_preferred: Bool
            let p_transportation_plan: String?
            let p_checkin_cadence_minutes: Int?
        }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("save_job_safety_plan", params: Params(
                p_application_id: applicationID,
                p_expected_people: expectedPeople?.nilIfBlank,
                p_public_or_visible_meeting: publicMeeting,
                p_daylight_preferred: daylight,
                p_transportation_plan: transportation?.nilIfBlank,
                p_checkin_cadence_minutes: checkinMinutes
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The safety plan could not be saved.")
        }
    }

    func confirmSafetyAgreement(applicationID: UUID, version: Int) async throws {
        struct Params: Encodable { let p_application_id: UUID; let p_agreement_version: Int }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("confirm_job_safety_agreement", params: Params(
                p_application_id: applicationID, p_agreement_version: version
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The current safety terms could not be confirmed.")
        }
    }

    func savePrivateJobLocation(jobID: UUID, address: String, arrivalInstructions: String?, accessNotes: String?) async throws {
        struct Params: Encodable { let p_job_id: UUID; let p_exact_address: String; let p_arrival_instructions: String?; let p_access_notes: String? }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("save_job_private_location", params: Params(
                p_job_id: jobID,
                p_exact_address: address.trimmed,
                p_arrival_instructions: arrivalInstructions?.nilIfBlank,
                p_access_notes: accessNotes?.nilIfBlank
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The restricted job location could not be saved.")
        }
    }

    func releasedJobLocation(applicationID: UUID) async throws -> [String: JSONValue] {
        struct Params: Encodable { let p_application_id: UUID }
        return try await translated {
            let payload: [String: JSONValue] = try await client.rpc("get_released_job_location", params: Params(p_application_id: applicationID)).execute().value
            if payload["ok"]?.boolValue != true {
                throw MortError.backend(code: payload["code"]?.stringValue ?? "exact_location_not_released", message: "The exact job location is not available at this stage.")
            }
            return payload
        }
    }

    func generateArrivalCode(applicationID: UUID) async throws -> TrustSafetyActionResult {
        struct Params: Encodable { let p_application_id: UUID }
        return try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("generate_job_arrival_code", params: Params(p_application_id: applicationID)).execute().value
            return try result.requireSuccess(defaultMessage: "An arrival code could not be generated.")
        }
    }

    func confirmArrival(applicationID: UUID, code: String, personMatches: Bool) async throws -> TrustSafetyActionResult {
        struct Params: Encodable { let p_application_id: UUID; let p_code: String; let p_person_matches_profile: Bool }
        return try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("confirm_job_arrival_code", params: Params(
                p_application_id: applicationID, p_code: code.trimmed, p_person_matches_profile: personMatches
            )).execute().value
            return try result.requireSuccess(defaultMessage: "Arrival could not be confirmed.")
        }
    }

    func submitSafetyCancellation(applicationID: UUID, reason: String, details: String?) async throws {
        struct Params: Encodable { let p_application_id: UUID; let p_reason: String; let p_details: String? }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("submit_safety_cancellation", params: Params(
                p_application_id: applicationID, p_reason: reason, p_details: details?.nilIfBlank
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The safety cancellation could not be recorded.")
        }
    }

    func authorizedLocationShares() async throws -> [AuthorizedLocationShare] {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_authorized_location_shares").execute().value
        }
    }

    func startTemporaryLocationShare(applicationID: UUID, recipientID: UUID, mode: String, coarseLocation: String?) async throws -> TrustSafetyActionResult {
        struct Params: Encodable {
            let p_application_id: UUID
            let p_recipient_user_id: UUID
            let p_mode: String
            let p_expires_at: String
            let p_coarse_location: String?
            let p_latitude: Double?
            let p_longitude: Double?
            let p_explicit_consent: Bool
        }
        return try await translated {
            let formatter = ISO8601DateFormatter()
            let result: TrustSafetyActionResult = try await client.rpc("start_temporary_location_share", params: Params(
                p_application_id: applicationID,
                p_recipient_user_id: recipientID,
                p_mode: mode,
                p_expires_at: formatter.string(from: Date().addingTimeInterval(2 * 60 * 60)),
                p_coarse_location: coarseLocation?.nilIfBlank,
                p_latitude: nil,
                p_longitude: nil,
                p_explicit_consent: true
            )).execute().value
            return try result.requireSuccess(defaultMessage: "Temporary location sharing could not be started.")
        }
    }

    func stopTemporaryLocationShare(id: UUID) async throws {
        struct Params: Encodable { let p_share_id: UUID }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("stop_temporary_location_share", params: Params(p_share_id: id)).execute().value
            _ = try result.requireSuccess(defaultMessage: "Temporary location sharing could not be stopped.")
        }
    }

    func activeSessions() async throws -> [ActiveAccountSession] {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_my_active_sessions").execute().value
        }
    }

    func reportAccountSecurityConcern(type: String, sessionReference: String?, details: String?) async throws {
        struct Params: Encodable { let p_event_type: String; let p_session_reference: String?; let p_details: String? }
        try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("report_account_security_concern", params: Params(
                p_event_type: type, p_session_reference: sessionReference, p_details: details?.nilIfBlank
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The account security concern could not be recorded.")
        }
    }

    private static func reportCategory(_ reason: String) -> String {
        switch reason {
        case "harassment": "harassment"
        case "scam": "scam"
        case "exploitation": "child_safety_concern"
        case "privacy": "personal_information_request"
        case "discrimination": "discrimination"
        case "unsafe_content": "unsafe_job_conditions"
        default: "other_urgent_concern"
        }
    }
}

private extension ReportTarget {
    var userID: UUID? { if case let .user(id) = self { id } else { nil } }
    var jobID: UUID? { if case let .job(id) = self { id } else { nil } }
    var messageID: UUID? { if case let .message(id) = self { id } else { nil } }
    var reviewID: UUID? { if case let .review(id) = self { id } else { nil } }
}
