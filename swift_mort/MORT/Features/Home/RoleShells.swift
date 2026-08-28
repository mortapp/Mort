import SwiftUI

struct RoleRootView: View {
    @Environment(Router.self) private var router
    let role: UserRole

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            shell
                .navigationDestination(for: AppRoute.self) { route in
                    RouteDestinationView(route: route)
                }
        }
        .tint(MortColors.neon)
    }

    @ViewBuilder
    private var shell: some View {
        switch role {
        case .teen: TeenShellView()
        case .adult: AdultShellView()
        case .guardian: GuardianShellView()
        case .admin: AdminShellView()
        }
    }
}

private struct TeenShellView: View {
    var body: some View {
        TabView {
            JobFeedView().tabItem { Label("Jobs", systemImage: "briefcase.fill") }
            ApplicationsView(mode: .teen).tabItem { Label("Applied", systemImage: "doc.text.fill") }
            MessageListView().tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
            SafetyCenterView().tabItem { Label("Safety", systemImage: "shield.fill") }
            SettingsView().tabItem { Label("You", systemImage: "person.crop.circle.fill") }
        }
    }
}

private struct AdultShellView: View {
    var body: some View {
        TabView {
            AdultDashboardView().tabItem { Label("Home", systemImage: "house.fill") }
            MyJobsView().tabItem { Label("Jobs", systemImage: "briefcase.fill") }
            JobWizardView(jobID: nil).tabItem { Label("Post", systemImage: "plus.square.fill") }
            ApplicationsView(mode: .adult).tabItem { Label("Applicants", systemImage: "person.2.fill") }
            SettingsView().tabItem { Label("You", systemImage: "person.crop.circle.fill") }
        }
    }
}

private struct GuardianShellView: View {
    var body: some View {
        TabView {
            GuardianDashboardView().tabItem { Label("Guardian", systemImage: "person.2.badge.gearshape.fill") }
            ApplicationsView(mode: .guardian).tabItem { Label("Approvals", systemImage: "checkmark.seal.fill") }
            GuardianSafetyPingsView().tabItem { Label("Pings", systemImage: "location.fill") }
            SafetyCenterView().tabItem { Label("Safety", systemImage: "shield.fill") }
            SettingsView().tabItem { Label("You", systemImage: "person.crop.circle.fill") }
        }
    }
}

private struct AdminShellView: View {
    var body: some View {
        TabView {
            AdminDashboardView().tabItem { Label("Admin", systemImage: "gauge.with.dots.needle.67percent") }
            AdminQueueView(queue: .reports).tabItem { Label("Reports", systemImage: "flag.fill") }
            AdminQueueView(queue: .verifications).tabItem { Label("Verify", systemImage: "checkmark.shield.fill") }
            AdminQueueView(queue: .support).tabItem { Label("Support", systemImage: "lifepreserver.fill") }
            SettingsView().tabItem { Label("You", systemImage: "person.crop.circle.fill") }
        }
    }
}

struct RouteDestinationView: View {
    let route: AppRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case .jobFeed: JobFeedView()
        case let .jobDetail(id): JobDetailView(jobID: id)
        case .savedJobs: SavedJobsView()
        case let .jobWizard(id): JobWizardView(jobID: id)
        case .myJobs: MyJobsView()
        case let .jobManagement(id): JobManagementView(jobID: id)
        case let .applications(mode): ApplicationsView(mode: mode)
        case let .applicationDetail(id, mode): ApplicationDetailView(applicationID: id, mode: mode)
        case let .proofUpload(id): ProofUploadView(applicationID: id)
        case let .proofReview(id): ProofReviewView(applicationID: id)
        case .messages: MessageListView()
        case let .messageThread(id): MessageThreadView(threadID: id)
        case .guardianMode: GuardianModeView()
        case .guardianSafetyPings: GuardianSafetyPingsView()
        case .safetyCenter: SafetyCenterView()
        case .safetyCircle: SafetyCircleView()
        case .incidentHistory: IncidentHistoryView()
        case let .jobSafety(id): JobSafetyWorkspaceView(applicationID: id)
        case .activeSessions: SessionManagementView()
        case .accountTrust: AccountTrustView()
        case .deviceSecurity: DeviceSecuritySettingsView()
        case .passkeys: PasskeySettingsView()
        case .schoolAffiliation: SchoolEmailVerificationView()
        case .partnerCode: PartnerCodeVerificationView()
        case .businessRegistry: BusinessRegistryMatchView()
        case .digitalID: DigitalIDAvailabilityView()
        case .trustAppeal: VerificationAppealView()
        case .trustAdmin: TrustAdminReviewView()
        case .pilotEligibility: PilotEligibilityView()
        case .partnerInvitation: PartnerInvitationView()
        case .partnerAffiliation: PartnerAffiliationView()
        case .discreetMode: DiscreetModeSettingsView()
        case .supportCircle: SupportCircleView()
        case .futureIndependence: FutureIndependencePlanView()
        case .earningsGoals: EarningsGoalsView()
        case .resourceDirectory: ResourceDirectoryView()
        case .pilotJobSafety: PilotJobSafetyView()
        case .verificationExplanation: VerificationExplanationView()
        case .documentReviewStatus: DocumentReviewStatusView()
        case .documentCaptureQuality: DocumentCaptureQualityView()
        case .livePresence: LivePresenceChallengeView()
        case .livePresenceAccessibility: LivePresenceAccessibilityView()
        case .teamAccessReview: TeamAccessReviewView()
        case .reviewerAssignment: ReviewerAssignmentView()
        case let .report(target): ReportView(target: target)
        case .blockedUsers: BlockedUsersView()
        case .notifications: NotificationCenterView()
        case .profile: ProfileView()
        case .businessProfile: BusinessProfileView()
        case .emergencyContact: EmergencyContactView()
        case .avatar: AvatarEditorView()
        case .reviews: ReviewsView()
        case let .leaveReview(jobID, subjectID): LeaveReviewView(jobID: jobID, subjectID: subjectID)
        case .activity: ActivityHistoryView()
        case .verification: VerificationView()
        case let .monetization(offering): PaywallView(offeringID: offering)
        case .customerCenter: CustomerCenterScreen()
        case .support: SupportCenterView()
        case let .adminQueue(queue): AdminQueueView(queue: queue)
        case .settings: SettingsView()
        case .username: UsernameView()
        case .adPreferences: AdPreferencesView()
        case .paymentPreferences: PaymentPreferenceView()
        case .jobContracts: JobContractsView()
        case let .jobContract(id): JobContractReviewView(contractID: id)
        case let .jobContractChange(id): JobContractChangeView(contractID: id)
        case let .paymentStatus(id): PaymentStatusView(contractID: id)
        case let .nonpaymentReport(id): NonpaymentReportView(obligationID: id)
        case let .paymentDispute(id): PaymentDisputeView(disputeID: id)
        case let .evidenceExport(id): EvidenceExportView(disputeID: id)
        case .pushSettings: PushSettingsView()
        case .accountDeletion: AccountDeletionRequestView()
        case let .legal(document): LegalDocumentView(document: document)
        case .legalCenter: LegalCenterView()
        case .teenTermsSummary: TeenTermsSummaryView()
        case let .legalAcceptance(requirement): LegalReacceptanceView(requirement: requirement)
        case .biometricSettings: BiometricSettingsView()
        case let .unavailable(title, reason): UnavailableFeatureView(title: title, reason: reason)
        }
    }
}
