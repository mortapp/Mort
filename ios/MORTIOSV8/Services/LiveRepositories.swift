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
        let response: HostedProfileMutationResponseDTO = try await client.rpc(
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
        // Review presentation still needs a participant-safe joined read shape
        // (reviewer username/display name + job title). Fail closed rather
        // than decoding the raw table into fields it does not contain.
        throw MortError.notConfigured("Profile reviews")
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
        let nextCursor = page.hasMore ? page.nextCursor?.opaqueValue : nil
        return (jobs, nextCursor)
    }

    func job(id: String) async throws -> MortJob {
        let rows: [JobDTO] = try await client.get(
            path: "/rest/v1/jobs",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "select", value: "*"),
            ]
        )
        guard let row = rows.first else { throw MortError.notFound }
        return row.toDomain()
    }

    func myJobs(role: MortRole) async throws -> [MortJob] {
        let rows: [JobDTO] = try await client.rpc("mort_my_jobs", args: ["p_role": role.rawValue])
        return rows.map { $0.toDomain() }
    }

    func createJob(
        title: String,
        category: String,
        details: String,
        baseCents: Int64,
        scheduleText: String,
        requiresProof: Bool
    ) async throws -> MortJob {
        // The backend re-validates Fair Pay here; a client-side green verdict
        // is never sufficient.
        let row: JobDTO = try await client.rpc("mort_create_job", args: [
            "p_title": title,
            "p_category": category,
            "p_details": details,
            "p_base_cents": baseCents,
            "p_schedule_text": scheduleText,
            "p_requires_proof": requiresProof,
        ])
        return row.toDomain()
    }

    func updateJob(id: String, title: String, details: String, baseCents: Int64) async throws -> MortJob {
        let row: JobDTO = try await client.rpc("mort_update_job", args: [
            "p_job_id": id,
            "p_title": title,
            "p_details": details,
            "p_base_cents": baseCents,
        ])
        return row.toDomain()
    }

    func cancelJob(id: String, reason: String) async throws {
        // Cancellation may trigger a refund; the backend owns that decision.
        let _: EmptyResponse = try await client.rpc("mort_cancel_job", args: [
            "p_job_id": id,
            "p_reason": reason,
        ])
    }

    func fairPayPolicy(category: String) async throws -> FairPayPolicy {
        // [POSSIBLE NEW BACKEND REQUIRED] if MORT has no per-category band
        // endpoint yet. Do NOT hardcode bands in the app.
        let dto: FairPayPolicyDTO = try await client.rpc("mort_fair_pay_policy", args: [
            "p_category": category,
        ])
        return dto.toDomain()
    }
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

    func startJob(jobId: String, pin: String) async throws {
        // The backend refuses to start a job that is not FUNDED.
        let _: EmptyResponse = try await client.rpc("mort_start_job", args: [
            "p_job_id": jobId,
            "p_pin": pin,
        ])
    }

    func startPin(jobId: String) async throws -> String {
        let dto: PinDTO = try await client.rpc("mort_job_start_pin", args: ["p_job_id": jobId])
        return dto.pin
    }

    func submitProof(jobId: String, note: String, attachmentNames: [String]) async throws {
        let _: EmptyResponse = try await client.rpc("mort_submit_proof", args: [
            "p_job_id": jobId,
            "p_note": note,
            "p_attachments": attachmentNames,
        ])
    }

    func markComplete(jobId: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_mark_complete", args: ["p_job_id": jobId])
    }

    func confirmCompletion(jobId: String) async throws -> SettlementResult {
        // AUTHORITATIVE SETTLEMENT. The returned numbers are the backend's
        // decision; the app only renders them.
        let dto: SettlementDTO = try await client.rpc("mort_confirm_completion", args: [
            "p_job_id": jobId,
        ])
        return dto.toDomain()
    }

    func openDispute(jobId: String, category: String, detail: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_open_dispute", args: [
            "p_job_id": jobId,
            "p_category": category,
            "p_detail": detail,
        ])
    }

    func settlement(jobId: String) async throws -> SettlementResult {
        let dto: SettlementDTO = try await client.rpc("mort_settlement", args: ["p_job_id": jobId])
        return dto.toDomain()
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
        // The hosted tip function requires an authoritative settlement_id.
        // There is not yet a participant-safe read contract that exposes that
        // id by job. Fail closed instead of guessing or touching private tables.
        throw MortError.notConfigured("Post-settlement tips")
    }

    func feeConfig() async throws -> MortFeeConfig {
        // The actual fee on a charge comes from the authoritative quote above.
        // Do not expose the reference constants as if they were hosted config.
        throw MortError.notConfigured("MORT fee configuration")
    }

    func tipConfig() async throws -> TipConfig {
        throw MortError.notConfigured("Tip policy")
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
        // Receipts are immutable, backend-issued documents.
        let dto: ReceiptDTO = try await client.rpc("mort_receipt", args: ["p_receipt_number": number])
        return dto.toDomain()
    }

    func receipts(cursor: String?) async throws -> (receipts: [Receipt], nextCursor: String?) {
        let page: ReceiptPageDTO = try await client.rpc("mort_receipts", args: [
            "p_cursor": cursor ?? "",
        ])
        return (page.receipts.map { $0.toDomain() }, page.nextCursor)
    }

    func receipt(jobId: String, type: ReceiptType) async throws -> Receipt? {
        let rows: [ReceiptDTO] = try await client.rpc("mort_job_receipts", args: [
            "p_job_id": jobId,
            "p_type": type.rawValue,
        ])
        return rows.first?.toDomain()
    }
}

nonisolated final class LivePayoutRepository: PayoutRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func payoutStatus() async throws -> PayoutStatus {
        let dto: PayoutDTO = try await client.rpc("mort_payout_status")
        return dto.toDomain()
    }

    func payoutHistory() async throws -> [PayoutStatus] {
        let rows: [PayoutDTO] = try await client.rpc("mort_payout_history")
        return rows.map { $0.toDomain() }
    }

    func beginPayoutOnboarding() async throws -> URL {
        // The backend creates the Connect onboarding link.
        let dto: OnboardingLinkDTO = try await client.rpc("mort_payout_onboarding_link")
        guard let url = URL(string: dto.url) else { throw MortError.unknown }
        return url
    }

    func refreshPayoutReadiness() async throws -> PayoutStage {
        // Readiness is ALWAYS re-read from the provider via the backend.
        let dto: PayoutStageDTO = try await client.rpc("mort_refresh_payout_readiness")
        return PayoutStage(rawValue: dto.stage) ?? .setupRequired
    }
}

// MARK: - History

nonisolated final class LiveHistoryRepository: HistoryRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func records(
        filter: HistoryFilter,
        year: Int?,
        query: String?,
        cursor: String?
    ) async throws -> (records: [HistoryRecord], nextCursor: String?) {
        let page: HistoryPageDTO = try await client.rpc("mort_history", args: [
            "p_filter": filter.rawValue,
            "p_year": year ?? 0,
            "p_query": query ?? "",
            "p_cursor": cursor ?? "",
        ])
        return (page.records.map { $0.toDomain() }, page.nextCursor)
    }

    func availableYears() async throws -> [Int] {
        let dto: YearsDTO = try await client.rpc("mort_history_years")
        return dto.years
    }

    func startAnnualExport(year: Int) async throws {
        let _: EmptyResponse = try await client.rpc("mort_start_annual_export", args: ["p_year": year])
    }

    func exportState(year: Int) async throws -> ExportState {
        let dto: ExportStateDTO = try await client.rpc("mort_export_state", args: ["p_year": year])
        return ExportState(rawValue: dto.state) ?? .ready
    }

    func exportFile(year: Int) async throws -> URL {
        // [DO NOT FAKE] If the backend has no file, this throws and the UI
        // stays in a failed/preparing state.
        let dto: ExportFileDTO = try await client.rpc("mort_export_file", args: ["p_year": year])
        guard let url = URL(string: dto.url) else { throw MortError.notFound }
        return url
    }
}

// MARK: - Messaging / Safety / Support / Notifications / Guardian

nonisolated final class LiveMessageRepository: MessageRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func conversations() async throws -> [MortConversation] {
        let rows: [ConversationDTO] = try await client.rpc("mort_conversations")
        return rows.map { $0.toDomain() }
    }

    func messages(conversationId: String, cursor: String?) async throws -> (messages: [MortMessage], nextCursor: String?) {
        let page: MessagePageDTO = try await client.rpc("mort_messages", args: [
            "p_conversation_id": conversationId,
            "p_cursor": cursor ?? "",
        ])
        return (page.messages.map { $0.toDomain() }, page.nextCursor)
    }

    func send(conversationId: String, body: String) async throws -> MortMessage {
        let row: MessageDTO = try await client.rpc("mort_send_message", args: [
            "p_conversation_id": conversationId,
            "p_body": body,
        ])
        return row.toDomain()
    }

    func markRead(conversationId: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_mark_conversation_read", args: [
            "p_conversation_id": conversationId,
        ])
    }

    func report(conversationId: String, category: SafetyReportCategory, detail: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_report_conversation", args: [
            "p_conversation_id": conversationId,
            "p_category": category.rawValue,
            "p_detail": detail,
        ])
    }

    func block(handle: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_block_user", args: ["p_handle": handle])
    }
}

nonisolated final class LiveSafetyRepository: SafetyRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func activeCheckIn() async throws -> SafetyCheckIn? {
        let rows: [CheckInDTO] = try await client.rpc("mort_active_check_in")
        return rows.first?.toDomain()
    }

    func confirmCheckIn(id: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_confirm_check_in", args: ["p_check_in_id": id])
    }

    func contacts() async throws -> [SafetyContact] {
        let rows: [SafetyContactDTO] = try await client.rpc("mort_safety_contacts")
        return rows.map { $0.toDomain() }
    }

    func shareJobStatus(jobId: String, enabled: Bool) async throws {
        let _: EmptyResponse = try await client.rpc("mort_share_job_status", args: [
            "p_job_id": jobId,
            "p_enabled": enabled,
        ])
    }

    func report(category: SafetyReportCategory, detail: String, jobId: String?) async throws {
        let _: EmptyResponse = try await client.rpc("mort_safety_report", args: [
            "p_category": category.rawValue,
            "p_detail": detail,
            "p_job_id": jobId ?? "",
        ])
    }

    func raiseEmergencyAlert(jobId: String?) async throws {
        // NEVER faked. If this RPC is absent, the call throws and the UI keeps
        // the native emergency-call affordance as the real path.
        let _: EmptyResponse = try await client.rpc("mort_raise_emergency_alert", args: [
            "p_job_id": jobId ?? "",
        ])
    }

    func capabilityState() async -> SafetyCapabilityState {
        .available
    }
}

nonisolated final class LiveSupportRepository: SupportRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func cases() async throws -> [SupportCase] {
        let rows: [SupportCaseDTO] = try await client.rpc("mort_support_cases")
        return rows.map { $0.toDomain() }
    }

    func openCase(topicId: String, subject: String, detail: String, reference: String?) async throws -> SupportCase {
        let row: SupportCaseDTO = try await client.rpc("mort_open_support_case", args: [
            "p_topic": topicId,
            "p_subject": subject,
            "p_detail": detail,
            "p_reference": reference ?? "",
        ])
        return row.toDomain()
    }

    func messages(caseId: String) async throws -> [MortMessage] {
        let rows: [MessageDTO] = try await client.rpc("mort_support_messages", args: ["p_case_id": caseId])
        return rows.map { $0.toDomain() }
    }

    func reply(caseId: String, body: String) async throws -> MortMessage {
        let row: MessageDTO = try await client.rpc("mort_support_reply", args: [
            "p_case_id": caseId,
            "p_body": body,
        ])
        return row.toDomain()
    }

    func requestHuman(caseId: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_support_request_human", args: ["p_case_id": caseId])
    }
}

nonisolated final class LiveNotificationRepository: NotificationRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func notifications() async throws -> [MortNotification] {
        let rows: [NotificationDTO] = try await client.rpc("mort_notifications")
        return rows.map { $0.toDomain() }
    }

    func markRead(id: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_mark_notification_read", args: ["p_id": id])
    }

    func markAllRead() async throws {
        let _: EmptyResponse = try await client.rpc("mort_mark_all_notifications_read")
    }

    func registerPushToken(_ token: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_register_push_token", args: [
            "p_token": token,
            "p_platform": "ios",
        ])
    }
}

nonisolated final class LiveGuardianRepository: GuardianRepository {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func linkedTeens() async throws -> [MortUser] {
        let rows: [ProfileDTO] = try await client.rpc("mort_linked_teens")
        return rows.map { $0.toDomain() }
    }

    func teenSummary(teenId: String) async throws -> GuardianSummary {
        // Policy-limited by RLS: the guardian only receives approved fields.
        let dto: GuardianSummaryDTO = try await client.rpc("mort_guardian_summary", args: [
            "p_teen_id": teenId,
        ])
        return dto.toDomain()
    }

    func inviteTeen(email: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_invite_teen", args: ["p_email": email])
    }

    func acceptLink(code: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_accept_guardian_link", args: ["p_code": code])
    }

    func unlink(teenId: String) async throws {
        let _: EmptyResponse = try await client.rpc("mort_unlink_teen", args: ["p_teen_id": teenId])
    }
}
