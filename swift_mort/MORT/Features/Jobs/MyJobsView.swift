import SwiftUI

struct MyJobsView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var state: LoadState<[Job]> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading your jobs")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(jobs) where jobs.isEmpty:
                MortEmptyState(title: "No jobs yet", message: "Post a clear, safe local job when you are ready.", systemImage: "briefcase")
            case let .loaded(jobs):
                List(jobs) { job in
                    Button { router.push(.jobManagement(job.id)) } label: {
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                                HStack { MortBadge(text: job.status, tint: statusTint(job.status)); Spacer(); Text(job.payDisplay).foregroundStyle(MortColors.neon) }
                                Text(job.title).font(MortTypography.section).foregroundStyle(MortColors.text)
                                Label(job.scheduleDisplay, systemImage: "calendar").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(MortColors.background)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("My jobs")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { router.push(.jobWizard(nil)) } label: { Image(systemName: "plus") } } }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.jobs.listMine()) }
        catch { state = .failed(mortMessage(error)) }
    }
}

struct JobManagementView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var jobState: LoadState<Job> = .idle
    @State private var events: [JobStatusEvent] = []
    @State private var boostStatus = JobBoostStatus.empty
    @State private var isWorking = false
    @State private var pendingDestructiveAction: JobAction?
    @State private var notice: String?
    let jobID: UUID

    var body: some View {
        Group {
            switch jobState {
            case .idle, .loading: MortLoadingState(label: "Loading job controls")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(job):
                ScrollView {
                    VStack(alignment: .leading, spacing: MortSpacing.lg) {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            MortBadge(text: job.status, tint: statusTint(job.status))
                            Text(job.title).font(MortTypography.title)
                            Text("\(job.payDisplay) | \(job.scheduleDisplay)").foregroundStyle(MortColors.textMuted)
                        }
                        actionGrid(job)
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                                HStack { Text("Job boost credits").font(MortTypography.label); Spacer(); MortBadge(text: "\(boostStatus.availableCredits) available", tint: MortColors.premium) }
                                Text("Boosts are optional visibility credits. They never bypass moderation, verification, safety review, or ranking safeguards.")
                                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                MortSecondaryButton(title: boostStatus.availableCredits > 0 ? "Use one boost" : "View Job Boost", icon: "bolt.fill") {
                                    if boostStatus.availableCredits > 0 { Task { await useBoost(job.id) } }
                                    else { router.push(.monetization("job_boost")) }
                                }
                            }
                        }
                        MortSecondaryButton(title: "Review applicants", icon: "person.2.fill") { router.push(.applications(.adult)) }
                        MortSectionHeader(title: "Job timeline")
                        if events.isEmpty {
                            Text("No status changes recorded yet.").foregroundStyle(MortColors.textMuted)
                        } else {
                            ForEach(events) { event in
                                TimelineRow(title: event.toStatus.replacingOccurrences(of: "_", with: " ").capitalized, detail: DateFormatting.displayDateTime(event.createdAt))
                            }
                        }
                    }
                    .padding(MortSpacing.lg)
                }
            }
        }
        .navigationTitle("Manage job")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Confirm job action", isPresented: Binding(get: { pendingDestructiveAction != nil }, set: { if !$0 { pendingDestructiveAction = nil } })) {
            if let action = pendingDestructiveAction {
                Button(action.title, role: .destructive) { Task { await perform(action) } }
            }
            Button("Cancel", role: .cancel) { pendingDestructiveAction = nil }
        } message: {
            Text("This action changes the job and may close applications. The backend validates whether it is allowed.")
        }
        .alert("MORT", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func actionGrid(_ job: Job) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: MortSpacing.sm)], spacing: MortSpacing.sm) {
            if ["draft", "open", "paused"].contains(job.status) {
                JobActionButton(action: .edit, working: isWorking) { router.push(.jobWizard(job.id)) }
            }
            if job.status == "open" {
                JobActionButton(action: .pause, working: isWorking) { Task { await perform(.pause) } }
                JobActionButton(action: .closeApplications, working: isWorking) { Task { await perform(.closeApplications) } }
            }
            if job.status == "paused" {
                JobActionButton(action: .resume, working: isWorking) { Task { await perform(.resume) } }
            }
            JobActionButton(action: .duplicate, working: isWorking) { Task { await perform(.duplicate) } }
            if job.status == "draft" {
                JobActionButton(action: .deleteDraft, working: isWorking) { pendingDestructiveAction = .deleteDraft }
            }
            if ["open", "paused", "assigned", "in_progress"].contains(job.status) {
                JobActionButton(action: .cancel, working: isWorking) { pendingDestructiveAction = .cancel }
            }
        }
    }

    private func load() async {
        jobState = .loading
        do {
            guard let job = try await container.jobs.job(id: jobID) else { throw MortError.invalidInput("This job is no longer available.") }
            jobState = .loaded(job)
            events = try await container.jobs.statusEvents(jobID: jobID)
            boostStatus = try await container.monetization.jobBoostStatus()
        } catch { jobState = .failed(mortMessage(error)) }
    }

    private func perform(_ action: JobAction) async {
        guard let rpcAction = action.rpcAction else { return }
        isWorking = true
        defer { isWorking = false; pendingDestructiveAction = nil }
        do {
            let result = try await container.jobs.manage(id: jobID, action: rpcAction)
            if action == .deleteDraft {
                router.pop()
            } else if action == .duplicate, let result {
                router.push(.jobWizard(result.id))
            } else {
                notice = "Job updated."
                await load()
            }
        } catch { notice = mortMessage(error) }
    }

    private func useBoost(_ id: UUID) async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.monetization.consumeJobBoost(jobID: id)
            boostStatus = try await container.monetization.jobBoostStatus()
            notice = "Job boost applied. Moderation and safety rules are unchanged."
        } catch { notice = mortMessage(error) }
    }
}

private enum JobAction: String, Equatable {
    case edit
    case pause
    case resume
    case closeApplications
    case duplicate
    case deleteDraft
    case cancel

    var title: String {
        switch self {
        case .edit: "Edit"
        case .pause: "Pause"
        case .resume: "Resume"
        case .closeApplications: "Close applications"
        case .duplicate: "Duplicate"
        case .deleteDraft: "Delete draft"
        case .cancel: "Cancel job"
        }
    }
    var icon: String {
        switch self {
        case .edit: "pencil"
        case .pause: "pause.fill"
        case .resume: "play.fill"
        case .closeApplications: "lock.fill"
        case .duplicate: "doc.on.doc.fill"
        case .deleteDraft: "trash.fill"
        case .cancel: "xmark.octagon.fill"
        }
    }
    var destructive: Bool { self == .deleteDraft || self == .cancel }
    var rpcAction: String? {
        switch self {
        case .edit: nil
        case .pause: "pause"
        case .resume: "resume"
        case .closeApplications: "close_applications"
        case .duplicate: "duplicate"
        case .deleteDraft: "delete_draft"
        case .cancel: "cancel"
        }
    }
}

private struct JobActionButton: View {
    let action: JobAction
    let working: Bool
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            Label(action.title, systemImage: action.icon)
                .font(MortTypography.caption)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(action.destructive ? MortColors.danger : MortColors.neon)
        .disabled(working)
    }
}

struct TimelineRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: MortSpacing.md) {
            Circle().fill(MortColors.neon).frame(width: 9, height: 9).padding(.top, 5)
            VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                Text(title).font(MortTypography.label)
                Text(detail).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            }
        }
    }
}

func statusTint(_ status: String) -> Color {
    switch status {
    case "open", "accepted", "completed", "approved": MortColors.neon
    case "pending", "paused", "submitted", "in_progress": MortColors.warning
    case "declined", "canceled", "rejected", "restricted": MortColors.danger
    default: MortColors.safetyBlue
    }
}
