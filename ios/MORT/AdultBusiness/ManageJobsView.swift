//
//  ManageJobsView.swift
//  MORT
//
//  Adult/Business: list of jobs they posted + applicants drill-down.
//

import SwiftUI

struct ManageJobsView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    @State private var jobs: [Job] = []
    @State private var loading = true
    @State private var showPost = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "My posted jobs", subtitle: "Manage listings and applicants", trailingSystemImage: "plus") {
                    showPost = true
                }
                content
            }
            .mortScreen()
            .navigationDestination(for: Job.self) { ApplicantsView(job: $0) }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showPost) {
                PostJobView { Task { await load() } }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView()
        } else if jobs.isEmpty {
            MortEmptyState(systemImage: "plus.rectangle.on.folder", title: "No jobs posted yet", message: "Post a safe local job and start receiving applicants.", actionTitle: "Post a job") { showPost = true }
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(jobs) { job in
                        NavigationLink(value: job) {
                            MortJobCard(job: job)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func load() async {
        guard let me = session.profile else { return }
        loading = true
        jobs = (try? await services.jobs.fetchJobs(postedBy: me.id)) ?? []
        loading = false
    }
}

struct ApplicantsView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session
    let job: Job

    @State private var applications: [JobApplication] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: MortSpacing.sm) {
                if loading {
                    MortLoadingView()
                } else if applications.isEmpty {
                    MortEmptyState(systemImage: "person.crop.circle.badge.questionmark", title: "No applicants yet", message: "When teens apply, you'll see them here.")
                } else {
                    ForEach(applications) { app in
                        NavigationLink(value: app) {
                            ApplicantRow(application: app)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(MortSpacing.md)
        }
        .mortScreen()
        .navigationTitle(job.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: JobApplication.self) { ApplicantDetailView(application: $0, reload: { await load() }) }
        .task { await load() }
    }

    private func load() async {
        loading = true
        let requesterId = session.profile?.id ?? ""
        applications = (try? await services.jobs.applications(forJob: job.id, visibleTo: requesterId)) ?? []
        loading = false
    }
}

private struct ApplicantRow: View {
    let application: JobApplication
    var body: some View {
        MortCard {
            HStack(spacing: MortSpacing.sm) {
                MortAvatar(name: application.applicantName)
                VStack(alignment: .leading, spacing: 3) {
                    Text(application.applicantName).font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                    Text(application.message.isEmpty ? "Applied" : application.message)
                        .font(MortFont.caption()).foregroundStyle(MortColor.secondaryText).lineLimit(1)
                }
                Spacer()
                MortBadge.forApplication(application.status)
            }
        }
    }
}

struct ApplicantDetailView: View {
    @Environment(\.services) private var services
    let application: JobApplication
    var reload: () async -> Void

    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.md) {
                HStack(spacing: MortSpacing.sm) {
                    MortAvatar(name: application.applicantName, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(application.applicantName).font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
                        MortBadge.forApplication(application.status)
                    }
                }
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        Text("MESSAGE").font(MortFont.tiny()).tracking(0.8).foregroundStyle(MortColor.darkSilver)
                        Text(application.message.isEmpty ? "No message provided." : application.message)
                            .font(MortFont.body()).foregroundStyle(MortColor.silver)
                    }
                }

                MortSafetyBanner(staticMessage: "Keep all communication inside MORT. Meet in safe, public, daytime settings.")

                if application.status == .pending {
                    MortButton(title: "Accept applicant", systemImage: "checkmark.circle.fill", isLoading: working) {
                        Task { await setStatus(.accepted) }
                    }
                    MortButton(title: "Decline", kind: .ghost) {
                        Task { await setStatus(.declined) }
                    }
                }
            }
            .padding(MortSpacing.md)
        }
        .mortScreen()
        .navigationTitle("Applicant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func setStatus(_ status: ApplicationStatus) async {
        working = true
        try? await services.jobs.setApplicationStatus(application, status: status)
        await reload()
        working = false
    }
}
