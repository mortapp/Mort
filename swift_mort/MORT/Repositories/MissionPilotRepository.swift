import Foundation
import Supabase

protocol MissionPilotRepositoryProtocol: Sendable {
    func dashboard() async throws -> MissionPilotDashboard
    func eligibility(action: String, jobID: UUID?) async throws -> ClosedPilotEligibility
    func submitEnrollment(organizationID: UUID, source: String) async throws -> MissionPilotActionResult
    func acknowledge(_ type: String) async throws -> MissionPilotActionResult
    func partnerAttestations() async throws -> PartnerAttestationsResponse
    func updateDiscreetMode(enabled: Bool, appLock: Bool, lockMinutes: Int, quickExit: String) async throws -> MissionPilotActionResult
    func configureSupportCircle(enabled: Bool) async throws -> MissionPilotActionResult
    func documentReadiness() async throws -> DocumentCollectionReadiness
    func documentCases() async throws -> [DocumentReviewCaseSummary]
    func resources() async throws -> [ResourceDirectoryEntry]
    func bookmarkResource(_ id: UUID) async throws
    func goals() async throws -> [IndependenceGoal]
    func createGoal(type: String, title: String, targetCents: Int?) async throws
    func saveFuturePlan(targetDate: Date?, education: String?, employment: String?, transportation: String?, savingsTargetCents: Int?) async throws
    func privateWorkSummary() async throws -> PrivateWorkSummary
}

final class MissionPilotRepository: SupabaseRepository, MissionPilotRepositoryProtocol {
    func dashboard() async throws -> MissionPilotDashboard {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_mission_pilot_dashboard").execute().value
        }
    }

    func eligibility(action: String, jobID: UUID?) async throws -> ClosedPilotEligibility {
        struct Params: Encodable { let p_action: String; let p_job_id: UUID? }
        return try await translated {
            _ = try await currentUserID()
            return try await client.rpc(
                "get_closed_pilot_eligibility",
                params: Params(p_action: action, p_job_id: jobID)
            ).execute().value
        }
    }

    func submitEnrollment(organizationID: UUID, source: String) async throws -> MissionPilotActionResult {
        struct Params: Encodable { let p_organization_id: UUID; let p_source_type: String }
        return try await action(
            "submit_pilot_enrollment_request",
            Params(p_organization_id: organizationID, p_source_type: source),
            "Pilot enrollment could not be submitted."
        )
    }

    func acknowledge(_ type: String) async throws -> MissionPilotActionResult {
        struct Params: Encodable { let p_acknowledgement_type: String }
        return try await action(
            "acknowledge_pilot_policy",
            Params(p_acknowledgement_type: type),
            "The pilot acknowledgement could not be saved."
        )
    }

    func partnerAttestations() async throws -> PartnerAttestationsResponse {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_my_partner_attestations").execute().value
        }
    }

    func updateDiscreetMode(enabled: Bool, appLock: Bool, lockMinutes: Int, quickExit: String) async throws -> MissionPilotActionResult {
        struct Params: Encodable {
            let p_enabled: Bool
            let p_app_lock_enabled: Bool
            let p_automatic_lock_minutes: Int
            let p_quick_exit_destination: String
        }
        return try await action(
            "update_discreet_mode",
            Params(
                p_enabled: enabled,
                p_app_lock_enabled: appLock,
                p_automatic_lock_minutes: lockMinutes,
                p_quick_exit_destination: quickExit
            ),
            "Discreet Mode could not be updated."
        )
    }

    func configureSupportCircle(enabled: Bool) async throws -> MissionPilotActionResult {
        struct Params: Encodable { let p_enabled: Bool }
        return try await action(
            "configure_support_circle",
            Params(p_enabled: enabled),
            "Support Circle could not be updated."
        )
    }

    func documentReadiness() async throws -> DocumentCollectionReadiness {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_document_collection_readiness").execute().value
        }
    }

    func documentCases() async throws -> [DocumentReviewCaseSummary] {
        try await translated {
            try await client.from("document_review_cases")
                .select("id,evidence_category,status,public_label,what_was_established,what_was_not_established,final_decision_at,expires_at")
                .order("created_at", ascending: false)
                .execute().value
        }
    }

    func resources() async throws -> [ResourceDirectoryEntry] {
        try await translated {
            try await client.from("resource_directory_entries")
                .select("id,organization_name,category,source_url,source_status,organization_verification_status,city,state,summary,emergency_limitations,availability_claimed")
                .order("organization_name")
                .execute().value
        }
    }

    func bookmarkResource(_ id: UUID) async throws {
        struct Input: Encodable { let user_id: UUID; let resource_id: UUID }
        try await translated {
            try await client.from("private_resource_bookmarks")
                .upsert(Input(user_id: try await currentUserID(), resource_id: id))
                .execute()
        }
    }

    func goals() async throws -> [IndependenceGoal] {
        try await translated {
            try await client.from("independence_goals")
                .select("id,goal_type,title,target_amount_cents,current_amount_cents,target_date,status")
                .order("created_at", ascending: false)
                .execute().value
        }
    }

    func createGoal(type: String, title: String, targetCents: Int?) async throws {
        struct Input: Encodable {
            let user_id: UUID
            let goal_type: String
            let title: String
            let target_amount_cents: Int?
        }
        try await translated {
            try await client.from("independence_goals").insert(Input(
                user_id: try await currentUserID(),
                goal_type: type,
                title: title.trimmed,
                target_amount_cents: targetCents
            )).execute()
        }
    }

    func saveFuturePlan(
        targetDate: Date?,
        education: String?,
        employment: String?,
        transportation: String?,
        savingsTargetCents: Int?
    ) async throws {
        struct Input: Encodable {
            let user_id: UUID
            let target_date: String?
            let education_plan: String?
            let employment_plan: String?
            let transportation_plan: String?
            let savings_target_cents: Int?
            let runaway_guidance_provided: Bool
        }
        try await translated {
            try await client.from("future_independence_plans").upsert(Input(
                user_id: try await currentUserID(),
                target_date: targetDate.map(DateOfBirthRules.isoDate),
                education_plan: education?.nilIfBlank,
                employment_plan: employment?.nilIfBlank,
                transportation_plan: transportation?.nilIfBlank,
                savings_target_cents: savingsTargetCents,
                runaway_guidance_provided: false
            )).execute()
        }
    }

    func privateWorkSummary() async throws -> PrivateWorkSummary {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_private_work_summary").execute().value
        }
    }

    private func action<Params: Encodable>(
        _ function: String,
        _ params: Params,
        _ defaultMessage: String
    ) async throws -> MissionPilotActionResult {
        try await translated {
            _ = try await currentUserID()
            let result: MissionPilotActionResult = try await client.rpc(function, params: params).execute().value
            guard result.ok else {
                throw MortError.backend(code: result.code ?? "mission_pilot_action_failed", message: result.message ?? defaultMessage)
            }
            return result
        }
    }
}
