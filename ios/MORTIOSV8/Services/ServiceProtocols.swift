//
//  ServiceProtocols.swift
//  MORT iOS V8 — Services
//
//  ============================================================
//  THESE ARE THE INTEGRATION BOUNDARIES.
//  ============================================================
//  Every protocol here is fully specified native Swift. The CONCRETE
//  implementations that talk to Supabase / Stripe / APNs are the parts VS Code
//  must wire to the real MORT backend (see the *Live* adapters).
//
//  Rules that apply to every implementation:
//   - The backend is authoritative for auth, money, receipts and payouts.
//   - Never fabricate success. Unwired paths throw `.notConfigured` and the UI
//     renders an honest unavailable state.
//   - Money is integer cents everywhere.
//   - No service-role keys, no secret keys, no RLS bypass in the app.
//

import Foundation

// MARK: - Auth

/// Authentication. Backed by Supabase Auth in production.
protocol AuthService: Sendable {
    /// Restores a persisted session. Returns nil when there is none.
    func restoreSession() async throws -> MortUser?
    func signIn(email: String, password: String) async throws -> MortUser
    func signUp(email: String, password: String, role: MortRole) async throws -> MortUser
    /// Native Sign in with Apple. Requires the capability + entitlement.
    func signInWithApple() async throws -> MortUser
    /// Google OAuth via ASWebAuthenticationSession + Supabase callback.
    func signInWithGoogle() async throws -> MortUser
    func sendPasswordReset(email: String) async throws
    func completeOnboarding(userId: String, draft: MortProfileDraft) async throws -> MortUser
    func signOut() async throws
    func deleteAccount(userId: String) async throws
}

// MARK: - Jobs

/// A normalized proof image ready for the private proof-uploads bucket.
/// Live implementations accept JPEG bytes only because the hosted proof RPC
/// validates both the object path and MIME type before attaching evidence.
nonisolated struct JobProofAttachment: Sendable, Equatable {
    let data: Data
    let filename: String
    let contentType: String

    init(data: Data, filename: String, contentType: String = "image/jpeg") {
        self.data = data
        self.filename = filename
        self.contentType = contentType
    }
}


protocol JobRepository: Sendable {
    /// Paginated discovery feed. `cursor` is an opaque backend cursor.
    func discover(query: String?, category: String?, cursor: String?) async throws -> (jobs: [MortJob], nextCursor: String?)
    func job(id: String) async throws -> MortJob
    /// Jobs relevant to the signed-in user in their current role.
    func myJobs(role: MortRole) async throws -> [MortJob]
    func createJob(
        title: String,
        category: String,
        details: String,
        baseCents: Int64,
        scheduleText: String,
        requiresProof: Bool
    ) async throws -> MortJob
    func updateJob(id: String, title: String, details: String, baseCents: Int64) async throws -> MortJob
    func cancelJob(id: String, reason: String) async throws
    /// Fair Pay policy for a job type. May require new backend if absent.
    func fairPayPolicy(category: String) async throws -> FairPayPolicy
}

protocol ApplicationRepository: Sendable {
    func applications(jobId: String) async throws -> [MortApplication]
    func myApplications() async throws -> [MortApplication]
    func apply(jobId: String, message: String) async throws -> MortApplication
    func withdraw(applicationId: String) async throws
    /// Selecting a worker. Backend enforces funding and eligibility rules.
    func selectApplicant(applicationId: String) async throws
}

/// Job execution: start, PIN handshake, proof, completion.
protocol JobExecutionRepository: Sendable {
    /// Starting requires the job to be FUNDED — the backend enforces this.
    /// personMatchesProfile is an explicit in-person safety attestation and
    /// must come from the worker UI; the client must never assume it.
    func startJob(jobId: String, pin: String, personMatchesProfile: Bool) async throws
    /// The PIN the counterparty must enter. Issued by the backend.
    func startPin(jobId: String) async throws -> String
    func submitProof(jobId: String, note: String, attachment: JobProofAttachment) async throws
    func markComplete(jobId: String) async throws
    /// Adult confirms the work; this triggers authoritative settlement.
    func confirmCompletion(jobId: String) async throws -> SettlementResult
    func openDispute(jobId: String, category: String, detail: String) async throws
    func settlement(jobId: String) async throws -> SettlementResult
}

// MARK: - Payments (Payment OS)

protocol PaymentRepository: Sendable {
    /// Authoritative pre-work funding quote. Never computed on device.
    /// This may create/supersede a short-lived backend quote and is therefore
    /// only for the payment-review step.
    func fundingQuote(jobId: String) async throws -> PaymentQuote
    /// Returns already-known funding display context without creating a new
    /// quote. Used by result/tip screens so rendering never mutates money state.
    func fundingDisplay(jobId: String) async throws -> PaymentQuote?
    /// Starts pre-work platform funding. Returns the backend's state.
    /// An idempotency key makes duplicate submissions impossible.
    func beginFunding(jobId: String, methodId: String?, idempotencyKey: String) async throws -> PaymentState
    /// Reconciles an unknown/pending outcome. The ONLY way to learn the
    /// result after a dropped connection.
    func fundingStatus(jobId: String) async throws -> (state: PaymentState, reason: PaymentFailureReason?)
    func paymentMethods() async throws -> [PaymentMethodRef]
    func setDefaultMethod(id: String) async throws
    /// Tip is a SEPARATE transaction; a failure here never undoes settlement.
    func submitTip(jobId: String, tipCents: Int64, idempotencyKey: String) async throws -> PaymentState
    func feeConfig() async throws -> MortFeeConfig
    func tipConfig() async throws -> TipConfig
}


extension PaymentRepository {
    func fundingDisplay(jobId: String) async throws -> PaymentQuote? {
        try await fundingQuote(jobId: jobId)
    }
}

protocol ReceiptRepository: Sendable {
    func receipt(number: String) async throws -> Receipt
    func receipts(cursor: String?) async throws -> (receipts: [Receipt], nextCursor: String?)
    /// Receipt for a specific job + document type, if one was issued.
    func receipt(jobId: String, type: ReceiptType) async throws -> Receipt?
}

protocol PayoutRepository: Sendable {
    func payoutStatus() async throws -> PayoutStatus
    func payoutHistory() async throws -> [PayoutStatus]
    /// Returns the provider onboarding URL to present. Never fabricate
    /// completion — the backend confirms readiness.
    func beginPayoutOnboarding() async throws -> URL
    func refreshPayoutReadiness() async throws -> PayoutStage
}

// MARK: - History

protocol HistoryRepository: Sendable {
    func records(
        filter: HistoryFilter,
        year: Int?,
        query: String?,
        cursor: String?
    ) async throws -> (records: [HistoryRecord], nextCursor: String?)
    /// Distinct years present in the feed — never a hardcoded list.
    func availableYears() async throws -> [Int]
    /// Starts an annual export job. [DO NOT FAKE] no file ⇒ no success.
    func startAnnualExport(year: Int) async throws
    func exportState(year: Int) async throws -> ExportState
    /// The generated file, once the backend has produced it.
    func exportFile(year: Int) async throws -> URL
}

// MARK: - Messaging

protocol MessageRepository: Sendable {
    func conversations() async throws -> [MortConversation]
    func messages(conversationId: String, cursor: String?) async throws -> (messages: [MortMessage], nextCursor: String?)
    func send(conversationId: String, body: String) async throws -> MortMessage
    func markRead(conversationId: String) async throws
    func report(conversationId: String, category: SafetyReportCategory, detail: String) async throws
    func block(handle: String) async throws
}

// MARK: - Safety

protocol SafetyRepository: Sendable {
    func activeCheckIn() async throws -> SafetyCheckIn?
    func confirmCheckIn(id: String) async throws
    func contacts() async throws -> [SafetyContact]
    func shareJobStatus(jobId: String, enabled: Bool) async throws
    func report(category: SafetyReportCategory, detail: String, jobId: String?) async throws
    /// Raises an emergency alert through the backend. NEVER simulated: if this
    /// is not wired, it throws and the UI shows an honest unavailable state
    /// plus the native emergency-call affordance.
    func raiseEmergencyAlert(jobId: String?) async throws
    func capabilityState() async -> SafetyCapabilityState
}

// MARK: - Support

protocol SupportRepository: Sendable {
    func cases() async throws -> [SupportCase]
    func openCase(topicId: String, subject: String, detail: String, reference: String?) async throws -> SupportCase
    func messages(caseId: String) async throws -> [MortMessage]
    func reply(caseId: String, body: String) async throws -> MortMessage
    /// Escalates to a human agent. Backend decides queue priority.
    func requestHuman(caseId: String) async throws
}

// MARK: - Notifications / Profile / Guardian

protocol NotificationRepository: Sendable {
    func notifications() async throws -> [MortNotification]
    func markRead(id: String) async throws
    func markAllRead() async throws
    /// Registers the APNs device token with the backend.
    func registerPushToken(_ token: String) async throws
}

protocol ProfileRepository: Sendable {
    func profile(userId: String) async throws -> MortUser
    func updateProfile(userId: String, draft: MortProfileDraft) async throws -> MortUser
    func reviews(userId: String) async throws -> [MortReview]
}

/// A review left after a completed job.
nonisolated struct MortReview: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let authorHandle: String
    let authorDisplayName: String
    let rating: Int
    let body: String
    let jobTitle: String
    let createdAt: Date

    var dateText: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: createdAt)
    }
}

protocol GuardianRepository: Sendable {
    /// The teens linked to this guardian.
    func linkedTeens() async throws -> [MortUser]
    /// Policy-limited summary for a linked teen.
    func teenSummary(teenId: String) async throws -> GuardianSummary
    func inviteTeen(email: String) async throws
    func acceptLink(code: String) async throws
    func unlink(teenId: String) async throws
}

/// What a guardian is permitted to see. Deliberately limited: no message
/// contents, no exact locations, no full financial identifiers.
nonisolated struct GuardianSummary: Codable, Hashable, Sendable {
    let teenHandle: String
    let teenDisplayName: String
    let activeJobCount: Int
    let upcomingJobTitle: String?
    let lastCheckInState: CheckInState
    let lastCheckInText: String
    /// Approved aggregate only, in cents.
    let earningsThisMonthCents: Int64
    let payoutStage: PayoutStage
    let safetyAlertsCount: Int
    /// Fields the guardian is NOT allowed to see, for honest UI messaging.
    let restrictedNotice: String

    var earningsThisMonth: Money { Money(cents: earningsThisMonthCents) }
}
