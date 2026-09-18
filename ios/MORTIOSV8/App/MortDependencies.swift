//
//  MortDependencies.swift
//  MORT iOS V8 — App
//
//  The dependency container. One place decides whether the app talks to the
//  real MORT backend or renders clearly-labeled preview fixtures.
//
//  FAIL-CLOSED RULE: when no backend configuration is present the app runs in
//  `.preview` mode AND surfaces a visible "preview data" banner, so fixture
//  content can never be mistaken for real backend success.
//

import SwiftUI

/// How the app is currently sourcing data.
nonisolated enum MortDataMode: Sendable, Equatable {
    /// Wired to the real MORT backend.
    case live
    /// No backend configuration — previews/fixtures only, clearly labeled.
    case preview

    var isPreview: Bool { self == .preview }
}

@Observable
@MainActor
final class MortDependencies {
    let mode: MortDataMode

    let auth: any AuthService
    let jobs: any JobRepository
    let applications: any ApplicationRepository
    let execution: any JobExecutionRepository
    let payments: any PaymentRepository
    let receipts: any ReceiptRepository
    let payouts: any PayoutRepository
    let history: any HistoryRepository
    let messages: any MessageRepository
    let safety: any SafetyRepository
    let support: any SupportRepository
    let notifications: any NotificationRepository
    let profiles: any ProfileRepository
    let guardians: any GuardianRepository

    let settings: MortSettingsStore
    let session: MortSession

    private init(
        mode: MortDataMode,
        auth: any AuthService,
        jobs: any JobRepository,
        applications: any ApplicationRepository,
        execution: any JobExecutionRepository,
        payments: any PaymentRepository,
        receipts: any ReceiptRepository,
        payouts: any PayoutRepository,
        history: any HistoryRepository,
        messages: any MessageRepository,
        safety: any SafetyRepository,
        support: any SupportRepository,
        notifications: any NotificationRepository,
        profiles: any ProfileRepository,
        guardians: any GuardianRepository,
        settings: MortSettingsStore = MortSettingsStore()
    ) {
        self.mode = mode
        self.auth = auth
        self.jobs = jobs
        self.applications = applications
        self.execution = execution
        self.payments = payments
        self.receipts = receipts
        self.payouts = payouts
        self.history = history
        self.messages = messages
        self.safety = safety
        self.support = support
        self.notifications = notifications
        self.profiles = profiles
        self.guardians = guardians
        self.settings = settings
        self.session = MortSession(auth: auth)
    }

    /// Resolves the shipping container from public client configuration.
    static func resolve() -> MortDependencies {
        resolve(config: SupabaseConfig.fromEnvironment())
    }

    /// Explicit configuration seam for tests and controlled bootstrap paths.
    /// Passing nil must fail closed to clearly labeled preview data.
    static func resolve(config: SupabaseConfig?) -> MortDependencies {
        guard let config else {
            return .preview()
        }
        let client = SupabaseClient(config: config)
        let sheet = StripePaymentSheetAdapter()
        return MortDependencies(
            mode: .live,
            auth: LiveAuthService(client: client),
            jobs: LiveJobRepository(client: client),
            applications: LiveApplicationRepository(client: client),
            execution: LiveJobExecutionRepository(client: client),
            payments: LivePaymentRepository(client: client, sheet: sheet),
            receipts: LiveReceiptRepository(client: client),
            payouts: LivePayoutRepository(client: client),
            history: LiveHistoryRepository(client: client),
            messages: LiveMessageRepository(client: client),
            safety: LiveSafetyRepository(client: client),
            support: LiveSupportRepository(client: client),
            notifications: LiveNotificationRepository(client: client),
            profiles: LiveProfileRepository(client: client),
            guardians: LiveGuardianRepository(client: client)
        )
    }

    /// Preview/fixture container. Also used by SwiftUI previews and tests.
    static func preview(
        user: MortUser = MortFixtures.teen,
        signedIn: Bool = true,
        paymentOutcome: PaymentState = .funded,
        paymentReason: PaymentFailureReason? = nil,
        payoutStage: PayoutStage = .transferPending,
        largeHistory: Bool = false,
        exportState: ExportState = .ready
    ) -> MortDependencies {
        MortDependencies(
            mode: .preview,
            auth: PreviewAuthService(user: user, startsSignedIn: signedIn),
            jobs: PreviewJobRepository(),
            applications: PreviewApplicationRepository(),
            execution: PreviewJobExecutionRepository(),
            payments: PreviewPaymentRepository(outcome: paymentOutcome, reason: paymentReason),
            receipts: PreviewReceiptRepository(),
            payouts: PreviewPayoutRepository(stage: payoutStage),
            history: PreviewHistoryRepository(useLargeFeed: largeHistory, exportState: exportState),
            messages: PreviewMessageRepository(),
            safety: PreviewSafetyRepository(),
            support: PreviewSupportRepository(),
            notifications: PreviewNotificationRepository(),
            profiles: PreviewProfileRepository(),
            guardians: PreviewGuardianRepository()
        )
    }
}

// MARK: - Environment

private struct MortDependenciesKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: MortDependencies = .preview()
}

extension EnvironmentValues {
    var mort: MortDependencies {
        get { self[MortDependenciesKey.self] }
        set { self[MortDependenciesKey.self] = newValue }
    }
}
