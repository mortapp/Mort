//
//  LiveRepositories.swift
//  MORT iOS V8 — Services / Supabase-backed implementations
//
//  ============================================================
//  INTEGRATION TARGET — VS CODE VERIFIES EVERY RPC NAME
//  ============================================================
//  These implementations are complete native Swift. What VS Code must confirm
//  is that each Postgres function / table name below matches the REAL MORT
//  schema. Where MORT already has an equivalent, use the existing name rather
//  than creating a duplicate.
//
//  Every method forwards a backend decision. None of them computes money,
//  decides a payment outcome, or fabricates a receipt.
//

import Foundation

// MARK: - Auth

nonisolated final class LiveAuthService: AuthService {
    private let client: SupabaseClient
    private let profiles: LiveProfileRepository

    init(client: SupabaseClient) {
        self.client = client
        self.profiles = LiveProfileRepository(client: client)
    }

    func restoreSession() async throws -> MortUser? {
        guard let stored = await client.storedSession() else { return nil }
        // Validate with the backend; never trust a local token alone.
        do {
            _ = try await client.validAccessToken()
            return try await profiles.profile(userId: stored.userId)
        } catch MortError.unauthorized {
            await client.clearSession()
            return nil
        }
    }

    func signIn(email: String, password: String) async throws -> MortUser {
        let response: AuthTokenResponse = try await client.post(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            body: ["email": email, "password": password],
            authenticated: false
        )
        try await store(response)
        return try await profiles.profile(userId: response.user.id)
    }

    func signUp(email: String, password: String, role: MortRole) async throws -> MortUser {
        let response: AuthTokenResponse = try await client.post(
            path: "/auth/v1/signup",
            body: [
                "email": email,
                "password": password,
                // Role is recorded in user metadata; the backend is still the
                // authority that decides what a role may do.
                "data": ["role": role.rawValue],
            ],
            authenticated: false
        )
        try await store(response)
        return try await profiles.profile(userId: response.user.id)
    }

    /// INTEGRATION: requires the Sign in with Apple capability + entitlement.
    /// Flow: ASAuthorizationController -> identityToken -> Supabase
    /// `/auth/v1/token?grant_type=id_token`.
    func signInWithApple() async throws -> MortUser {
        let credential = try await AppleSignInCoordinator().requestCredential()
        let response: AuthTokenResponse = try await client.post(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: [
                "provider": "apple",
                "id_token": credential.identityToken,
                "nonce": credential.rawNonce,
            ],
            authenticated: false
        )
        try await store(response)
        return try await profiles.profile(userId: response.user.id)
    }

    /// INTEGRATION: Google OAuth via ASWebAuthenticationSession and the
    /// Supabase callback URL. Requires the custom URL scheme in Info.plist.
    func signInWithGoogle() async throws -> MortUser {
        throw MortError.notConfigured("Google sign-in")
    }

    func sendPasswordReset(email: String) async throws {
        let _: EmptyResponse = try await client.post(
            path: "/auth/v1/recover",
            body: ["email": email],
            authenticated: false
        )
    }

    func completeOnboarding(userId: String, draft: MortProfileDraft) async throws -> MortUser {
        try await profiles.updateProfile(userId: userId, draft: draft)
    }

    func signOut() async throws {
        let _: EmptyResponse? = try? await client.post(path: "/auth/v1/logout", body: [:])
        await client.clearSession()
    }

    func deleteAccount(userId: String) async throws {
        guard let stored = await client.storedSession(), stored.userId == userId else {
            throw MortError.forbidden
        }
        let response: HostedAccountDeletionResponseDTO = try await client.rpc(
            MortBackendContract.RPC.requestAccountDeletion,
            args: ["p_source": "in_app"]
        )
        guard response.ok else {
            if response.code == "recent_reauthentication_required" {
                throw MortError.rejected("Please sign in again before deleting your account.")
            }
            throw MortError.rejected(response.code ?? "Account deletion could not be requested.")
        }
        await client.clearSession()
    }

    private func store(_ response: AuthTokenResponse) async throws {
        await client.store(session: SupabaseSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            userId: response.user.id
        ))
    }
}

// MARK: - Profile

nonisolated final class LiveProfileRepository: ProfileRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func profile(userId: String) async throws -> MortUser {
        guard UUID(uuidString: userId) != nil else { throw MortError.notFound }

        if let stored = await client.storedSession(), stored.userId == userId {
            let rows: [HostedProfileDTO] = try await client.rpc(
                MortBackendContract.RPC.getMyProfile
            )
            guard let row = rows.first else { throw MortError.notFound }
            return row.toDomain()
        }

        // Public profile lookup stays explicitly field-limited. RLS remains
        // authoritative for whether the signed-in viewer may read the row.
        let rows: [HostedProfileDTO] = try await client.get(
            path: "/rest/v1/profiles",
            query: [
                URLQueryItem(name: "id", value: "eq.\(userId)"),
                URLQueryItem(
                    name: "select",
                    value: "id,username,display_name,role,city,state,approximate_area,verification_status,guardian_setup_status,created_at,bio"
                ),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let row = rows.first else { throw MortError.notFound }
        return row.toDomain()
    }

    func updateProfile(userId: String, draft: MortProfileDraft) async throws -> MortUser {
        guard let stored = await client.storedSession(), stored.userId == userId else {
            throw MortError.forbidden
        }

        let patch: [String: any Sendable] = [
            "display_name": draft.displayName,
            "approximate_area": draft.area,
            "preferred_job_categories": draft.categories,
            "bio": draft.bio,
        ]
        let response: HostedProfileUpdateResponseDTO = try await client.rpc(
            MortBackendContract.RPC.updateMyProfile,
            args: [
                "p_patch": patch,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok, let profile = response.profile else {
            throw MortError.rejected(response.code ?? "Profile update was not accepted.")
        }
        return profile.toDomain()
    }

    func reviews(userId: String) async throws -> [MortReview] {
        guard UUID(uuidString: userId) != nil else { throw MortError.notFound }
        let rows: [HostedReviewDTO] = try await client.get(
            path: "/rest/v1/reviews",
            query: [
                URLQueryItem(name: "subject_id", value: "eq.\(userId)"),
                URLQueryItem(name: "moderation_status", value: "eq.approved"),
                URLQueryItem(
                    name: "select",
                    value: "id,reviewer_id,subject_id,rating,body,moderation_status,created_at,reviewer:profiles!reviews_reviewer_id_fkey(username,display_name),job:jobs!reviews_job_id_fkey(title)"
                ),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "100"),
            ]
        )
        return rows.map { $0.toDomain() }
    }
}

// MARK: - Jobs

nonisolated final class LiveJobRepository: JobRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func discover(query: String?, category: String?, cursor: String?) async throws -> (jobs: [MortJob], nextCursor: String?) {
        var args: [String: any Sendable] = [
            "p_keyword": query ?? "",
            "p_sort": "newest",
            "p_limit": 20,
        ]
        if let category, !category.isEmpty {
            args["p_category"] = category
        }
        if let cursor {
            guard let decoded = HostedJobCursorDTO(opaqueValue: cursor) else {
                throw MortError.rejected("That job-feed page token is no longer valid. Refresh the list.")
            }
            args["p_cursor_value"] = decoded.value
            args["p_cursor_id"] = decoded.id
        }

        let page: HostedJobFeedPageDTO = try await client.rpc(
            MortBackendContract.RPC.discoverJobs,
            args: args
        )
        guard page.ok else {
            throw MortError.rejected(page.code ?? "The job feed is temporarily unavailable.")
        }

        let jobs = try page.items.map { try $0.toDomain() }
        return (jobs, page.hasMore ? page.nextCursor?.opaqueValue : nil)
    }

    func job(id: String) async throws -> MortJob {
        let row = try await jobRecord(id: id)
        let profile = try? await profileSummary(id: row.posterId)
        return try row.toDomain(
            posterHandle: profile?.handle ?? "",
            posterDisplayName: profile?.displayName ?? "MORT member"
        )
    }

    func myJobs(role: MortRole) async throws -> [MortJob] {
        guard let stored = await client.storedSession() else {
            throw MortError.unauthorized
        }

        let rows: [HostedJobRecordDTO]
        switch role {
        case .adult:
            rows = try await client.get(
                path: "/rest/v1/jobs",
                query: [
                    URLQueryItem(name: "poster_id", value: "eq.\(stored.userId)"),
                    URLQueryItem(name: "select", value: Self.jobSelect),
                    URLQueryItem(name: "order", value: "updated_at.desc"),
                    URLQueryItem(name: "limit", value: "100"),
                ]
            )
        case .teen:
            let applications: [HostedExecutionApplicationWithJobDTO] = try await client.get(
                path: "/rest/v1/applications",
                query: [
                    URLQueryItem(name: "teen_id", value: "eq.\(stored.userId)"),
                    URLQueryItem(
                        name: "status",
                        value: "in.(submitted,guardian_pending,adult_review,viewed,accepted,in_progress,proof_submitted,completion_pending_release,completed)"
                    ),
                    URLQueryItem(name: "select", value: "job_id"),
                    URLQueryItem(name: "order", value: "updated_at.desc"),
                    URLQueryItem(name: "limit", value: "100"),
                ]
            )
            let ids = Array(Set(applications.map(\.jobId)))
            guard !ids.isEmpty else { return [] }
            rows = try await client.get(
                path: "/rest/v1/jobs",
                query: [
                    URLQueryItem(name: "id", value: "in.(\(ids.joined(separator: ",")))"),
                    URLQueryItem(name: "select", value: Self.jobSelect),
                    URLQueryItem(name: "order", value: "updated_at.desc"),
                ]
            )
        case .guardian:
            return []
        }

        let posterIds = Array(Set(rows.map(\.posterId)))
        let profiles = try await profileSummaries(ids: posterIds)
        return try rows.map { row in
            let profile = profiles[row.posterId]
            return try row.toDomain(
                posterHandle: profile?.handle ?? "",
                posterDisplayName: profile?.displayName ?? "MORT member"
            )
        }
    }

    func createJob(
        title: String,
        category: String,
        details: String,
        baseCents: Int64,
        scheduleText: String,
        requiresProof: Bool
    ) async throws -> MortJob {
        guard baseCents > 0 else {
            throw MortError.rejected("Enter a valid base pay amount.")
        }
        let profile = try await currentPostingProfile()
        let payload = try postingPayload(
            title: title,
            category: category,
            details: details,
            baseCents: baseCents,
            requiresProof: requiresProof,
            profile: profile
        )
        let response: HostedJobMutationResponseDTO = try await client.rpc(
            MortBackendContract.RPC.saveJob,
            args: [
                "p_client_request_id": UUID().uuidString.lowercased(),
                "p_payload": payload,
                "p_publish": true,
            ]
        )
        guard response.ok, let row = response.job else {
            throw MortError.rejected(response.code ?? "That job could not be published.")
        }
        let identity = profile.toDomain()
        return try row.toDomain(
            posterHandle: identity.handle,
            posterDisplayName: identity.displayName
        )
    }

    func updateJob(id: String, title: String, details: String, baseCents: Int64) async throws -> MortJob {
        guard UUID(uuidString: id) != nil else { throw MortError.notFound }
        guard baseCents > 0 else {
            throw MortError.rejected("Enter a valid base pay amount.")
        }
        let existing = try await jobRecord(id: id)
        let profile = try await currentPostingProfile()
        let payload = try postingPayload(
            title: title,
            category: existing.category,
            details: details,
            baseCents: baseCents,
            requiresProof: existing.proofExpected ?? false,
            profile: profile,
            existing: existing
        )
        let response: HostedJobMutationResponseDTO = try await client.rpc(
            MortBackendContract.RPC.saveJob,
            args: [
                "p_job_id": id,
                "p_client_request_id": UUID().uuidString.lowercased(),
                "p_payload": payload,
                "p_publish": existing.status != "draft",
            ]
        )
        guard response.ok, let row = response.job else {
            throw MortError.rejected(response.code ?? "That job could not be updated.")
        }
        let identity = profile.toDomain()
        return try row.toDomain(
            posterHandle: identity.handle,
            posterDisplayName: identity.displayName
        )
    }

    func cancelJob(id: String, reason: String) async throws {
        guard UUID(uuidString: id) != nil else { throw MortError.notFound }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else {
            throw MortError.rejected("Add a short cancellation reason before continuing.")
        }
        let response: HostedJobMutationResponseDTO = try await client.rpc(
            MortBackendContract.RPC.manageJob,
            args: [
                "p_job_id": id,
                "p_action": "cancel",
                "p_reason": trimmed,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "That job could not be cancelled.")
        }
    }

    func fairPayPolicy(category: String) async throws -> FairPayPolicy {
        // Fair Pay is enforced by the hosted funding-quote path. The database
        // does not expose a participant-safe per-category band endpoint yet,
        // so the app must not invent a local band.
        throw MortError.notConfigured("Fair Pay preview bands")
    }

    private static let jobSelect = "id,poster_id,title,summary,description,category,location_text,city,state,neighborhood,pay_amount_cents,status,starts_at,created_at,updated_at,proof_expected,schedule_type,applications_open"

    private func jobRecord(id: String) async throws -> HostedJobRecordDTO {
        guard UUID(uuidString: id) != nil else { throw MortError.notFound }
        let rows: [HostedJobRecordDTO] = try await client.get(
            path: "/rest/v1/jobs",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "select", value: Self.jobSelect),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let row = rows.first else { throw MortError.notFound }
        return row
    }

    private func currentPostingProfile() async throws -> HostedProfileDTO {
        let rows: [HostedProfileDTO] = try await client.rpc(
            MortBackendContract.RPC.getMyProfile
        )
        guard let profile = rows.first else { throw MortError.notFound }
        return profile
    }

    private func profileSummary(id: String) async throws -> MortUser {
        let rows: [HostedProfileDTO] = try await client.get(
            path: "/rest/v1/profiles",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "select", value: "id,username,display_name,role,city,state,approximate_area,verification_status,guardian_setup_status,created_at,bio"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let row = rows.first else { throw MortError.notFound }
        return row.toDomain()
    }

    private func profileSummaries(ids: [String]) async throws -> [String: MortUser] {
        guard !ids.isEmpty else { return [:] }
        let rows: [HostedProfileDTO] = try await client.get(
            path: "/rest/v1/profiles",
            query: [
                URLQueryItem(name: "id", value: "in.(\(ids.joined(separator: ",")))"),
                URLQueryItem(name: "select", value: "id,username,display_name,role,city,state,approximate_area,verification_status,guardian_setup_status,created_at,bio"),
            ]
        )
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.toDomain()) })
    }

    private func postingPayload(
        title: String,
        category: String,
        details: String,
        baseCents: Int64,
        requiresProof: Bool,
        profile: HostedProfileDTO,
        existing: HostedJobRecordDTO? = nil
    ) throws -> [String: any Sendable] {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTitle.count >= 5, cleanTitle.count <= 80 else {
            throw MortError.rejected("Job titles must be 5–80 characters.")
        }
        guard cleanDetails.count >= 20, cleanDetails.count <= 4000 else {
            throw MortError.rejected("Job details must be 20–4000 characters.")
        }
        guard let city = profile.city, !city.isEmpty,
              let state = profile.state, state.count == 2 else {
            throw MortError.rejected("Add your city and state to your profile before publishing a job.")
        }

        let summary = String(cleanDetails.prefix(240))
        let area = existing?.locationText
            ?? profile.approximateArea
            ?? "\(city), \(state)"

        return [
            "title": cleanTitle,
            "summary": summary,
            "description": cleanDetails,
            "category": category.lowercased(),
            "location_text": area,
            "city": existing?.city ?? city,
            "state": existing?.state ?? state,
            "pay_amount_cents": baseCents,
            "proof_expected": requiresProof,
            "schedule_type": existing?.scheduleType ?? "flexible",
            "payment_type": "fixed",
            "payment_method": "flexible",
            "payment_timing": "after_completion",
            "tip_allowed": true,
        ]
    }
}

nonisolated struct HostedExecutionApplicationWithJobDTO: Codable, Sendable {
    let jobId: String
}

nonisolated final class LiveApplicationRepository: ApplicationRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    private let selectShape = """
    id,job_id,teen_id,status,note,created_at,updated_at,    jobs:jobs!applications_job_id_fkey(title),    applicant:profiles!applications_teen_id_fkey(username,display_name)
    """

    func applications(jobId: String) async throws -> [MortApplication] {
        guard UUID(uuidString: jobId) != nil else { throw MortError.notFound }
        let rows: [HostedApplicationDTO] = try await client.get(
            path: "/rest/v1/applications",
            query: [
                URLQueryItem(name: "job_id", value: "eq.\(jobId)"),
                URLQueryItem(name: "select", value: selectShape),
                URLQueryItem(name: "order", value: "created_at.desc"),
            ]
        )
        return rows.map { $0.toDomain() }
    }

    func myApplications() async throws -> [MortApplication] {
        guard let stored = await client.storedSession() else {
            throw MortError.unauthorized
        }
        let rows: [HostedApplicationDTO] = try await client.get(
            path: "/rest/v1/applications",
            query: [
                URLQueryItem(name: "teen_id", value: "eq.\(stored.userId)"),
                URLQueryItem(name: "select", value: selectShape),
                URLQueryItem(name: "order", value: "created_at.desc"),
            ]
        )
        return rows.map { $0.toDomain() }
    }

    func apply(jobId: String, message: String) async throws -> MortApplication {
        guard UUID(uuidString: jobId) != nil else { throw MortError.notFound }
        let response: HostedApplicationSubmitResponseDTO = try await client.rpc(
            MortBackendContract.RPC.submitApplication,
            args: [
                "p_job_id": jobId,
                "p_note": message,
                "p_availability_confirmed": true,
                "p_portfolio_ids": [String](),
            ]
        )
        guard response.ok, let application = response.application else {
            throw MortError.rejected(
                response.message ?? response.code ?? "That application could not be submitted."
            )
        }
        return application.toDomain()
    }

    func withdraw(applicationId: String) async throws {
        try await transition(applicationId: applicationId, action: "withdrawn")
    }

    func selectApplicant(applicationId: String) async throws {
        try await transition(applicationId: applicationId, action: "accepted")
    }

    private func transition(applicationId: String, action: String) async throws {
        guard UUID(uuidString: applicationId) != nil else { throw MortError.notFound }
        let response: HostedApplicationTransitionResponseDTO = try await client.rpc(
            MortBackendContract.RPC.updateApplication,
            args: [
                "p_application_id": applicationId,
                "p_action": action,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(
                response.code ?? "That application status could not be changed."
            )
        }
    }
}

nonisolated final class LiveJobExecutionRepository: JobExecutionRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func startJob(jobId: String, pin: String, personMatchesProfile: Bool) async throws {
        guard personMatchesProfile else {
            throw MortError.rejected("Confirm the person matches the profile before starting.")
        }
        let application = try await executionApplication(jobId: jobId)
        let response: HostedStartConfirmationResponseDTO = try await client.rpc(
            MortBackendContract.RPC.confirmStartPin,
            args: [
                "p_application_id": application.id,
                "p_pin": pin,
                "p_person_matches_profile": true,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "The start code was not accepted.")
        }
    }

    func startPin(jobId: String) async throws -> String {
        let application = try await executionApplication(jobId: jobId)
        let response: HostedStartPinResponseDTO = try await client.rpc(
            MortBackendContract.RPC.generateStartPin,
            args: [
                "p_application_id": application.id,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok, let pin = response.startPin, pin.count == 6 else {
            throw MortError.rejected(response.code ?? "A start code could not be created.")
        }
        return pin
    }

    func submitProof(jobId: String, note: String, attachment: JobProofAttachment) async throws {
        guard attachment.contentType == "image/jpeg" else {
            throw MortError.rejected("Job proof must be a JPEG image.")
        }
        guard !attachment.data.isEmpty, attachment.data.count <= 10 * 1024 * 1024 else {
            throw MortError.rejected("Job proof must be 10 MB or smaller.")
        }
        guard let stored = await client.storedSession() else {
            throw MortError.unauthorized
        }

        let application = try await executionApplication(jobId: jobId)
        guard application.status == "in_progress" else {
            throw MortError.rejected("Proof can only be submitted while the job is in progress.")
        }

        let proofId = UUID().uuidString.lowercased()
        let storagePath = "\(stored.userId)/\(proofId).jpg"
        try await client.upload(
            bucket: "proof-uploads",
            path: storagePath,
            data: attachment.data,
            contentType: attachment.contentType
        )

        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.submitApplicationProof,
            args: [
                "p_proof_id": proofId,
                "p_application_id": application.id,
                "p_storage_path": storagePath,
                "p_note": note.trimmingCharacters(in: .whitespacesAndNewlines),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "MORT could not attach that proof to the job.")
        }
    }

    func markComplete(jobId: String) async throws {
        let application = try await executionApplication(jobId: jobId)
        let status: HostedExecutionStatusDTO = try await client.rpc(
            MortBackendContract.RPC.executionStatus,
            args: ["p_application_id": application.id]
        )
        guard
            status.ok,
            status.state == "in_progress",
            let contractId = status.contractId,
            UUID(uuidString: contractId) != nil
        else {
            throw MortError.rejected(
                status.code ?? "This job is not in a state where completion can be submitted."
            )
        }

        let jobs: [HostedExecutionJobContextDTO] = try await client.get(
            path: "/rest/v1/jobs",
            query: [
                URLQueryItem(name: "id", value: "eq.\(jobId)"),
                URLQueryItem(name: "select", value: "id,location_type"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let job = jobs.first else { throw MortError.notFound }
        let locationType = job.locationType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmedLocationType = (locationType?.isEmpty == false)
            ? locationType!
            : "unspecified"

        // The "I've finished the work" action is the worker's explicit
        // approved-scope confirmation. Empty checklist means no structured
        // checklist was supplied; it never invents completed task facts.
        var completionArgs: [String: any Sendable] = [
            "p_contract_id": contractId,
            "p_task_checklist": [String](),
            "p_completion_timestamp": Date().ISO8601Format(),
            "p_location_type_confirmation": confirmedLocationType,
            "p_approved_scope_confirmation": true,
            "p_witness_notes": SupabaseJSONNull(),
            "p_statement": SupabaseJSONNull(),
        ]
        if let startedAt = status.startedAt {
            completionArgs["p_start_timestamp"] = startedAt.ISO8601Format()
        } else {
            completionArgs["p_start_timestamp"] = SupabaseJSONNull()
        }

        let response: HostedCompletionAssertionResponseDTO = try await client.rpc(
            MortBackendContract.RPC.submitCompletionAssertion,
            args: completionArgs
        )
        guard response.ok, response.assertionId != nil else {
            throw MortError.rejected(
                response.code ?? "MORT could not record the completion assertion."
            )
        }
    }

    func confirmCompletion(jobId: String) async throws -> CompletionAcknowledgement {
        let application = try await executionApplication(jobId: jobId)
        let status: HostedExecutionStatusDTO = try await client.rpc(
            MortBackendContract.RPC.executionStatus,
            args: ["p_application_id": application.id]
        )
        guard
            status.ok,
            let contractId = status.contractId,
            UUID(uuidString: contractId) != nil
        else {
            throw MortError.rejected(
                status.code ?? "MORT could not resolve this job's completion contract."
            )
        }

        let response: HostedAdultCompletionResponseDTO = try await client.rpc(
            MortBackendContract.RPC.respondCompletion,
            args: [
                "p_contract_id": contractId,
                "p_acknowledged": true,
                "p_statement": SupabaseJSONNull(),
            ]
        )
        return try response.toDomain()
    }

    func openDispute(jobId: String, category: String, detail: String) async throws {
        throw MortError.notConfigured("Payment dispute opening")
    }

    func settlement(jobId: String) async throws -> SettlementResult {
        guard UUID(uuidString: jobId) != nil else { throw MortError.notFound }
        let contracts: [HostedJobContractDTO] = try await client.get(
            path: "/rest/v1/job_contracts",
            query: [
                URLQueryItem(name: "job_id", value: "eq.\(jobId)"),
                URLQueryItem(name: "select", value: "id,job_id,teen_id,adult_id,status,active_version_id"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let contract = contracts.first else {
            throw MortError.rejected("We couldn't find this job's settlement contract.")
        }
        let dto: HostedJobSettlementDTO? = try await client.rpc(
            MortBackendContract.RPC.jobSettlement,
            args: ["p_contract_id": contract.id]
        )
        guard let dto else {
            throw MortError.rejected("Settlement has not been finalized yet.")
        }
        return try dto.toDomain()
    }

    private func executionApplication(jobId: String) async throws -> HostedExecutionApplicationRefDTO {
        guard UUID(uuidString: jobId) != nil else { throw MortError.notFound }
        let rows: [HostedExecutionApplicationRefDTO] = try await client.get(
            path: "/rest/v1/applications",
            query: [
                URLQueryItem(name: "job_id", value: "eq.\(jobId)"),
                URLQueryItem(
                    name: "status",
                    value: "in.(accepted,in_progress,proof_submitted,completion_pending_release)"
                ),
                URLQueryItem(name: "select", value: "id,status,updated_at"),
                URLQueryItem(name: "order", value: "updated_at.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let application = rows.first else {
            throw MortError.rejected("This job is not ready for the start handshake.")
        }
        return application
    }
}

// MARK: - Payment OS

nonisolated actor LivePaymentRepository: PaymentRepository {
    private struct FundingSession: Sendable {
        let quote: PaymentQuote
        let contractId: String
        let quoteId: String
        var providerPaymentIntentId: String?
    }

    private let client: SupabaseClient
    private let sheet: any ProviderPaymentSheet
    private var sessions: [String: FundingSession] = [:]

    init(client: SupabaseClient, sheet: any ProviderPaymentSheet) {
        self.client = client
        self.sheet = sheet
    }

    func fundingQuote(jobId: String) async throws -> PaymentQuote {
        let contract = try await contractForJob(jobId, activeOnly: true)
        guard contract.status == "active" else {
            throw MortError.rejected("This job is not ready to be funded.")
        }

        let requestId = UUID().uuidString.lowercased()
        let response: HostedFundingQuoteResponseDTO = try await client.function(
            MortBackendContract.EdgeFunction.fundingQuote,
            body: [
                "contract_id": contract.id,
                "request_id": requestId,
            ]
        )

        guard
            response.ok,
            let quoteId = response.quoteId,
            UUID(uuidString: quoteId) != nil,
            let contractId = response.contractId,
            contractId == contract.id,
            let base = response.basePayCents, base > 0,
            let fee = response.serviceFeeCents, fee >= 0,
            let total = response.authoritativeTotalCents, total == base + fee,
            let expiresAt = response.expiresAt,
            response.state == "ACTIVE"
        else {
            if response.state == "EXPIRED" {
                throw MortError.rejected("That funding amount expired. Refresh it before paying.")
            }
            throw MortError.serverUnavailable
        }

        let metadata = try await paymentMetadata(contract: contract)
        let quote = PaymentQuote(
            jobId: jobId,
            jobTitle: metadata.job.title,
            workerHandle: metadata.worker.safeDisplayHandle,
            orderNumber: nil,
            baseCents: base,
            feeCents: fee,
            totalCents: total,
            feeExplanation: "MORT's service fee for this funding quote is \(Money(cents: fee).formatted). It's added on top of base pay and is not taken from the worker.",
            expiresAt: expiresAt,
            method: nil
        )
        sessions[jobId] = FundingSession(
            quote: quote,
            contractId: contractId,
            quoteId: quoteId,
            providerPaymentIntentId: nil
        )
        return quote
    }

    func fundingDisplay(jobId: String) async throws -> PaymentQuote? {
        sessions[jobId]?.quote
    }

    func beginFunding(jobId: String, methodId: String?, idempotencyKey: String) async throws -> PaymentState {
        guard var session = sessions[jobId] else {
            throw MortError.rejected("Refresh the funding amount before paying.")
        }
        guard !session.quote.isExpired else { return .quoteExpired }
        guard UUID(uuidString: idempotencyKey) != nil else {
            throw MortError.rejected("This payment attempt is no longer valid. Refresh and try again.")
        }

        let intent: HostedPaymentIntentResponseDTO = try await client.function(
            MortBackendContract.EdgeFunction.paymentIntent,
            body: [
                "quote_id": session.quoteId,
                "request_id": idempotencyKey.lowercased(),
                // PaymentSheet may collect a new method. Saving requires a
                // separate explicit-consent UX that iOS has not enabled yet.
                "save_payment_method": false,
            ]
        )

        guard
            intent.ok,
            let clientSecret = intent.paymentIntentClientSecret,
            let publishableKey = intent.publishableKey,
            let providerId = intent.providerPaymentIntentId,
            let responseBase = intent.basePayCents,
            let responseFee = intent.serviceFeeCents,
            let responseTotal = intent.totalAmountCents,
            responseBase == session.quote.baseCents,
            responseFee == session.quote.feeCents,
            responseTotal == session.quote.totalCents
        else {
            return .unknown
        }

        session.providerPaymentIntentId = providerId
        sessions[jobId] = session

        let outcome = await sheet.present(handle: PaymentIntentHandle(
            clientSecret: clientSecret,
            publishableKey: publishableKey,
            customerEphemeralKeySecret: intent.customerEphemeralKeySecret,
            customerId: intent.customerId,
            merchantDisplayName: "MORT",
            applePayMerchantId: nil
        ))

        // PaymentSheet is presentation state, never financial truth. Always
        // ask MORT after it dismisses, even when the SDK reports completion.
        let reconciled = try? await fundingStatus(jobId: jobId)

        switch outcome {
        case .completed:
            guard let reconciled else { return .unknown }
            // A provider completion can precede the signed webhook. Render a
            // pending state until the backend reaches SUCCEEDED.
            return reconciled.state == .processing ? .pending : reconciled.state

        case .canceled:
            if let reconciled,
               reconciled.state == .funded
                || reconciled.state == .processing
                || reconciled.state == .pending
                || reconciled.state == .requiresAction {
                return reconciled.state
            }
            return .cancelled

        case .failed(let reason):
            if let reconciled,
               reconciled.state != .ready
                && reconciled.state != .unknown {
                return reconciled.state
            }
            return reason == .networkInterrupted ? .failedNetwork : .unknown
        }
    }

    func fundingStatus(jobId: String) async throws -> (state: PaymentState, reason: PaymentFailureReason?) {
        if
            let providerId = sessions[jobId]?.providerPaymentIntentId,
            let attempt: HostedPaymentAttemptStateDTO = try await paymentAttempt(providerId: providerId)
        {
            return (attempt.paymentState, nil)
        }

        // Recovery path after app restart: the participant-visible payment
        // summary is keyed by the job contract and prevents blind re-charging.
        let contract = try await contractForJob(jobId, activeOnly: false)
        let summary: HostedJobPaymentSummaryDTO = try await client.rpc(
            MortBackendContract.RPC.jobPaymentSummary,
            args: ["p_contract_id": contract.id]
        )
        return (summary.paymentState, nil)
    }

    func paymentMethods() async throws -> [PaymentMethodRef] {
        // Saved-method display/collection is owned by Stripe PaymentSheet using
        // its short-lived Customer ephemeral key. MORT never receives PAN/CVV.
        []
    }

    func setDefaultMethod(id: String) async throws {
        throw MortError.notConfigured("Saved payment-method management")
    }

    func submitTip(jobId: String, tipCents: Int64, idempotencyKey: String) async throws -> PaymentState {
        guard tipCents > 0 else {
            throw MortError.rejected("Enter a valid tip amount.")
        }
        guard UUID(uuidString: idempotencyKey) != nil else {
            throw MortError.rejected("This tip attempt is no longer valid. Try again.")
        }

        let policy = try await tipConfig()
        guard tipCents >= policy.minimumCents, tipCents <= policy.maximumCents else {
            throw MortError.rejected("That tip is outside MORT's current allowed range.")
        }

        let contract = try await contractForJob(jobId, activeOnly: false)
        let settlement: HostedJobSettlementDTO? = try await client.rpc(
            MortBackendContract.RPC.jobSettlement,
            args: ["p_contract_id": contract.id]
        )
        guard let settlement else {
            throw MortError.rejected("This job must be settled before you can add a tip.")
        }

        let intent: HostedTipPaymentIntentResponseDTO = try await client.function(
            MortBackendContract.EdgeFunction.tipPaymentIntent,
            body: [
                "settlement_id": settlement.settlementId,
                "amount_cents": tipCents,
                "request_id": idempotencyKey.lowercased(),
            ]
        )

        guard
            intent.ok,
            let tipAttemptId = intent.tipAttemptId,
            UUID(uuidString: tipAttemptId) != nil,
            let clientSecret = intent.paymentIntentClientSecret,
            let publishableKey = intent.publishableKey,
            intent.amountCents == tipCents,
            intent.teenAmountCents == tipCents,
            intent.mortFeeCents == 0
        else {
            if let state = intent.normalizedState {
                return HostedPaymentStateMapper.normalized(state)
            }
            return .unknown
        }

        let outcome = await sheet.present(handle: PaymentIntentHandle(
            clientSecret: clientSecret,
            publishableKey: publishableKey,
            customerEphemeralKeySecret: nil,
            customerId: intent.customerId,
            merchantDisplayName: "MORT tip",
            applePayMerchantId: nil
        ))

        let reconciled: HostedTipAttemptStateDTO? = try? await client.rpc(
            MortBackendContract.RPC.tipAttemptState,
            args: ["p_tip_attempt_id": tipAttemptId]
        )
        let state = reconciled?.paymentState ?? .unknown

        switch outcome {
        case .completed:
            return state == .processing ? .pending : state
        case .canceled:
            if state == .funded || state == .processing || state == .pending || state == .requiresAction {
                return state
            }
            return .cancelled
        case .failed(let reason):
            if state != .unknown && state != .ready { return state }
            return reason == .networkInterrupted ? .failedNetwork : .unknown
        }
    }

    func feeConfig() async throws -> MortFeeConfig {
        let config: HostedFinancialPolicyConfigDTO = try await client.rpc(
            MortBackendContract.RPC.financialPolicyConfig
        )
        guard config.ok, let fee = config.serviceFee else {
            throw MortError.serverUnavailable
        }
        return fee.toDomain()
    }

    func tipConfig() async throws -> TipConfig {
        let config: HostedFinancialPolicyConfigDTO = try await client.rpc(
            MortBackendContract.RPC.financialPolicyConfig
        )
        guard config.ok, let tip = config.tip else {
            throw MortError.notConfigured("Tip policy")
        }
        return try tip.toDomain()
    }

    private func paymentAttempt(providerId: String) async throws -> HostedPaymentAttemptStateDTO? {
        let dto: HostedPaymentAttemptStateDTO? = try await client.rpc(
            MortBackendContract.RPC.paymentAttemptState,
            args: ["p_payment_intent_id": providerId]
        )
        return dto
    }

    private func contractForJob(_ jobId: String, activeOnly: Bool) async throws -> HostedJobContractDTO {
        guard UUID(uuidString: jobId) != nil else { throw MortError.notFound }
        var query = [
            URLQueryItem(name: "job_id", value: "eq.\(jobId)"),
            URLQueryItem(name: "select", value: "id,job_id,teen_id,adult_id,status,active_version_id"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        if activeOnly {
            query.insert(URLQueryItem(name: "status", value: "eq.active"), at: 1)
        }
        let rows: [HostedJobContractDTO] = try await client.get(
            path: "/rest/v1/job_contracts",
            query: query
        )
        guard let contract = rows.first else {
            throw MortError.rejected(
                activeOnly
                    ? "This job does not have an active funding contract yet."
                    : "We couldn't find this job's payment record."
            )
        }
        return contract
    }

    private func paymentMetadata(
        contract: HostedJobContractDTO
    ) async throws -> (job: HostedPaymentJobDTO, worker: HostedPaymentCounterpartyDTO) {
        let jobs: [HostedPaymentJobDTO] = try await client.get(
            path: "/rest/v1/jobs",
            query: [
                URLQueryItem(name: "id", value: "eq.\(contract.jobId)"),
                URLQueryItem(name: "select", value: "id,title"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let job = jobs.first, let teenId = contract.teenId else {
            throw MortError.notFound
        }

        let workers: [HostedPaymentCounterpartyDTO] = try await client.get(
            path: "/rest/v1/profiles",
            query: [
                URLQueryItem(name: "id", value: "eq.\(teenId)"),
                URLQueryItem(name: "select", value: "id,username,display_name"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let worker = workers.first else { throw MortError.notFound }
        return (job, worker)
    }
}

nonisolated final class LiveReceiptRepository: ReceiptRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func receipt(number: String) async throws -> Receipt {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { throw MortError.notFound }
        let dto: HostedFinancialDocumentDTO? = try await client.rpc(
            MortBackendContract.RPC.financialDocument,
            args: ["p_receipt_id": trimmed]
        )
        guard let dto else { throw MortError.notFound }
        return dto.toReceipt()
    }

    func receipts(cursor: String?) async throws -> (receipts: [Receipt], nextCursor: String?) {
        let page = try await financialPage(cursor: cursor, category: nil, search: nil, limit: 50)
        let next = page.items.count == 50
            ? page.items.last?.createdAt.ISO8601Format()
            : nil
        return (page.items.map { $0.toReceipt() }, next)
    }

    func receipt(jobId: String, type: ReceiptType) async throws -> Receipt? {
        guard UUID(uuidString: jobId) != nil else { throw MortError.notFound }

        let documentType: String?
        switch type {
        case .adultJobPayment: documentType = "ADULT_JOB_PAYMENT"
        case .teenEarnings: documentType = "TEEN_EARNINGS"
        case .lateTip: documentType = "TIP"
        case .fullRefund: documentType = "FULL_REFUND"
        case .partialRefund: documentType = "PARTIAL_REFUND"
        case .adjustment: documentType = "ADJUSTMENT"
        case .reversal: documentType = "REVERSAL"
        case .storePurchase: documentType = nil
        }
        guard let documentType else { return nil }

        let contracts: [HostedJobContractDTO] = try await client.get(
            path: "/rest/v1/job_contracts",
            query: [
                URLQueryItem(name: "job_id", value: "eq.\(jobId)"),
                URLQueryItem(name: "select", value: "id,job_id,teen_id,adult_id,status,active_version_id"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let contract = contracts.first else { return nil }

        let dto: HostedFinancialDocumentDTO? = try await client.rpc(
            MortBackendContract.RPC.jobFinancialDocument,
            args: [
                "p_contract_id": contract.id,
                "p_document_type": documentType,
            ]
        )
        return dto?.toReceipt()
    }

    private func financialPage(
        cursor: String?,
        category: String?,
        search: String?,
        limit: Int
    ) async throws -> HostedFinancialHistoryPageDTO {
        var args: [String: any Sendable] = [
            "p_limit": min(max(limit, 1), 100),
        ]
        if let cursor {
            guard ISO8601DateFormatter().date(from: cursor) != nil else {
                throw MortError.rejected("That receipt page token is no longer valid.")
            }
            args["p_cursor"] = cursor
        }
        if let category, !category.isEmpty { args["p_category"] = category }
        if let search, !search.isEmpty { args["p_search"] = search }
        return try await client.rpc(
            MortBackendContract.RPC.financialHistory,
            args: args
        )
    }
}

nonisolated final class LivePayoutRepository: PayoutRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func payoutStatus() async throws -> PayoutStatus {
        let dto: HostedStripePayoutStatusDTO = try await client.rpc(
            MortBackendContract.RPC.payoutStatus
        )
        return dto.toDomain()
    }

    func payoutHistory() async throws -> [PayoutStatus] {
        let dto: HostedStripePayoutStatusDTO = try await client.rpc(
            MortBackendContract.RPC.payoutStatus
        )
        guard dto.latestPayout != nil else { return [] }
        // The current participant-safe RPC deliberately exposes only the latest
        // provider payout. Return exactly that one known record rather than
        // manufacturing a historical list.
        return [dto.toDomain()]
    }

    func beginPayoutOnboarding() async throws -> URL {
        // Hosted onboarding requires approved HTTPS return/refresh origins.
        // Native universal-link routing is not configured in this target yet.
        throw MortError.notConfigured("Payout onboarding return link")
    }

    func refreshPayoutReadiness() async throws -> PayoutStage {
        let dto: HostedStripePayoutStatusDTO = try await client.function(
            MortBackendContract.EdgeFunction.connectedAccountStatus,
            body: [:]
        )
        return dto.stage
    }
}

nonisolated final class LiveHistoryRepository: HistoryRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func records(
        filter: HistoryFilter,
        year: Int?,
        query: String?,
        cursor: String?
    ) async throws -> (records: [HistoryRecord], nextCursor: String?) {
        if filter == .failed || filter == .disputed || filter == .jobs {
            // Failed attempts and disputes do not issue immutable financial
            // documents, while job lifecycle rows are a separate domain. The
            // hosted backend has no unified participant-safe cursor yet.
            return ([], nil)
        }

        var args: [String: any Sendable] = ["p_limit": 50]
        if let year { args["p_year"] = year }
        if let query {
            let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { args["p_search"] = clean }
        }
        if let category = Self.category(for: filter) {
            args["p_category"] = category
        }
        if let cursor {
            guard ISO8601DateFormatter().date(from: cursor) != nil else {
                throw MortError.rejected("That history page token is no longer valid.")
            }
            args["p_cursor"] = cursor
        }

        let page: HostedFinancialHistoryPageDTO = try await client.rpc(
            MortBackendContract.RPC.financialHistory,
            args: args
        )
        let next = page.items.count == 50
            ? page.items.last?.createdAt.ISO8601Format()
            : nil
        return (page.items.map { $0.toHistoryRecord() }, next)
    }

    func availableYears() async throws -> [Int] {
        var years = Set<Int>()
        var cursor: String?
        var pageCount = 0

        repeat {
            var args: [String: any Sendable] = ["p_limit": 100]
            if let cursor { args["p_cursor"] = cursor }
            let page: HostedFinancialHistoryPageDTO = try await client.rpc(
                MortBackendContract.RPC.financialHistory,
                args: args
            )
            for item in page.items {
                years.insert(Calendar(identifier: .gregorian).component(.year, from: item.createdAt))
            }
            cursor = page.items.count == 100
                ? page.items.last?.createdAt.ISO8601Format()
                : nil
            pageCount += 1
        } while cursor != nil && pageCount < 20

        if years.isEmpty {
            years.insert(Calendar(identifier: .gregorian).component(.year, from: Date()))
        }
        return years.sorted(by: >)
    }

    func startAnnualExport(year: Int) async throws {
        // No hosted export-file job currently exists. Keep this honest rather
        // than claiming a local reconstruction is an official export.
        throw MortError.notConfigured("Annual financial export")
    }

    func exportState(year: Int) async throws -> ExportState {
        throw MortError.notConfigured("Annual financial export")
    }

    func exportFile(year: Int) async throws -> URL {
        throw MortError.notConfigured("Annual financial export")
    }

    private static func category(for filter: HistoryFilter) -> String? {
        switch filter {
        case .all, .receipts:
            return nil
        case .payments:
            return "ADULT_JOB_PAYMENT"
        case .earnings:
            return "TEEN_EARNINGS"
        case .tips:
            return "TIP"
        case .refunds:
            return "REFUND"
        case .adjustments:
            return "ADJUSTMENT"
        case .failed, .disputed, .jobs:
            return nil
        }
    }
}

nonisolated final class LiveMessageRepository: MessageRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func conversations() async throws -> [MortConversation] {
        let page: HostedMessageThreadPageDTO = try await client.rpc(
            MortBackendContract.RPC.messageThreads,
            args: ["p_limit": 50]
        )

        let ids = page.items.compactMap(\.counterpartyId)
        var usernames: [String: String] = [:]
        if !ids.isEmpty {
            let rows: [HostedUsernameDTO] = try await client.get(
                path: "/rest/v1/profiles",
                query: [
                    URLQueryItem(name: "id", value: "in.(\(ids.joined(separator: ",")))"),
                    URLQueryItem(name: "select", value: "id,username"),
                ]
            )
            usernames = Dictionary(
                uniqueKeysWithValues: rows.compactMap { row in
                    guard let username = row.username else { return nil }
                    return (row.id, username)
                }
            )
        }

        return page.items.map { item in
            item.toDomain(username: item.counterpartyId.flatMap { usernames[$0] })
        }
    }

    func messages(
        conversationId: String,
        cursor: String?
    ) async throws -> (messages: [MortMessage], nextCursor: String?) {
        guard UUID(uuidString: conversationId) != nil else { throw MortError.notFound }
        guard let stored = await client.storedSession() else { throw MortError.unauthorized }

        var args: [String: any Sendable] = [
            "p_thread_id": conversationId,
            "p_limit": 40,
        ]
        if let cursor {
            guard let decoded = HostedThreadMessagesPageDTO.Cursor(opaqueValue: cursor) else {
                throw MortError.rejected("That message page token is no longer valid. Refresh the conversation.")
            }
            args["p_cursor_created_at"] = decoded.createdAt.ISO8601Format()
            args["p_cursor_id"] = decoded.id
        }

        let page: HostedThreadMessagesPageDTO = try await client.rpc(
            MortBackendContract.RPC.threadMessages,
            args: args
        )
        let summary = page.thread
        let counterpartyName = summary?.counterpartyDisplayName ?? "MORT participant"
        let counterpartyHandle = ""
        let rows = page.items.map {
            $0.toDomain(
                currentUserId: stored.userId,
                counterpartyHandle: counterpartyHandle,
                counterpartyDisplayName: counterpartyName
            )
        }
        return (rows, page.hasMore ? page.nextCursor?.opaqueValue : nil)
    }

    func send(conversationId: String, body: String) async throws -> MortMessage {
        guard UUID(uuidString: conversationId) != nil else { throw MortError.notFound }
        guard let stored = await client.storedSession() else { throw MortError.unauthorized }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MortError.rejected("Write a message before sending.")
        }

        let row: HostedMessageRowDTO = try await client.rpc(
            MortBackendContract.RPC.sendMessage,
            args: [
                "p_thread_id": conversationId,
                "p_body": trimmed,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        return row.toDomain(
            currentUserId: stored.userId,
            counterpartyHandle: "",
            counterpartyDisplayName: "MORT participant"
        )
    }

    func markRead(conversationId: String) async throws {
        guard UUID(uuidString: conversationId) != nil else { throw MortError.notFound }
        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.markThreadRead,
            args: ["p_thread_id": conversationId]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "The conversation could not be marked read.")
        }
    }

    func report(conversationId: String, category: SafetyReportCategory, detail: String) async throws {
        guard UUID(uuidString: conversationId) != nil else { throw MortError.notFound }
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else {
            throw MortError.rejected("Add a little more detail before submitting the safety report.")
        }

        let page: HostedThreadMessagesPageDTO = try await client.rpc(
            MortBackendContract.RPC.threadMessages,
            args: [
                "p_thread_id": conversationId,
                "p_limit": 1,
            ]
        )
        guard let thread = page.thread,
              thread.counterpartyId != nil || thread.jobId != nil else {
            throw MortError.rejected("MORT could not identify a reportable participant or job for this conversation.")
        }

        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.submitSafetyReport,
            args: [
                "p_target_user_id": Self.nullableJSON(thread.counterpartyId),
                "p_target_job_id": Self.nullableJSON(thread.jobId),
                "p_target_message_id": SupabaseJSONNull(),
                "p_target_review_id": SupabaseJSONNull(),
                "p_application_id": SupabaseJSONNull(),
                "p_category": Self.backendCategory(category),
                "p_severity": "moderate",
                "p_immediate_danger": false,
                "p_details": trimmed,
                "p_occurred_at": Date().ISO8601Format(),
                "p_location_type": SupabaseJSONNull(),
                "p_desired_outcome": "review_and_follow_up",
                "p_confidential_safety_feedback": false,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "MORT could not submit that safety report.")
        }
    }

    func block(handle: String) async throws {
        let clean = handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard !clean.isEmpty else { throw MortError.notFound }

        let rows: [HostedSafetyContactProfileDTO] = try await client.get(
            path: "/rest/v1/profiles",
            query: [
                URLQueryItem(name: "username", value: "eq.\(clean)"),
                URLQueryItem(name: "select", value: "id,username,display_name,role"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let target = rows.first else { throw MortError.notFound }
        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.blockUser,
            args: [
                "p_blocked_id": target.id,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "That MORT account could not be blocked.")
        }
    }

    private static func nullableJSON(_ value: String?) -> any Sendable {
        if let value { return value }
        return SupabaseJSONNull()
    }

    private static func backendCategory(_ category: SafetyReportCategory) -> String {
        switch category {
        case .unsafeBehavior: return "unsafe_job_conditions"
        case .harassment: return "harassment"
        case .paymentProblem: return "nonpayment"
        case .noShow: return "other_urgent_concern"
        case .unsafeLocation: return "unexpected_location"
        case .somethingElse: return "other_urgent_concern"
        }
    }
}

nonisolated final class LiveSafetyRepository: SafetyRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func activeCheckIn() async throws -> SafetyCheckIn? {
        let rows: [HostedActiveCheckInDTO] = try await client.rpc(
            MortBackendContract.RPC.activeCheckIns
        )
        return rows.first?.toDomain()
    }

    func confirmCheckIn(id: String) async throws {
        guard UUID(uuidString: id) != nil else { throw MortError.notFound }
        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.completeCheckIn,
            args: [
                "p_checkin_id": id,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "That safety check-in could not be confirmed.")
        }
    }

    func contacts() async throws -> [SafetyContact] {
        guard let stored = await client.storedSession() else {
            throw MortError.unauthorized
        }
        let rows: [HostedSafetyCircleMemberDTO] = try await client.rpc(
            MortBackendContract.RPC.safetyCircle
        )
        let active = rows.filter { $0.status == "active" }
        let otherIds = Array(Set(active.map {
            $0.teenId == stored.userId ? $0.contactId : $0.teenId
        }))
        guard !otherIds.isEmpty else { return [] }

        let profiles: [HostedSafetyContactProfileDTO] = try await client.get(
            path: "/rest/v1/profiles",
            query: [
                URLQueryItem(name: "id", value: "in.(\(otherIds.joined(separator: ",")))"),
                URLQueryItem(name: "select", value: "id,username,display_name,role"),
            ]
        )
        let byId = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return active.compactMap { row in
            let otherId = row.teenId == stored.userId ? row.contactId : row.teenId
            guard let profile = byId[otherId] else { return nil }
            return SafetyContact(
                id: row.id,
                displayName: profile.display,
                relationship: row.relationshipLabel,
                contactMask: profile.handleOrMask,
                isGuardian: profile.role == "guardian",
                isNotifiedOnJobs: row.receiveJobStatus
            )
        }
    }

    func shareJobStatus(jobId: String, enabled: Bool) async throws {
        // The hosted safety-circle permission is global per member, not
        // per-job. Do not silently turn a per-job UI switch into a broader
        // permission change.
        throw MortError.notConfigured("Per-job safety sharing")
    }

    func report(category: SafetyReportCategory, detail: String, jobId: String?) async throws {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else {
            throw MortError.rejected("Add a little more detail before submitting the safety report.")
        }
        if let jobId, UUID(uuidString: jobId) == nil { throw MortError.notFound }
        guard jobId != nil else {
            throw MortError.rejected("Choose the related job before submitting this safety report.")
        }

        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.submitSafetyReport,
            args: [
                "p_target_user_id": SupabaseJSONNull(),
                "p_target_job_id": jobId!,
                "p_target_message_id": SupabaseJSONNull(),
                "p_target_review_id": SupabaseJSONNull(),
                "p_application_id": SupabaseJSONNull(),
                "p_category": Self.backendCategory(category),
                "p_severity": "moderate",
                "p_immediate_danger": false,
                "p_details": trimmed,
                "p_occurred_at": Date().ISO8601Format(),
                "p_location_type": SupabaseJSONNull(),
                "p_desired_outcome": "review_and_follow_up",
                "p_confidential_safety_feedback": false,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "MORT could not submit that safety report.")
        }
    }

    func raiseEmergencyAlert(jobId: String?) async throws {
        // The hosted urgent Safety Ping creates a critical safety incident but
        // explicitly does NOT claim physical intervention was dispatched.
        guard let jobId, UUID(uuidString: jobId) != nil else {
            throw MortError.notConfigured("Urgent safety ping without an active job")
        }
        let response: HostedSafetyPingResponseDTO = try await client.rpc(
            MortBackendContract.RPC.createSafetyPing,
            args: [
                "p_status": "needs_help",
                "p_note": "Urgent safety help requested from the MORT iOS Safety Center.",
                "p_job_id": jobId,
                "p_immediate_danger": true,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "MORT could not send the urgent safety ping.")
        }
    }

    private static func backendCategory(_ category: SafetyReportCategory) -> String {
        switch category {
        case .unsafeBehavior: return "unsafe_job_conditions"
        case .harassment: return "harassment"
        case .paymentProblem: return "nonpayment"
        case .noShow: return "other_urgent_concern"
        case .unsafeLocation: return "unexpected_location"
        case .somethingElse: return "other_urgent_concern"
        }
    }

    func capabilityState() async -> SafetyCapabilityState {
        guard await client.storedSession() != nil else { return .unavailable }
        return .available
    }
}

nonisolated final class LiveSupportRepository: SupportRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func cases() async throws -> [SupportCase] {
        let rows: [HostedSupportTicketDTO] = try await client.rpc(
            MortBackendContract.RPC.listSupportTickets
        )
        return rows.map { $0.toDomain() }
    }

    func openCase(
        topicId: String,
        subject: String,
        detail: String,
        reference: String?
    ) async throws -> SupportCase {
        let response: HostedSupportCreateResponseDTO = try await client.rpc(
            MortBackendContract.RPC.createSupportTicket,
            args: [
                "p_subject": subject,
                "p_message": detail,
            ]
        )
        guard response.ok, let ticket = response.ticket else {
            throw MortError.rejected(response.code ?? "Support could not open that conversation.")
        }
        return ticket.toDomain()
    }

    func messages(caseId: String) async throws -> [MortMessage] {
        guard UUID(uuidString: caseId) != nil else { throw MortError.notFound }
        let thread: HostedSupportThreadDTO = try await client.rpc(
            MortBackendContract.RPC.supportThread,
            args: ["p_ticket_id": caseId]
        )
        guard thread.ok else {
            throw MortError.rejected(thread.code ?? "That support conversation is unavailable.")
        }
        return (thread.messages ?? []).map { $0.toDomain() }
    }

    func reply(caseId: String, body: String) async throws -> MortMessage {
        guard UUID(uuidString: caseId) != nil else { throw MortError.notFound }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MortError.rejected("Write a reply before sending.")
        }

        let response: HostedSupportReplyResponseDTO = try await client.rpc(
            MortBackendContract.RPC.postSupportTicketMessage,
            args: [
                "p_ticket_id": caseId,
                "p_message": trimmed,
                "p_client_request_id": UUID().uuidString.lowercased(),
            ]
        )
        guard response.ok, let message = response.message else {
            throw MortError.rejected(response.code ?? "That support reply could not be sent.")
        }
        return message.toDomain()
    }

    func requestHuman(caseId: String) async throws {
        guard UUID(uuidString: caseId) != nil else { throw MortError.notFound }
        let response: HostedMutationAckDTO = try await client.rpc(
            MortBackendContract.RPC.requestSupportHumanReview,
            args: ["p_ticket_id": caseId]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "Human review could not be requested.")
        }
    }
}

nonisolated final class LiveNotificationRepository: NotificationRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func notifications() async throws -> [MortNotification] {
        let rows: [HostedNotificationDTO] = try await client.get(
            path: "/rest/v1/notifications",
            query: [
                URLQueryItem(name: "select", value: "id,title,body,data,read_at,created_at"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "100"),
            ]
        )
        return rows.map { $0.toDomain() }
    }

    func markRead(id: String) async throws {
        guard UUID(uuidString: id) != nil else { throw MortError.notFound }
        let rows: [HostedNotificationDTO] = try await client.patch(
            path: "/rest/v1/notifications",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "read_at", value: "is.null"),
                URLQueryItem(name: "select", value: "id,title,body,data,read_at,created_at"),
            ],
            body: ["read_at": Date().ISO8601Format()]
        )
        // A zero-row update is valid when the notification was already read.
        if rows.isEmpty {
            let existing: [HostedNotificationDTO] = try await client.get(
                path: "/rest/v1/notifications",
                query: [
                    URLQueryItem(name: "id", value: "eq.\(id)"),
                    URLQueryItem(name: "select", value: "id,title,body,data,read_at,created_at"),
                    URLQueryItem(name: "limit", value: "1"),
                ]
            )
            guard existing.first != nil else { throw MortError.notFound }
        }
    }

    func markAllRead() async throws {
        let _: [HostedNotificationDTO] = try await client.patch(
            path: "/rest/v1/notifications",
            query: [
                URLQueryItem(name: "read_at", value: "is.null"),
                URLQueryItem(name: "select", value: "id,title,body,data,read_at,created_at"),
            ],
            body: ["read_at": Date().ISO8601Format()]
        )
    }

    func registerPushToken(_ token: String) async throws {
        // Hosted push registration currently requires an FCM registration
        // token even on iOS. This protocol receives the native APNs token, so
        // forwarding it would falsely register the wrong provider material.
        throw MortError.notConfigured("iOS push provider bridge")
    }
}

nonisolated final class LiveGuardianRepository: GuardianRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func linkedTeens() async throws -> [MortUser] {
        let links: [HostedGuardianConnectionDTO] = try await client.get(
            path: "/rest/v1/guardian_connections",
            query: [
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "select", value: "id,teen_id,guardian_id,status"),
                URLQueryItem(name: "order", value: "accepted_at.desc"),
            ]
        )
        let teenIds = Array(Set(links.map(\.teenId)))
        guard !teenIds.isEmpty else { return [] }

        let rows: [HostedProfileDTO] = try await client.get(
            path: "/rest/v1/profiles",
            query: [
                URLQueryItem(name: "id", value: "in.(\(teenIds.joined(separator: ",")))"),
                URLQueryItem(
                    name: "select",
                    value: "id,username,display_name,role,city,state,approximate_area,verification_status,guardian_setup_status,created_at,updated_at,bio"
                ),
            ]
        )
        let order = Dictionary(uniqueKeysWithValues: teenIds.enumerated().map { ($0.element, $0.offset) })
        return rows
            .sorted { order[$0.id, default: .max] < order[$1.id, default: .max] }
            .map { $0.toDomain() }
    }

    func teenSummary(teenId: String) async throws -> GuardianSummary {
        guard UUID(uuidString: teenId) != nil else { throw MortError.notFound }
        let dto: HostedGuardianTeenSummaryDTO? = try await client.rpc(
            MortBackendContract.RPC.guardianTeenSummary,
            args: ["p_teen_id": teenId]
        )
        guard let dto, dto.ok else { throw MortError.notFound }
        return dto.toDomain()
    }

    func inviteTeen(email: String) async throws {
        // Hosted invite creation is teen-initiated. A guardian cannot create a
        // link for a teen by email, so this legacy UI path fails closed.
        throw MortError.notConfigured("Guardian-initiated email invite")
    }

    func acceptLink(code: String) async throws {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            throw MortError.rejected("Enter the guardian link code from the teen account.")
        }
        let response: HostedGuardianLinkResponseDTO = try await client.rpc(
            MortBackendContract.RPC.acceptGuardianInvite,
            args: ["p_invite_code": trimmed]
        )
        guard response.ok else {
            throw MortError.rejected(
                response.message ?? response.code ?? "That guardian link code could not be accepted."
            )
        }
    }

    func unlink(teenId: String) async throws {
        guard UUID(uuidString: teenId) != nil else { throw MortError.notFound }
        let rows: [HostedGuardianConnectionDTO] = try await client.get(
            path: "/rest/v1/guardian_connections",
            query: [
                URLQueryItem(name: "teen_id", value: "eq.\(teenId)"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "select", value: "id,teen_id,guardian_id,status"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let link = rows.first else { throw MortError.notFound }
        let response: HostedGuardianLinkResponseDTO = try await client.rpc(
            MortBackendContract.RPC.unlinkGuardian,
            args: ["p_link_id": link.id]
        )
        guard response.ok else {
            throw MortError.rejected(response.code ?? "That Guardian Mode link could not be removed.")
        }
    }
}
