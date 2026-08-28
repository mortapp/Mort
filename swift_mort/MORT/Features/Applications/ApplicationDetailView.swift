import SwiftUI

struct ApplicationDetailView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var state: LoadState<MortApplication> = .idle
    @State private var events: [ApplicationStatusEvent] = []
    @State private var contractID: UUID?
    @State private var isWorking = false
    @State private var pendingAction: ApplicationAction?
    @State private var notice: String?
    let applicationID: UUID
    let mode: ApplicationListMode

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading application")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(application):
                ScrollView {
                    VStack(alignment: .leading, spacing: MortSpacing.lg) {
                        header(application)
                        proposal(application)
                        if let job = application.job { jobSummary(job) }
                        actionGrid(application)
                        MortSectionHeader(title: "Application timeline")
                        if events.isEmpty {
                            Text("No status events are visible yet.").foregroundStyle(MortColors.textMuted)
                        } else {
                            ForEach(events) { event in
                                TimelineRow(title: statusText(event.toStatus), detail: DateFormatting.displayDateTime(event.createdAt))
                            }
                        }
                        MortSafetyBanner(message: "Keep work details and communication in MORT. Report pressure to share private information or move off-platform.")
                    }
                    .padding(MortSpacing.lg)
                }
            }
        }
        .navigationTitle("Application")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case let .loaded(application) = state {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.push(.report(.user(reportUserID(application)))) } label: { Image(systemName: "flag") }
                        .accessibilityLabel("Report user")
                }
            }
        }
        .confirmationDialog("Confirm application action", isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } })) {
            if let pendingAction {
                Button(pendingAction.title, role: pendingAction.destructive ? .destructive : nil) { Task { await perform(pendingAction) } }
            }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        } message: {
            Text("The server validates ownership, role, status, guardian policy, and job state before changing anything.")
        }
        .alert("MORT", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func header(_ application: MortApplication) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortBadge(text: statusText(application.status), tint: statusTint(application.status))
            Text(application.job?.title ?? "Application").font(MortTypography.title)
            if mode == .adult {
                HStack(spacing: MortSpacing.sm) {
                    MortAvatar(displayName: application.teen?.name ?? "Applicant")
                    VStack(alignment: .leading) {
                        Text(application.teen?.name ?? "Applicant").font(MortTypography.label)
                        Text(application.teen?.verificationStatus?.capitalized ?? "Verification unknown")
                            .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    }
                }
            }
        }
    }

    private func proposal(_ application: MortApplication) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: "Proposal")
            MortCard {
                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                    Text(application.note?.nilIfBlank ?? "No written proposal was added.")
                    Label(application.availabilityConfirmed ? "Availability confirmed" : "Availability not confirmed", systemImage: "calendar.badge.checkmark")
                        .font(MortTypography.caption)
                        .foregroundStyle(application.availabilityConfirmed ? MortColors.neon : MortColors.warning)
                }
            }
        }
    }

    private func jobSummary(_ job: Job) -> some View {
        Button { router.push(.jobDetail(job.id)) } label: {
            MortCard {
                HStack {
                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        Text("Job").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        Text(job.title).font(MortTypography.label).foregroundStyle(MortColors.text)
                        Text("\(job.payDisplay) | \(job.scheduleDisplay)").font(MortTypography.caption).foregroundStyle(MortColors.neon)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(MortColors.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func actionGrid(_ application: MortApplication) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: MortSpacing.sm)], spacing: MortSpacing.sm) {
            ForEach(actions(application), id: \.rawValue) { action in
                Button {
                    if action.routeOnly { route(action, application) }
                    else if action.destructive { pendingAction = action }
                    else { Task { await perform(action) } }
                } label: {
                    Label(action.title, systemImage: action.icon)
                        .font(MortTypography.caption)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(action.destructive ? MortColors.danger : MortColors.neon)
                .disabled(isWorking)
            }
        }
    }

    private func actions(_ application: MortApplication) -> [ApplicationAction] {
        switch mode {
        case .guardian:
            guard application.status == "guardian_pending" else { return [] }
            return [.guardianApprove, .guardianReject]
        case .adult:
            var values: [ApplicationAction] = []
            if ["submitted", "adult_review"].contains(application.status) { values.append(.viewed) }
            if ["submitted", "adult_review", "viewed"].contains(application.status) { values += [.accept, .reject] }
            if application.status == "in_progress" && application.job?.proofExpected != true { values.append(.complete) }
            if application.status == "proof_submitted" { values.append(.proofReview) }
            if ["accepted", "in_progress", "proof_submitted"].contains(application.status) { values.append(.jobSafety) }
            if ["accepted", "in_progress", "proof_submitted", "completed"].contains(application.status), contractID != nil { values.append(.contract) }
            if ["accepted", "in_progress", "proof_submitted"].contains(application.status) { values.append(.message) }
            if application.status == "completed" { values.append(.review) }
            return values
        case .teen:
            var values: [ApplicationAction] = []
            if ["submitted", "guardian_pending", "adult_review", "viewed"].contains(application.status) { values.append(.withdraw) }
            if application.status == "accepted" { values += [.jobSafety, .start] }
            if ["in_progress", "proof_submitted"].contains(application.status) { values.append(.jobSafety) }
            if ["accepted", "in_progress", "proof_submitted", "completed"].contains(application.status), contractID != nil { values.append(.contract) }
            if application.status == "in_progress" { values.append(.proof) }
            if ["accepted", "in_progress", "proof_submitted"].contains(application.status) { values.append(.message) }
            if application.status == "completed" { values.append(.review) }
            return values
        }
    }

    private func route(_ action: ApplicationAction, _ application: MortApplication) {
        switch action {
        case .proof: router.push(.proofUpload(application.id))
        case .proofReview: router.push(.proofReview(application.id))
        case .message: router.push(.messages)
        case .review:
            guard let job = application.job else { return }
            let subject = mode == .adult ? application.teenID : job.posterID
            router.push(.leaveReview(jobID: job.id, subjectID: subject))
        case .jobSafety: router.push(.jobSafety(application.id))
        case .contract:
            if let contractID { router.push(.jobContract(contractID)) }
        default: break
        }
    }

    private func perform(_ action: ApplicationAction) async {
        guard let backendAction = action.backendAction else { return }
        isWorking = true
        defer { isWorking = false; pendingAction = nil }
        do {
            _ = try await container.applications.updateStatus(applicationID: applicationID, action: backendAction)
            notice = action.successMessage
            await load()
        } catch { notice = mortMessage(error) }
    }

    private func load() async {
        state = .loading
        do {
            guard let application = try await container.applications.application(id: applicationID) else {
                throw MortError.invalidInput("This application is no longer available.")
            }
            state = .loaded(application)
            events = try await container.applications.statusEvents(applicationID: applicationID)
            contractID = try await container.jobContracts.contract(applicationID: applicationID)?.id
        } catch { state = .failed(mortMessage(error)) }
    }

    private func reportUserID(_ application: MortApplication) -> UUID {
        if mode == .adult { return application.teenID }
        return application.job?.posterID ?? application.teenID
    }
}

private enum ApplicationAction: String, Equatable {
    case guardianApprove
    case guardianReject
    case viewed
    case accept
    case reject
    case withdraw
    case start
    case complete
    case proof
    case proofReview
    case message
    case review
    case jobSafety
    case contract

    var title: String {
        switch self {
        case .guardianApprove: "Approve for review"
        case .guardianReject: "Decline"
        case .viewed: "Mark viewed"
        case .accept: "Accept applicant"
        case .reject: "Decline applicant"
        case .withdraw: "Withdraw"
        case .start: "Start job"
        case .complete: "Mark complete"
        case .proof: "Upload proof"
        case .proofReview: "Review proof"
        case .message: "Message"
        case .review: "Leave review"
        case .jobSafety: "Job safety"
        case .contract: "Job agreement"
        }
    }
    var icon: String {
        switch self {
        case .guardianApprove, .accept, .complete: "checkmark.circle.fill"
        case .guardianReject, .reject: "xmark.circle.fill"
        case .viewed: "eye.fill"
        case .withdraw: "arrow.uturn.backward"
        case .start: "play.fill"
        case .proof: "arrow.up.doc.fill"
        case .proofReview: "doc.text.magnifyingglass"
        case .message: "bubble.left.fill"
        case .review: "star.fill"
        case .jobSafety: "checkmark.shield.fill"
        case .contract: "doc.text.fill"
        }
    }
    var destructive: Bool { [.guardianReject, .reject, .withdraw].contains(self) }
    var routeOnly: Bool { [.proof, .proofReview, .message, .review, .jobSafety, .contract].contains(self) }
    var backendAction: String? {
        switch self {
        case .guardianApprove: "adult_review"
        case .guardianReject: "guardian_rejected"
        case .viewed: "viewed"
        case .accept: "accepted"
        case .reject: "rejected"
        case .withdraw: "withdrawn"
        case .start: "in_progress"
        case .complete: "completed"
        case .proof, .proofReview, .message, .review, .jobSafety, .contract: nil
        }
    }
    var successMessage: String {
        switch self {
        case .guardianApprove: "Application approved for poster review."
        case .guardianReject: "Application declined by guardian."
        case .viewed: "Application marked viewed."
        case .accept: "Applicant accepted and job assigned."
        case .reject: "Application declined."
        case .withdraw: "Application withdrawn."
        case .start: "Job marked in progress."
        case .complete: "Job and application marked complete."
        case .proof, .proofReview, .message, .review, .jobSafety, .contract: ""
        }
    }
}

func statusText(_ status: String) -> String {
    switch status {
    case "guardian_pending": "Guardian review"
    case "adult_review": "Ready for poster review"
    case "viewed": "Viewed by poster"
    case "accepted": "Accepted"
    case "rejected": "Declined"
    case "guardian_rejected": "Declined by guardian"
    case "withdrawn": "Withdrawn"
    case "in_progress": "Work in progress"
    case "proof_submitted": "Proof submitted"
    case "completed": "Completed"
    default: status.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
