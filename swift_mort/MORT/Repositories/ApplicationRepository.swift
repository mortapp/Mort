import Foundation
import Supabase

protocol ApplicationRepositoryProtocol: Sendable {
    func application(id: UUID) async throws -> MortApplication?
    func listMine() async throws -> [MortApplication]
    func listForMyJobs() async throws -> [MortApplication]
    func eligibility(jobID: UUID) async throws -> ApplicationEligibility
    func apply(jobID: UUID, note: String?, availabilityConfirmed: Bool, portfolioIDs: [UUID]) async throws -> MortApplication
    func updateStatus(applicationID: UUID, action: String) async throws -> MortApplication
    func statusEvents(applicationID: UUID) async throws -> [ApplicationStatusEvent]
    func proofs(applicationID: UUID) async throws -> [ProofUpload]
    func reviewProof(proofID: UUID, action: String, note: String?) async throws -> ProofUpload
}

final class ApplicationRepository: SupabaseRepository, ApplicationRepositoryProtocol {
    private static let select = "*,jobs(*),teen:profiles!applications_teen_id_fkey(id,display_name,username,verification_status,avatar_path)"

    func application(id: UUID) async throws -> MortApplication? {
        try await translated {
            let rows: [MortApplication] = try await client.from("applications").select(Self.select).eq("id", value: id).limit(1).execute().value
            return rows.first
        }
    }

    func listMine() async throws -> [MortApplication] {
        try await translated {
            let id = try await currentUserID()
            return try await client.from("applications").select(Self.select)
                .or("teen_id.eq.\(id.uuidString),guardian_id.eq.\(id.uuidString)")
                .order("created_at", ascending: false).execute().value
        }
    }

    func listForMyJobs() async throws -> [MortApplication] {
        try await translated {
            try await client.from("applications")
                .select("*,jobs!inner(*),teen:profiles!applications_teen_id_fkey(id,display_name,username,verification_status,avatar_path)")
                .eq("jobs.poster_id", value: try await currentUserID())
                .order("created_at", ascending: false).execute().value
        }
    }

    func eligibility(jobID: UUID) async throws -> ApplicationEligibility {
        struct Params: Encodable { let p_job_id: UUID }
        return try await translated {
            try await client.rpc("get_job_application_eligibility", params: Params(p_job_id: jobID)).execute().value
        }
    }

    func apply(jobID: UUID, note: String?, availabilityConfirmed: Bool, portfolioIDs: [UUID] = []) async throws -> MortApplication {
        struct Params: Encodable {
            let p_job_id: UUID
            let p_note: String?
            let p_availability_confirmed: Bool
            let p_portfolio_ids: [UUID]
        }
        return try await translated {
            let result: ApplicationRPCResult = try await client.rpc("submit_job_application", params: Params(
                p_job_id: jobID,
                p_note: note?.nilIfBlank,
                p_availability_confirmed: availabilityConfirmed,
                p_portfolio_ids: portfolioIDs
            )).execute().value
            return try result.requiredApplication()
        }
    }

    func updateStatus(applicationID: UUID, action: String) async throws -> MortApplication {
        struct Params: Encodable { let p_application_id: UUID; let p_action: String }
        return try await translated {
            let result: ApplicationRPCResult = try await client.rpc("update_application_status_v2", params: Params(
                p_application_id: applicationID,
                p_action: action
            )).execute().value
            return try result.requiredApplication()
        }
    }

    func statusEvents(applicationID: UUID) async throws -> [ApplicationStatusEvent] {
        try await translated {
            try await client.from("application_status_events").select()
                .eq("application_id", value: applicationID).order("created_at").execute().value
        }
    }

    func proofs(applicationID: UUID) async throws -> [ProofUpload] {
        try await translated {
            try await client.from("proof_uploads").select()
                .eq("application_id", value: applicationID)
                .order("created_at", ascending: false)
                .execute().value
        }
    }

    func reviewProof(proofID: UUID, action: String, note: String?) async throws -> ProofUpload {
        struct Params: Encodable {
            let p_proof_id: UUID
            let p_action: String
            let p_note: String?
        }
        return try await translated {
            let result: ProofReviewRPCResult = try await client.rpc(
                "review_application_proof",
                params: Params(p_proof_id: proofID, p_action: action, p_note: note?.nilIfBlank)
            ).execute().value
            return try result.requiredProof()
        }
    }
}
