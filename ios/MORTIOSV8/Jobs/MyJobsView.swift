//
//  MyJobsView.swift
//  MORT iOS V8 — Jobs
//
//  The jobs tab: everything the user is involved in, grouped by what needs
//  attention.
//

import SwiftUI

struct MyJobsView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var jobs: LoadState<[MortJob]> = .idle
    @State private var filter: JobFilter = .active

    enum JobFilter: String, CaseIterable, Identifiable {
        case active, upcoming, finished
        var id: String { rawValue }
        var label: String {
            switch self {
            case .active: "Active"
            case .upcoming: "Upcoming"
            case .finished: "Finished"
            }
        }

        var states: [MortJobState] {
            switch self {
            case .active: [.funded, .inProgress, .awaitingCompletion, .completed, .accepted]
            case .upcoming: [.open, .applied, .scheduled]
            case .finished: [.settled, .cancelled, .disputed]
            }
        }
    }

    private var filtered: [MortJob] {
        (jobs.value ?? []).filter { filter.states.contains($0.state) }
    }

    var body: some View {
        MortScreen(atmosphereIntensity: 0.8) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                ScrollView(.horizontal) {
                    HStack(spacing: MortSpace.s2) {
                        ForEach(JobFilter.allCases) { option in
                            MortChip(label: option.label, isSelected: filter == option) {
                                filter = option
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                switch jobs {
                case .idle, .loading:
                    MortSkeletonList(rows: 4)
                case .failed(let error):
                    MortErrorState(message: error.userMessage) { Task { await load() } }
                case .loaded, .offlineCache:
                    if jobs.isOffline {
                        MortOfflineBanner { Task { await load() } }
                    }
                    if filtered.isEmpty {
                        MortEmptyState(
                            symbol: "briefcase",
                            title: emptyTitle,
                            message: emptyMessage,
                            actionTitle: user.role == .adult ? "Post a job" : "Find work"
                        ) {
                            nav.push(user.role == .adult ? .jobCreate : .myApplications)
                        }
                    } else {
                        ForEach(filtered) { job in
                            JobCard(job: job, showsState: true) {
                                nav.push(.jobDetail(job.id))
                            }
                        }
                    }
                }

                if user.role == .teen {
                    MortGhostButton(title: "My applications", symbol: "paperplane") {
                        nav.push(.myApplications)
                    }
                }

                MortGhostButton(title: "Job & payment history", symbol: "clock.arrow.circlepath") {
                    nav.push(.history)
                }
            }
        }
        .navigationTitle("Jobs")
        .task { if case .idle = jobs { await load() } }
        .refreshable { await load() }
    }

    private var emptyTitle: String {
        switch filter {
        case .active: "Nothing active"
        case .upcoming: "Nothing upcoming"
        case .finished: "Nothing finished yet"
        }
    }

    private var emptyMessage: String {
        switch (filter, user.role) {
        case (.active, .adult): "Jobs you've funded and that are underway show up here."
        case (.active, _): "Once a job is funded and you start it, it lives here."
        case (.upcoming, .adult): "Open posts and scheduled jobs appear here."
        case (.upcoming, _): "Applications and scheduled jobs appear here."
        case (.finished, _): "Settled, cancelled and disputed jobs stay here for your records."
        }
    }

    private func load() async {
        jobs = .loading
        do {
            jobs = .loaded(try await mort.jobs.myJobs(role: user.role))
        } catch let error as MortError {
            jobs = .failed(error)
        } catch {
            jobs = .failed(.unknown)
        }
    }
}

struct MyApplicationsView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var applications: LoadState<[MortApplication]> = .idle

    var body: some View {
        MortScreen(
            title: "My applications",
            subtitle: "Where each one stands.",
            atmosphereIntensity: 0.7
        ) {
            switch applications {
            case .idle, .loading:
                MortSkeletonList(rows: 3)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let items), .offlineCache(let items):
                if items.isEmpty {
                    MortEmptyState(
                        symbol: "paperplane",
                        title: "No applications yet",
                        message: "When you apply for a job, you can track it here."
                    )
                } else {
                    VStack(spacing: MortSpace.s3) {
                        ForEach(items) { application in
                            MortCard {
                                VStack(alignment: .leading, spacing: MortSpace.s3) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(application.jobTitle)
                                                .mortTitle()
                                                .lineLimit(2)
                                            Text("Applied \(application.submittedAgo)")
                                                .mortMicro()
                                        }
                                        Spacer(minLength: MortSpace.s2)
                                        MortStatusPill(
                                            tone: application.state.tone,
                                            symbol: application.state.symbol,
                                            label: application.state.label,
                                            compact: true
                                        )
                                    }
                                    Text(application.message)
                                        .mortBody()
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                    MortGhostButton(title: "View job", symbol: "briefcase") {
                                        nav.push(.jobDetail(application.jobId))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Applications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        applications = .loading
        do {
            applications = .loaded(try await mort.applications.myApplications())
        } catch let error as MortError {
            applications = .failed(error)
        } catch {
            applications = .failed(.unknown)
        }
    }
}

struct JobApplyView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var error: MortError?
    @State private var submitted = false

    var body: some View {
        MortScreen(
            title: submitted ? "Application sent" : "Apply for this job",
            subtitle: submitted
                ? "The poster can see your profile and message now."
                : "Tell them why you're a good fit. Short and specific wins.",
            atmosphereIntensity: 0.7
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if submitted {
                    MortStatusPanel(
                        tone: .success,
                        symbol: "checkmark.circle",
                        label: "APPLICATION SENT",
                        detail: "You'll get a notification if they pick you. The job only starts once they fund it."
                    )
                } else {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    MortTextArea(
                        label: "Your message",
                        placeholder: "e.g. I've done three lawns on your street. I can start at 10 and should be done in about two hours.",
                        text: $message,
                        minHeight: 140,
                        helpText: "Don't share your phone number or address here."
                    )
                    MortNote(
                        text: "MORT never asks you to work before a job is funded.",
                        tone: .info,
                        symbol: "lock.shield"
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                if submitted {
                    MortPrimaryButton(title: "Done") { nav.pop() }
                } else {
                    MortPrimaryButton(
                        title: "Send application",
                        symbol: "paperplane.fill",
                        isBusy: isSubmitting,
                        isEnabled: message.count >= 10 && !isSubmitting
                    ) {
                        Task { await submit() }
                    }
                }
            }
        }
        .navigationTitle("Apply")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        isSubmitting = true
        error = nil
        do {
            _ = try await mort.applications.apply(jobId: jobId, message: message)
            submitted = true
            MortHaptic.success()
        } catch let failure as MortError {
            error = failure
            MortHaptic.failure()
        } catch {
            self.error = .unknown
        }
        isSubmitting = false
    }
}

struct JobApplicantsView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var applications: LoadState<[MortApplication]> = .idle
    @State private var selecting: String?

    var body: some View {
        MortScreen(
            title: "Applicants",
            subtitle: "Pick someone, then fund the job so they can start.",
            atmosphereIntensity: 0.7
        ) {
            switch applications {
            case .idle, .loading:
                MortSkeletonList(rows: 3)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let items), .offlineCache(let items):
                if items.isEmpty {
                    MortEmptyState(
                        symbol: "person.2",
                        title: "No applicants yet",
                        message: "Teens nearby can see your job. We'll notify you when someone applies."
                    )
                } else {
                    VStack(spacing: MortSpace.s3) {
                        HistoryResultCount(count: items.count)
                        ForEach(items) { application in
                            ApplicantRow(
                                application: application,
                                onOpen: { nav.push(.publicProfile(application.applicantHandle)) },
                                onSelect: application.state == .accepted ? nil : {
                                    Task { await select(application) }
                                }
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Applicants")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        applications = .loading
        do {
            applications = .loaded(try await mort.applications.applications(jobId: jobId))
        } catch let error as MortError {
            applications = .failed(error)
        } catch {
            applications = .failed(.unknown)
        }
    }

    private func select(_ application: MortApplication) async {
        selecting = application.id
        defer { selecting = nil }
        do {
            try await mort.applications.selectApplicant(applicationId: application.id)
            MortHaptic.success()
            // Next step is funding — the job cannot start until it's funded.
            nav.push(.paymentReview(jobId))
        } catch {
            MortHaptic.failure()
        }
    }
}

#Preview {
    NavigationStack { MyJobsView(user: MortFixtures.teen) }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
