import SwiftUI

struct JobDetailView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var state: LoadState<Job> = .idle
    @State private var eligibility: LoadState<ApplicationEligibility> = .idle
    @State private var isSaved = false
    @State private var showingProposal = false
    @State private var notice: String?
    let jobID: UUID

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                MortLoadingState(label: "Loading job")
            case let .failed(message):
                MortErrorState(message: message) { Task { await load() } }
            case let .loaded(job):
                ScrollView {
                    VStack(alignment: .leading, spacing: MortSpacing.lg) {
                        header(job)
                        facts(job)
                        poster(job)
                        detailSection("Description", job.description)
                        workDetails(job)
                        requirements(job)
                        safety(job)
                        payment(job)
                        eligibilityView(job)
                    }
                    .padding(MortSpacing.lg)
                    .padding(.bottom, 90)
                }
                .safeAreaInset(edge: .bottom) { actionBar(job) }
            }
        }
        .navigationTitle("Job")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { Task { await toggleSaved() } } label: { Image(systemName: isSaved ? "bookmark.fill" : "bookmark") }
                    .accessibilityLabel(isSaved ? "Remove saved job" : "Save job")
                Button { router.push(.report(.job(jobID))) } label: { Image(systemName: "flag") }
                    .accessibilityLabel("Report job")
            }
        }
        .sheet(isPresented: $showingProposal) {
            if case let .loaded(job) = state {
                ApplicationProposalSheet(job: job) { note, confirmed in
                    try await container.applications.apply(jobID: job.id, note: note, availabilityConfirmed: confirmed, portfolioIDs: [])
                } onComplete: { application in
                    showingProposal = false
                    router.push(.applicationDetail(application.id, .teen))
                }
            }
        }
        .alert("MORT", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func header(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            HStack {
                MortBadge(text: job.category, tint: MortColors.safetyBlue)
                MortBadge(text: job.status, tint: job.isOpen ? MortColors.neon : MortColors.warning)
                Spacer()
            }
            Text(job.title).font(MortTypography.title)
            Text(job.payDisplay).font(MortTypography.section).foregroundStyle(MortColors.neon)
            if let summary = job.summary?.nilIfBlank { Text(summary).foregroundStyle(MortColors.textMuted) }
        }
    }

    private func facts(_ job: Job) -> some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                Label(job.locationText, systemImage: "mappin.and.ellipse")
                Label(job.scheduleDisplay, systemImage: "calendar")
                Label(job.scheduleType.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: "clock")
                Label("\(job.workersNeeded) worker\(job.workersNeeded == 1 ? "" : "s")", systemImage: "person.2")
                if job.requiresGuardianApproval {
                    Label("Guardian approval required for this job", systemImage: "person.2.badge.gearshape")
                        .foregroundStyle(MortColors.warning)
                }
            }
            .font(MortTypography.label)
        }
    }

    private func poster(_ job: Job) -> some View {
        MortCard {
            HStack(spacing: MortSpacing.md) {
                MortAvatar(displayName: job.poster?.name ?? "Job poster")
                VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                    Text(job.poster?.name ?? "MORT job poster").font(MortTypography.label)
                    Label(job.posterVerified ? "Verification approved" : "Not verified", systemImage: job.posterVerified ? "checkmark.seal.fill" : "questionmark.diamond")
                        .font(MortTypography.caption)
                        .foregroundStyle(job.posterVerified ? MortColors.neon : MortColors.textMuted)
                }
            }
        }
    }

    private func workDetails(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: "Work details")
            MortCard {
                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                    detailLine("Environment", job.workEnvironment)
                    detailLine("Experience", job.experienceLevel)
                    if let minutes = job.estimatedDurationMinutes { detailLine("Estimated time", "\(minutes) minutes") }
                    if let equipment = job.equipmentProvided { detailLine("Provided", equipment) }
                    if let brings = job.equipmentWorkerBrings { detailLine("Bring", brings) }
                    if let instructions = job.specialInstructions { detailLine("Instructions", instructions) }
                }
            }
        }
    }

    private func requirements(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: "Requirements")
            MortCard {
                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                    detailLine("Age", "\(job.teenMinAge)-\(job.teenMaxAge)")
                    detailLine("Verification", job.verificationRequirement.replacingOccurrences(of: "_", with: " "))
                    if !job.skillsNeeded.isEmpty { detailLine("Skills", job.skillsNeeded.joined(separator: ", ")) }
                    if !job.physicalRequirements.isEmpty { detailLine("Physical", job.physicalRequirements.joined(separator: ", ")) }
                    detailLine("Proof", job.proofExpected ? "Expected after work" : "Not required")
                }
            }
        }
    }

    private func safety(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: "Safety")
            MortSafetyBanner(message: job.safetyNotes?.nilIfBlank ?? "Keep communication in MORT, confirm the work and general location, and leave any situation that feels unsafe.")
            Text("Verification is a limited trust signal, not a guarantee. MORT does not replace emergency services.")
                .font(MortTypography.caption)
                .foregroundStyle(MortColors.textMuted)
        }
    }

    private func payment(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: "Payment")
            MortAlertBanner(
                title: "Preference only",
                message: "\(job.payDisplay), \(job.paymentTiming.replacingOccurrences(of: "_", with: " ")). MORT does not process payments, hold funds, provide escrow, or guarantee payment.",
                tint: MortColors.warning,
                icon: "dollarsign.trianglehead.counterclockwise.rotate.90"
            )
        }
    }

    @ViewBuilder
    private func eligibilityView(_ job: Job) -> some View {
        if session.profile?.role == .teen {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                MortSectionHeader(title: "Eligibility")
                switch eligibility {
                case .idle, .loading: ProgressView().tint(MortColors.neon)
                case let .failed(message): MortAlertBanner(title: "Could not confirm eligibility", message: message)
                case let .loaded(value):
                    MortAlertBanner(
                        title: value.eligible ? "You can apply" : "Action needed",
                        message: value.message,
                        tint: value.eligible ? MortColors.neon : MortColors.warning,
                        icon: value.eligible ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                    )
                    if value.guardianRequiredForThisJob {
                        Text(value.guardianLinked ? "Your linked guardian can approve this job." : "Link a guardian before applying to this specific job.")
                            .font(MortTypography.caption)
                            .foregroundStyle(MortColors.textMuted)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionBar(_ job: Job) -> some View {
        HStack {
            if session.userID == job.posterID {
                MortPrimaryButton(title: "Manage job", icon: "slider.horizontal.3") { router.push(.jobManagement(job.id)) }
            } else if session.profile?.role == .teen {
                MortPrimaryButton(
                    title: "Apply in MORT",
                    icon: "paperplane.fill",
                    isDisabled: !canApply(job)
                ) { showingProposal = true }
            } else {
                Text("Teen accounts apply to jobs. You can still report unsafe content.")
                    .font(MortTypography.caption)
                    .foregroundStyle(MortColors.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(MortSpacing.md)
        .background(.ultraThinMaterial)
    }

    private func detailSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: title)
            Text(content).foregroundStyle(MortColors.textSoft)
        }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(MortTypography.caption).foregroundStyle(MortColors.textMuted).frame(width: 92, alignment: .leading)
            Text(value.replacingOccurrences(of: "_", with: " ").capitalized).font(MortTypography.label)
        }
    }

    private func canApply(_ job: Job) -> Bool {
        guard job.isOpen else { return false }
        if case let .loaded(value) = eligibility { return value.eligible }
        return false
    }

    private func load() async {
        state = .loading
        do {
            guard let job = try await container.jobs.job(id: jobID) else { throw MortError.invalidInput("This job is no longer available.") }
            state = .loaded(job)
            isSaved = try await container.savedJobs.isSaved(jobID: jobID)
            if session.profile?.role == .teen {
                eligibility = .loading
                do { eligibility = .loaded(try await container.applications.eligibility(jobID: jobID)) }
                catch { eligibility = .failed(mortMessage(error)) }
            }
        } catch { state = .failed(mortMessage(error)) }
    }

    private func toggleSaved() async {
        do {
            if isSaved { try await container.savedJobs.remove(jobID: jobID) }
            else { try await container.savedJobs.save(jobID: jobID) }
            isSaved.toggle()
        } catch { notice = mortMessage(error) }
    }
}

private struct ApplicationProposalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let job: Job
    let submit: (String?, Bool) async throws -> MortApplication
    let onComplete: (MortApplication) -> Void
    @State private var note = ""
    @State private var availabilityConfirmed = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.lg) {
                    MortSectionHeader(title: job.title, subtitle: job.payDisplay)
                    MortTextField(title: "Proposal", text: $note, prompt: "Explain why you are a good fit and ask any work questions.", axis: .vertical)
                    Toggle("I reviewed the schedule and I am available.", isOn: $availabilityConfirmed).tint(MortColors.neon)
                    MortSafetyBanner(message: "Keep contact, location planning, and job details inside MORT. Never pay to apply.")
                    MortPrimaryButton(title: "Submit application", icon: "paperplane.fill", isLoading: isWorking, isDisabled: !availabilityConfirmed) {
                        Task { await submitApplication() }
                    }
                }
                .padding(MortSpacing.lg)
            }
            .navigationTitle("Apply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .alert("Application not sent", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .mortScreen()
        }
    }

    private func submitApplication() async {
        isWorking = true
        defer { isWorking = false }
        do { onComplete(try await submit(note.nilIfBlank, availabilityConfirmed)) }
        catch { errorMessage = mortMessage(error) }
    }
}
