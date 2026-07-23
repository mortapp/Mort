import Foundation
import Supabase

protocol JobRepositoryProtocol: Sendable {
    func listOpen(filters: JobSearchFilters, page: Int, pageSize: Int) async throws -> [Job]
    func listMine() async throws -> [Job]
    func job(id: UUID) async throws -> Job?
    func saveDraft(_ draft: JobDraft) async throws -> Job
    func publish(_ draft: JobDraft) async throws -> Job
    func manage(id: UUID, action: String) async throws -> Job?
    func statusEvents(jobID: UUID) async throws -> [JobStatusEvent]
}

final class JobRepository: SupabaseRepository, JobRepositoryProtocol {
    private static let select = "*,profiles:poster_id(id,display_name,username,verification_status,avatar_path)"

    func listOpen(filters: JobSearchFilters = .init(), page: Int = 0, pageSize: Int = 30) async throws -> [Job] {
        try await translated {
            var query = client.from("jobs").select(Self.select)
                .eq("status", value: "open")
                .eq("applications_open", value: true)
                .eq("is_test", value: false)

            if let category = filters.category?.nilIfBlank, category != "All" { query = query.eq("category", value: category) }
            if let value = filters.minimumPayCents { query = query.gte("pay_amount_cents", value: value) }
            if let value = filters.paymentType { query = query.eq("payment_type", value: value) }
            if let value = filters.scheduleType { query = query.eq("schedule_type", value: value) }
            if let value = filters.verificationRequirement { query = query.eq("verification_requirement", value: value) }
            if let value = filters.requiresGuardianApproval { query = query.eq("requires_guardian_approval", value: value) }
            if let value = filters.workEnvironment { query = query.eq("work_environment", value: value) }

            let keyword = filters.keyword.replacingOccurrences(of: #"[^A-Za-z0-9 ]"#, with: " ", options: .regularExpression).trimmed
            if !keyword.isEmpty {
                query = query.or("title.ilike.%\(keyword)%,summary.ilike.%\(keyword)%,description.ilike.%\(keyword)%")
            }

            let from = page * pageSize
            let to = from + pageSize - 1
            switch filters.sort {
            case .newest:
                return try await query.order("created_at", ascending: false).range(from: from, to: to).execute().value
            case .highestPay:
                return try await query.order("pay_amount_cents", ascending: false).range(from: from, to: to).execute().value
            case .soonestStart:
                return try await query.order("starts_at", ascending: true, nullsFirst: false).range(from: from, to: to).execute().value
            }
        }
    }

    func listMine() async throws -> [Job] {
        try await translated {
            try await client.from("jobs").select(Self.select)
                .eq("poster_id", value: try await currentUserID())
                .order("updated_at", ascending: false)
                .execute().value
        }
    }

    func job(id: UUID) async throws -> Job? {
        try await translated {
            let rows: [Job] = try await client.from("jobs").select(Self.select).eq("id", value: id).limit(1).execute().value
            return rows.first
        }
    }

    func saveDraft(_ draft: JobDraft) async throws -> Job { try await save(draft, publish: false) }
    func publish(_ draft: JobDraft) async throws -> Job { try await save(draft, publish: true) }

    private func save(_ draft: JobDraft, publish: Bool) async throws -> Job {
        struct Params: Encodable {
            let p_job_id: UUID?
            let p_client_request_id: UUID
            let p_payload: JobPayload
            let p_publish: Bool
        }
        return try await translated {
            let result: JobRPCResult = try await client.rpc("save_job_draft_or_publish", params: Params(
                p_job_id: draft.id,
                p_client_request_id: draft.clientRequestID,
                p_payload: draft.payload,
                p_publish: publish
            )).execute().value
            return try result.requiredJob()
        }
    }

    func manage(id: UUID, action: String) async throws -> Job? {
        struct Params: Encodable { let p_job_id: UUID; let p_action: String }
        return try await translated {
            let result: JobRPCResult = try await client.rpc("manage_job", params: Params(p_job_id: id, p_action: action)).execute().value
            guard result.ok else { throw MortError.backend(code: result.code ?? "unknown_permission_failure", message: result.message) }
            return result.job
        }
    }

    func statusEvents(jobID: UUID) async throws -> [JobStatusEvent] {
        try await translated {
            try await client.from("job_status_events").select().eq("job_id", value: jobID).order("created_at").execute().value
        }
    }
}

protocol SavedJobRepositoryProtocol: Sendable {
    func list() async throws -> [Job]
    func isSaved(jobID: UUID) async throws -> Bool
    func save(jobID: UUID) async throws
    func remove(jobID: UUID) async throws
}

final class SavedJobRepository: SupabaseRepository, SavedJobRepositoryProtocol {
    func list() async throws -> [Job] {
        try await translated {
            let rows: [SavedJobEnvelope] = try await client.from("saved_jobs")
                .select("created_at,jobs(*,profiles:poster_id(id,display_name,username,verification_status,avatar_path))")
                .eq("user_id", value: try await currentUserID())
                .order("created_at", ascending: false)
                .execute().value
            return rows.compactMap(\.job)
        }
    }

    func isSaved(jobID: UUID) async throws -> Bool {
        struct IDRow: Decodable { let job_id: UUID }
        return try await translated {
            let rows: [IDRow] = try await client.from("saved_jobs").select("job_id")
                .eq("user_id", value: try await currentUserID()).eq("job_id", value: jobID).limit(1).execute().value
            return !rows.isEmpty
        }
    }

    func save(jobID: UUID) async throws {
        struct Input: Encodable { let user_id: UUID; let job_id: UUID }
        try await translated {
            try await client.from("saved_jobs").upsert(Input(user_id: try await currentUserID(), job_id: jobID)).execute()
        }
    }

    func remove(jobID: UUID) async throws {
        try await translated {
            try await client.from("saved_jobs").delete()
                .eq("user_id", value: try await currentUserID()).eq("job_id", value: jobID).execute()
        }
    }
}

