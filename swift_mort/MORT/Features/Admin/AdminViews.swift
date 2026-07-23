import SwiftUI

struct AdminDashboardView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var counts: [AdminQueue: Int] = [:]
    @State private var monetization: [String: JSONValue] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                VStack(alignment: .leading, spacing: MortSpacing.xs) {
                    Text("SERVER-AUTHORIZED").font(MortTypography.caption).foregroundStyle(MortColors.danger)
                    Text("Admin dashboard").font(MortTypography.title)
                    Text("Access and mutations are enforced by Supabase admin checks and RLS. This UI is not the security boundary.")
                        .foregroundStyle(MortColors.textMuted)
                }
                if isLoading { ProgressView().tint(MortColors.neon) }
                if let errorMessage { MortAlertBanner(title: "Some queues failed", message: errorMessage) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: MortSpacing.sm)], spacing: MortSpacing.sm) {
                    ForEach(AdminQueue.allCases) { queue in
                        Button { router.push(.adminQueue(queue)) } label: {
                            MortCard {
                                VStack(alignment: .leading, spacing: MortSpacing.xs) {
                                    Text(counts[queue].map(String.init) ?? "...").font(MortTypography.title).foregroundStyle(queueTint(queue))
                                    Text(queue.title).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                MortSectionHeader(title: "Monetization overview", subtitle: "Server-calculated aggregate only; no client-side entitlement grants.")
                MortCard {
                    if monetization.isEmpty {
                        Text("No overview returned.").foregroundStyle(MortColors.textMuted)
                    } else {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            ForEach(monetization.keys.sorted(), id: \.self) { key in
                                HStack { Text(key.replacingOccurrences(of: "_", with: " ").capitalized).font(MortTypography.caption); Spacer(); Text(monetization[key]?.displayValue ?? "-").font(MortTypography.label) }
                            }
                        }
                    }
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("MORT Admin")
        .refreshable { await load() }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        var failures: [String] = []
        for queue in AdminQueue.allCases {
            do { counts[queue] = try await container.admin.queue(queue, limit: 50).count }
            catch { failures.append("\(queue.title): \(mortMessage(error))") }
        }
        do { monetization = try await container.admin.monetizationOverview() }
        catch { failures.append("Monetization: \(mortMessage(error))") }
        errorMessage = failures.first
    }

    private func queueTint(_ queue: AdminQueue) -> Color {
        switch queue {
        case .reports, .safetyPings, .messages, .personMismatch, .sexualSafety,
             .groomingSignals, .abductionConcerns, .threatsViolence,
             .propertyTheft, .accountSharing, .incidentCases,
             .evidencePreservation: MortColors.danger
        case .verifications, .adultIDReview, .teenSchoolIDReview,
             .teenAlternativeEvidence, .businessVerifications,
             .verificationAppeals, .lawfulRequests, .support, .reviews: MortColors.warning
        case .monetization: MortColors.premium
        default: MortColors.safetyBlue
        }
    }
}

struct AdminQueueView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var state: LoadState<[AdminRecord]> = .idle
    @State private var selectedAction: AdminModerationAction?
    @State private var selectedRecord: AdminRecord?
    @State private var isWorking = false
    @State private var message: String?
    let queue: AdminQueue

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading \(queue.title.lowercased())")
            case let .failed(error): MortErrorState(message: error) { Task { await load() } }
            case let .loaded(records) where records.isEmpty:
                MortEmptyState(title: "Queue is clear", message: "No records are visible in \(queue.title.lowercased()).", systemImage: "checkmark.circle")
            case let .loaded(records):
                List(records) { record in
                    AdminRecordCard(record: record, actions: actions(for: queue)) { action in
                        selectedRecord = record
                        selectedAction = action
                    }
                    .listRowBackground(MortColors.background)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle(queue.title)
        .confirmationDialog("Confirm admin action", isPresented: Binding(get: { selectedAction != nil }, set: { if !$0 { selectedAction = nil; selectedRecord = nil } })) {
            if let selectedAction {
                Button(selectedAction.title, role: selectedAction.destructive ? .destructive : nil) { Task { await perform(selectedAction) } }
            }
            Button("Cancel", role: .cancel) { selectedAction = nil; selectedRecord = nil }
        } message: { Text("This writes a real moderation state through the admin repository. Server-side authorization remains required.") }
        .alert("Admin action", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.admin.queue(queue, limit: 50)) }
        catch { state = .failed(mortMessage(error)) }
    }

    private func actions(for queue: AdminQueue) -> [AdminModerationAction] {
        switch queue {
        case .users: [.activateUser, .restrictUser]
        case .jobs: [.pauseJob, .cancelJob]
        case .reports: [.reviewReport, .resolveReport, .dismissReport]
        case .verifications, .adultIDReview, .teenSchoolIDReview,
             .teenAlternativeEvidence, .verificationAppeals:
            [.approveIdentity, .requestVerificationInfo, .rejectIdentity]
        case .businessVerifications: [.approveVerification, .rejectVerification]
        case .personMismatch, .sexualSafety, .groomingSignals,
             .abductionConcerns, .threatsViolence, .propertyTheft,
             .accountSharing, .incidentCases, .evidencePreservation:
            [.triageIncident, .investigateIncident, .resolveIncident]
        case .support: [.openSupport, .resolveSupport]
        case .reviews: [.approveReview, .rejectReview]
        case .lawfulRequests, .messages, .safetyPings, .monetization, .actionLogs: []
        }
    }

    private func perform(_ action: AdminModerationAction) async {
        guard let selectedRecord else { return }
        isWorking = true
        defer { isWorking = false; selectedAction = nil; self.selectedRecord = nil }
        do {
            switch action {
            case .activateUser, .restrictUser:
                guard let id = UUID(uuidString: selectedRecord.id) else { throw MortError.invalidResponse }
                try await container.admin.restrictUser(id: id, status: action == .activateUser ? "active" : "restricted")
            case .approveIdentity, .requestVerificationInfo, .rejectIdentity:
                guard let id = UUID(uuidString: selectedRecord.id) else { throw MortError.invalidResponse }
                let identityAction = switch action {
                case .approveIdentity: "approve"
                case .requestVerificationInfo: "request_information"
                default: "reject"
                }
                let decisionCode = switch action {
                case .approveIdentity: "restricted_evidence_review_completed"
                case .requestVerificationInfo: "additional_evidence_required"
                default: "identity_requirements_not_satisfied"
                }
                try await container.admin.reviewIdentity(id: id, action: identityAction, decisionCode: decisionCode)
            case .triageIncident, .investigateIncident, .resolveIncident:
                guard let id = UUID(uuidString: selectedRecord.id) else { throw MortError.invalidResponse }
                let status = switch action {
                case .triageIncident: "triage"
                case .investigateIncident: "investigating"
                default: "resolved"
                }
                let publicNote = switch action {
                case .triageIncident: "A restricted safety reviewer began triage."
                case .investigateIncident: "The safety team is reviewing the available information."
                default: "The current safety review is resolved. Appeal options remain available where applicable."
                }
                try await container.admin.updateIncident(id: id, status: status, publicNote: publicNote, restrictedNote: nil)
            default:
                try await container.admin.update(queue: queue, id: selectedRecord.id, values: action.values)
            }
            message = "\(action.title) completed."
            await load()
        } catch { message = mortMessage(error) }
    }
}

private struct AdminRecordCard: View {
    let record: AdminRecord
    let actions: [AdminModerationAction]
    let choose: (AdminModerationAction) -> Void

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack {
                    Text(primaryTitle).font(MortTypography.section)
                    Spacer()
                    if let status = record.text("status") ?? record.text("account_status") ?? record.text("moderation_status") {
                        MortBadge(text: status, tint: statusTint(status))
                    }
                }
                Text("ID \(record.id)").font(.system(size: 11, design: .monospaced)).foregroundStyle(MortColors.textMuted).lineLimit(1)
                ForEach(summaryKeys, id: \.self) { key in
                    if let value = record.payload[key], value != .null {
                        HStack(alignment: .top) {
                            Text(key.replacingOccurrences(of: "_", with: " ").capitalized).font(MortTypography.caption).foregroundStyle(MortColors.textMuted).frame(width: 100, alignment: .leading)
                            Text(value.displayValue).font(MortTypography.caption).lineLimit(4)
                        }
                    }
                }
                if !actions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(actions, id: \.rawValue) { action in
                                Button(action.title) { choose(action) }
                                    .buttonStyle(.bordered)
                                    .tint(action.destructive ? MortColors.danger : MortColors.neon)
                            }
                        }
                    }
                }
            }
        }
    }

    private var primaryTitle: String {
        record.text("case_number") ?? record.text("title") ?? record.text("display_name") ?? record.text("business_name") ?? record.text("subject") ?? record.text("reason") ?? "Admin record"
    }
    private var summaryKeys: [String] {
        ["role", "account_role", "evidence_route", "appeal_status", "category",
         "severity", "priority", "preservation_status", "business_type", "body",
         "details", "scanner_reason", "created_at"]
    }
}

private enum AdminModerationAction: String, Equatable {
    case activateUser
    case restrictUser
    case pauseJob
    case cancelJob
    case reviewReport
    case resolveReport
    case dismissReport
    case approveIdentity
    case requestVerificationInfo
    case rejectIdentity
    case approveVerification
    case rejectVerification
    case triageIncident
    case investigateIncident
    case resolveIncident
    case openSupport
    case resolveSupport
    case approveReview
    case rejectReview

    var title: String {
        switch self {
        case .activateUser: "Activate user"
        case .restrictUser: "Restrict user"
        case .pauseJob: "Pause job"
        case .cancelJob: "Cancel job"
        case .reviewReport: "Mark reviewing"
        case .resolveReport: "Resolve report"
        case .dismissReport: "Dismiss report"
        case .approveIdentity: "Approve after evidence review"
        case .requestVerificationInfo: "Request more information"
        case .rejectIdentity: "Reject identity verification"
        case .approveVerification: "Approve verification"
        case .rejectVerification: "Reject verification"
        case .triageIncident: "Begin triage"
        case .investigateIncident: "Mark investigating"
        case .resolveIncident: "Resolve incident"
        case .openSupport: "Mark in progress"
        case .resolveSupport: "Resolve ticket"
        case .approveReview: "Approve review"
        case .rejectReview: "Reject review"
        }
    }
    var destructive: Bool {
        [.restrictUser, .cancelJob, .dismissReport, .rejectIdentity,
         .rejectVerification, .resolveIncident, .rejectReview].contains(self)
    }
    var values: [String: JSONValue] {
        switch self {
        case .pauseJob: ["status": .string("paused"), "applications_open": .bool(false)]
        case .cancelJob: ["status": .string("canceled"), "applications_open": .bool(false)]
        case .reviewReport: ["status": .string("reviewing")]
        case .resolveReport: ["status": .string("resolved")]
        case .dismissReport: ["status": .string("dismissed")]
        case .approveVerification: ["status": .string("approved")]
        case .rejectVerification: ["status": .string("rejected")]
        case .openSupport: ["status": .string("in_progress")]
        case .resolveSupport: ["status": .string("resolved")]
        case .approveReview: ["moderation_status": .string("approved")]
        case .rejectReview: ["moderation_status": .string("rejected")]
        case .activateUser, .restrictUser, .approveIdentity,
             .requestVerificationInfo, .rejectIdentity, .triageIncident,
             .investigateIncident, .resolveIncident: [:]
        }
    }
}
