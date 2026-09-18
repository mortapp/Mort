//
//  PreviewRepositories.swift
//  MORT iOS V8 — Services / preview + test doubles
//
//  ============================================================
//  PREVIEW / TEST ONLY — NEVER A PRODUCTION FALLBACK
//  ============================================================
//  These implementations serve `MortFixtures` so SwiftUI previews and unit
//  tests can render every state. They are selected ONLY when the app has no
//  backend configuration (see `MortDependencies.preview`), and the app shows
//  an explicit "preview data" banner in that mode so fixture content can never
//  be mistaken for real backend success.
//
//  Payment/payout doubles deliberately do NOT invent provider success: they
//  return the state they were constructed with.
//

import Foundation

nonisolated final class PreviewAuthService: AuthService {
    private let user: MortUser
    private let startsSignedIn: Bool

    init(user: MortUser = MortFixtures.teen, startsSignedIn: Bool = true) {
        self.user = user
        self.startsSignedIn = startsSignedIn
    }

    func restoreSession() async throws -> MortUser? {
        try? await Task.sleep(for: .milliseconds(240))
        return startsSignedIn ? user : nil
    }

    func signIn(email: String, password: String) async throws -> MortUser {
        try? await Task.sleep(for: .milliseconds(420))
        guard password.count >= 6 else { throw MortError.rejected("That email and password don't match.") }
        return user
    }

    func signUp(email: String, password: String, role: MortRole) async throws -> MortUser {
        try? await Task.sleep(for: .milliseconds(420))
        return MortUser(
            id: "preview-new",
            handle: "@newuser",
            displayName: "",
            role: role,
            area: nil,
            avatarInitials: "?",
            rating: nil,
            completedJobs: 0,
            verifications: [],
            memberSince: "Today",
            bio: nil,
            guardianLinked: false
        )
    }

    func signInWithApple() async throws -> MortUser {
        try? await Task.sleep(for: .milliseconds(320))
        return user
    }

    func signInWithGoogle() async throws -> MortUser {
        try? await Task.sleep(for: .milliseconds(320))
        return user
    }

    func sendPasswordReset(email: String) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }

    func completeOnboarding(userId: String, draft: MortProfileDraft) async throws -> MortUser {
        try? await Task.sleep(for: .milliseconds(300))
        return MortUser(
            id: userId,
            handle: user.handle,
            displayName: draft.displayName,
            role: user.role,
            area: draft.area,
            avatarInitials: String(draft.displayName.prefix(2)).uppercased(),
            rating: nil,
            completedJobs: 0,
            verifications: [],
            memberSince: "Today",
            bio: draft.bio,
            guardianLinked: false
        )
    }

    func signOut() async throws {}
    func deleteAccount(userId: String) async throws {}
}

nonisolated final class PreviewJobRepository: JobRepository {
    func discover(query: String?, category: String?, cursor: String?) async throws -> (jobs: [MortJob], nextCursor: String?) {
        try? await Task.sleep(for: .milliseconds(300))
        var jobs = MortFixtures.nearbyJobs
        if let category, !category.isEmpty {
            jobs = jobs.filter { $0.category == category }
        }
        if let query, !query.isEmpty {
            let q = query.lowercased()
            jobs = jobs.filter {
                $0.title.lowercased().contains(q) || $0.category.lowercased().contains(q)
            }
        }
        return (jobs, nil)
    }

    func job(id: String) async throws -> MortJob {
        try? await Task.sleep(for: .milliseconds(180))
        let all = MortFixtures.nearbyJobs + MortFixtures.myJobs + [MortFixtures.jobLongContent]
        guard let job = all.first(where: { $0.id == id }) else { throw MortError.notFound }
        return job
    }

    func myJobs(role: MortRole) async throws -> [MortJob] {
        try? await Task.sleep(for: .milliseconds(260))
        return MortFixtures.myJobs
    }

    func createJob(
        title: String, category: String, details: String,
        baseCents: Int64, scheduleText: String, requiresProof: Bool
    ) async throws -> MortJob {
        try? await Task.sleep(for: .milliseconds(420))
        return MortJob(
            id: "job-new", title: title, category: category, details: details,
            baseCents: baseCents, distance: "—", area: "Northside",
            scheduleText: scheduleText, posterHandle: MortFixtures.adult.handle,
            posterDisplayName: MortFixtures.adult.displayName, workerHandle: nil,
            state: .open, orderNumber: nil, applicantCount: 0,
            postedAgo: "Just now", requiresProof: requiresProof
        )
    }

    func updateJob(id: String, title: String, details: String, baseCents: Int64) async throws -> MortJob {
        try? await Task.sleep(for: .milliseconds(300))
        return MortFixtures.job
    }

    func cancelJob(id: String, reason: String) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }

    func fairPayPolicy(category: String) async throws -> FairPayPolicy {
        try? await Task.sleep(for: .milliseconds(150))
        return .reference
    }
}

nonisolated final class PreviewApplicationRepository: ApplicationRepository {
    func applications(jobId: String) async throws -> [MortApplication] {
        try? await Task.sleep(for: .milliseconds(260))
        return MortFixtures.applications
    }

    func myApplications() async throws -> [MortApplication] {
        try? await Task.sleep(for: .milliseconds(260))
        return [MortFixtures.applications[0], MortFixtures.applications[2]]
    }

    func apply(jobId: String, message: String) async throws -> MortApplication {
        try? await Task.sleep(for: .milliseconds(380))
        return MortFixtures.applications[2]
    }

    func withdraw(applicationId: String) async throws {}
    func selectApplicant(applicationId: String) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }
}

nonisolated final class PreviewJobExecutionRepository: JobExecutionRepository {
    func startJob(jobId: String, pin: String, personMatchesProfile: Bool) async throws {
        try? await Task.sleep(for: .milliseconds(300))
        guard personMatchesProfile else {
            throw MortError.rejected("Confirm the person matches the profile before starting.")
        }
        guard pin == "441733" else {
            throw MortError.rejected("That code doesn't match. Ask them to read it again.")
        }
    }

    func startPin(jobId: String) async throws -> String { "441733" }

    func submitProof(jobId: String, note: String, attachment: JobProofAttachment) async throws {
        try? await Task.sleep(for: .milliseconds(380))
    }

    func markComplete(jobId: String) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }

    func confirmCompletion(jobId: String) async throws -> SettlementResult {
        try? await Task.sleep(for: .milliseconds(520))
        return MortFixtures.settlement
    }

    func openDispute(jobId: String, category: String, detail: String) async throws {
        try? await Task.sleep(for: .milliseconds(320))
    }

    func settlement(jobId: String) async throws -> SettlementResult {
        try? await Task.sleep(for: .milliseconds(240))
        return MortFixtures.settlement
    }
}

nonisolated final class PreviewPaymentRepository: PaymentRepository {
    /// The state this double reports. Set it per preview to inspect a state —
    /// it never decides an outcome on its own.
    private let outcome: PaymentState
    private let reason: PaymentFailureReason?

    init(outcome: PaymentState = .funded, reason: PaymentFailureReason? = nil) {
        self.outcome = outcome
        self.reason = reason
    }

    func fundingQuote(jobId: String) async throws -> PaymentQuote {
        try? await Task.sleep(for: .milliseconds(240))
        return MortFixtures.quote
    }

    func beginFunding(jobId: String, methodId: String?, idempotencyKey: String) async throws -> PaymentState {
        try? await Task.sleep(for: .milliseconds(900))
        return outcome
    }

    func fundingStatus(jobId: String) async throws -> (state: PaymentState, reason: PaymentFailureReason?) {
        try? await Task.sleep(for: .milliseconds(420))
        return (outcome, reason)
    }

    func paymentMethods() async throws -> [PaymentMethodRef] {
        try? await Task.sleep(for: .milliseconds(200))
        return MortFixtures.methods
    }

    func setDefaultMethod(id: String) async throws {}

    func submitTip(jobId: String, tipCents: Int64, idempotencyKey: String) async throws -> PaymentState {
        try? await Task.sleep(for: .milliseconds(700))
        return outcome == .funded ? .funded : outcome
    }

    func feeConfig() async throws -> MortFeeConfig { .reference }
    func tipConfig() async throws -> TipConfig { .reference }
}

nonisolated final class PreviewReceiptRepository: ReceiptRepository {
    func receipt(number: String) async throws -> Receipt {
        try? await Task.sleep(for: .milliseconds(240))
        guard let match = MortFixtures.allReceipts.first(where: { number.hasPrefix($0.id) || $0.id == number })
        else { throw MortError.notFound }
        return match
    }

    func receipts(cursor: String?) async throws -> (receipts: [Receipt], nextCursor: String?) {
        try? await Task.sleep(for: .milliseconds(280))
        return (MortFixtures.allReceipts, nil)
    }

    func receipt(jobId: String, type: ReceiptType) async throws -> Receipt? {
        try? await Task.sleep(for: .milliseconds(200))
        return MortFixtures.allReceipts.first { $0.type == type }
    }
}

nonisolated final class PreviewPayoutRepository: PayoutRepository {
    private let stage: PayoutStage
    init(stage: PayoutStage = .transferPending) { self.stage = stage }

    func payoutStatus() async throws -> PayoutStatus {
        try? await Task.sleep(for: .milliseconds(220))
        return PayoutStatus(
            id: "po-preview",
            stage: stage,
            amountCents: MortFixtures.payout.amountCents,
            relatedReceiptNumber: MortFixtures.payout.relatedReceiptNumber,
            updatedAt: MortFixtures.payout.updatedAt,
            destinationMask: MortFixtures.payout.destinationMask,
            expectedText: MortFixtures.payout.expectedText
        )
    }

    func payoutHistory() async throws -> [PayoutStatus] {
        try? await Task.sleep(for: .milliseconds(260))
        return [MortFixtures.payout]
    }

    func beginPayoutOnboarding() async throws -> URL {
        URL(string: "https://connect.stripe.com/setup/preview")!
    }

    func refreshPayoutReadiness() async throws -> PayoutStage {
        try? await Task.sleep(for: .milliseconds(320))
        return stage
    }
}

nonisolated final class PreviewHistoryRepository: HistoryRepository {
    private let useLargeFeed: Bool
    private let exportStateValue: ExportState

    init(useLargeFeed: Bool = false, exportState: ExportState = .ready) {
        self.useLargeFeed = useLargeFeed
        self.exportStateValue = exportState
    }

    func records(
        filter: HistoryFilter, year: Int?, query: String?, cursor: String?
    ) async throws -> (records: [HistoryRecord], nextCursor: String?) {
        try? await Task.sleep(for: .milliseconds(300))
        var records = useLargeFeed ? MortFixtures.largeHistoryFeed() : MortFixtures.historyRecords()
        records = records.filter { $0.kind.matches(filter) }
        if let year { records = records.filter { $0.year == year } }
        if let query, !query.isEmpty { records = records.filter { $0.matches(query: query) } }
        records.sort { $0.occurredAt > $1.occurredAt }
        // Simulate a first page + cursor so pagination UI is exercised.
        if records.count > 25, cursor == nil {
            return (Array(records.prefix(25)), "page-2")
        }
        return (records, nil)
    }

    func availableYears() async throws -> [Int] {
        let records = useLargeFeed ? MortFixtures.largeHistoryFeed() : MortFixtures.historyRecords()
        return Array(Set(records.map(\.year))).sorted(by: >)
    }

    func startAnnualExport(year: Int) async throws {
        try? await Task.sleep(for: .milliseconds(400))
    }

    func exportState(year: Int) async throws -> ExportState { exportStateValue }

    func exportFile(year: Int) async throws -> URL {
        // No real file in previews — fail closed rather than fake a save.
        throw MortError.notConfigured("Annual export file")
    }
}

nonisolated final class PreviewMessageRepository: MessageRepository {
    func conversations() async throws -> [MortConversation] {
        try? await Task.sleep(for: .milliseconds(260))
        return MortFixtures.conversations
    }

    func messages(conversationId: String, cursor: String?) async throws -> (messages: [MortMessage], nextCursor: String?) {
        try? await Task.sleep(for: .milliseconds(240))
        return (MortFixtures.messages.filter { $0.conversationId == conversationId }, nil)
    }

    func send(conversationId: String, body: String) async throws -> MortMessage {
        try? await Task.sleep(for: .milliseconds(320))
        return MortMessage(
            id: UUID().uuidString,
            conversationId: conversationId,
            authorHandle: MortFixtures.teen.handle,
            authorDisplayName: MortFixtures.teen.displayName,
            body: body,
            sentAt: Date(),
            fromMe: true,
            delivery: .sent,
            attachmentName: nil
        )
    }

    func markRead(conversationId: String) async throws {}
    func report(conversationId: String, category: SafetyReportCategory, detail: String) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }
    func block(handle: String) async throws {
        try? await Task.sleep(for: .milliseconds(240))
    }
}

nonisolated final class PreviewSafetyRepository: SafetyRepository {
    private let capability: SafetyCapabilityState
    init(capability: SafetyCapabilityState = .available) { self.capability = capability }

    func activeCheckIn() async throws -> SafetyCheckIn? {
        try? await Task.sleep(for: .milliseconds(220))
        return MortFixtures.checkIn
    }

    func confirmCheckIn(id: String) async throws {
        try? await Task.sleep(for: .milliseconds(260))
    }

    func contacts() async throws -> [SafetyContact] {
        try? await Task.sleep(for: .milliseconds(220))
        return MortFixtures.safetyContacts
    }

    func shareJobStatus(jobId: String, enabled: Bool) async throws {}

    func report(category: SafetyReportCategory, detail: String, jobId: String?) async throws {
        try? await Task.sleep(for: .milliseconds(320))
    }

    func raiseEmergencyAlert(jobId: String?) async throws {
        // Previews must NEVER imply an emergency alert was dispatched.
        throw MortError.notConfigured("Emergency alerting")
    }

    func capabilityState() async -> SafetyCapabilityState { capability }
}

nonisolated final class PreviewSupportRepository: SupportRepository {
    func cases() async throws -> [SupportCase] {
        try? await Task.sleep(for: .milliseconds(260))
        return MortFixtures.supportCases
    }

    func openCase(topicId: String, subject: String, detail: String, reference: String?) async throws -> SupportCase {
        try? await Task.sleep(for: .milliseconds(400))
        return SupportCase(
            id: "sup-new", subject: subject, state: .open,
            updatedAt: Date(), lastMessagePreview: detail,
            withHumanAgent: false, reference: reference
        )
    }

    func messages(caseId: String) async throws -> [MortMessage] {
        try? await Task.sleep(for: .milliseconds(240))
        return [
            MortMessage(
                id: "sm1", conversationId: caseId, authorHandle: "@mort_support",
                authorDisplayName: "MORT Support",
                body: "Thanks for reaching out — we've got this and will update you here.",
                sentAt: Date().addingTimeInterval(-3600), fromMe: false,
                delivery: .read, attachmentName: nil
            )
        ]
    }

    func reply(caseId: String, body: String) async throws -> MortMessage {
        try? await Task.sleep(for: .milliseconds(300))
        return MortMessage(
            id: UUID().uuidString, conversationId: caseId,
            authorHandle: MortFixtures.teen.handle,
            authorDisplayName: MortFixtures.teen.displayName,
            body: body, sentAt: Date(), fromMe: true,
            delivery: .sent, attachmentName: nil
        )
    }

    func requestHuman(caseId: String) async throws {
        try? await Task.sleep(for: .milliseconds(280))
    }
}

nonisolated final class PreviewNotificationRepository: NotificationRepository {
    func notifications() async throws -> [MortNotification] {
        try? await Task.sleep(for: .milliseconds(240))
        return MortFixtures.notifications
    }

    func markRead(id: String) async throws {}
    func markAllRead() async throws {}
    func registerPushToken(_ token: String) async throws {}
}

nonisolated final class PreviewProfileRepository: ProfileRepository {
    func profile(userId: String) async throws -> MortUser {
        try? await Task.sleep(for: .milliseconds(200))
        return MortFixtures.teen
    }

    func updateProfile(userId: String, draft: MortProfileDraft) async throws -> MortUser {
        try? await Task.sleep(for: .milliseconds(300))
        return MortFixtures.teen
    }

    func reviews(userId: String) async throws -> [MortReview] {
        try? await Task.sleep(for: .milliseconds(260))
        return [
            MortReview(
                id: "rv1", authorHandle: "@marcus", authorDisplayName: "Marcus T.",
                rating: 5, body: "Showed up early and did a careful job. Would hire again.",
                jobTitle: "Lawn mowing and edging",
                createdAt: Date(timeIntervalSince1970: 1_789_000_000)
            ),
            MortReview(
                id: "rv2", authorHandle: "@sofia", authorDisplayName: "Sofia L.",
                rating: 5, body: "Very reliable with the plants while we were away.",
                jobTitle: "Water plants while away",
                createdAt: Date(timeIntervalSince1970: 1_788_000_000)
            ),
        ]
    }
}

nonisolated final class PreviewGuardianRepository: GuardianRepository {
    func linkedTeens() async throws -> [MortUser] {
        try? await Task.sleep(for: .milliseconds(240))
        return [MortFixtures.teen]
    }

    func teenSummary(teenId: String) async throws -> GuardianSummary {
        try? await Task.sleep(for: .milliseconds(280))
        return GuardianSummary(
            teenHandle: MortFixtures.teen.handle,
            teenDisplayName: MortFixtures.teen.displayName,
            activeJobCount: 2,
            upcomingJobTitle: "Lawn mowing and edging — Saturday 10:00 AM",
            lastCheckInState: .confirmed,
            lastCheckInText: "Checked in at 10:06 AM",
            earningsThisMonthCents: 8700,
            payoutStage: .transferPending,
            safetyAlertsCount: 0,
            restrictedNotice: "Message contents, exact locations and full payment details stay private to your teen."
        )
    }

    func inviteTeen(email: String) async throws {
        try? await Task.sleep(for: .milliseconds(320))
    }

    func acceptLink(code: String) async throws {
        try? await Task.sleep(for: .milliseconds(320))
    }

    func unlink(teenId: String) async throws {}
}
