//
//  AdminScreens.swift
//  MORT
//
//  Reports queue, moderation queue, users, jobs, flagged messages, action log.
//

import SwiftUI

struct ReportsQueueView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    @State private var reports: [Report] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "Reports queue", subtitle: "Review and resolve reports")
                content
            }
            .mortScreen()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView()
        } else if reports.isEmpty {
            MortEmptyState(systemImage: "flag.slash", title: "No reports", message: "The queue is clear.")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(reports) { report in
                        VStack(spacing: MortSpacing.xs) {
                            ReportRow(report: report)
                            if report.status == .open || report.status == .reviewing {
                                HStack(spacing: MortSpacing.sm) {
                                    MortButton(title: "Resolve", kind: .secondary) { Task { await act(report, .resolved, "Resolved report") } }
                                    MortButton(title: "Dismiss", kind: .ghost) { Task { await act(report, .dismissed, "Dismissed report") } }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func load() async {
        loading = true
        reports = (try? await services.reports.fetchAll()) ?? []
        loading = false
    }

    private func act(_ report: Report, _ status: ReportStatus, _ label: String) async {
        try? await services.reports.setStatus(report, status: status)
        let action = AdminAction(adminName: session.profile?.displayName ?? "Admin", action: label, target: report.targetLabel)
        try? await services.admin.logAction(action)
        await load()
    }
}

struct ModerationQueueView: View {
    @Environment(\.services) private var services
    @State private var messages: [Message] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "Moderation", subtitle: "Flagged messages from the safety scanner")
                content
            }
            .mortScreen()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView()
        } else if messages.isEmpty {
            MortEmptyState(systemImage: "checkmark.shield.fill", title: "Nothing flagged", message: "Messages flagged by the safety scanner appear here.")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(messages) { message in
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpacing.xs) {
                                HStack {
                                    MortBadge(text: "Flagged", color: MortColor.warning, systemImage: "exclamationmark.triangle.fill")
                                    Spacer()
                                    Text(message.sentAt, style: .relative).font(MortFont.caption()).foregroundStyle(MortColor.darkSilver)
                                }
                                Text(message.text).font(MortFont.callout()).foregroundStyle(MortColor.silver)
                            }
                        }
                    }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func load() async {
        loading = true
        messages = (try? await services.admin.flaggedMessages()) ?? []
        loading = false
    }
}

struct AdminUsersView: View {
    @Environment(\.services) private var services
    @State private var users: [UserProfile] = []
    @State private var loading = true
    @State private var query = ""

    private var filtered: [UserProfile] {
        guard !query.isEmpty else { return users }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "Users", subtitle: "All MORT accounts")
                MortTextField(title: "Search", text: $query, placeholder: "Search by name or username", systemImage: "magnifyingglass")
                    .padding(.horizontal, MortSpacing.md)
                content
            }
            .mortScreen()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView()
        } else if filtered.isEmpty {
            MortEmptyState(systemImage: "person.slash", title: "No users found")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(filtered) { user in
                        MortCard {
                            HStack(spacing: MortSpacing.sm) {
                                MortAvatar(name: user.displayName)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName).font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                                    Text(user.handle).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                                }
                                Spacer()
                                MortBadge(text: user.role.title, color: MortColor.silver)
                            }
                        }
                    }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.top, MortSpacing.sm)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func load() async {
        loading = true
        users = (try? await services.admin.allUsers()) ?? []
        loading = false
    }
}

struct AdminJobsView: View {
    @Environment(\.services) private var services
    @State private var jobs: [Job] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: MortSpacing.sm) {
                if loading {
                    MortLoadingView()
                } else if jobs.isEmpty {
                    MortEmptyState(systemImage: "briefcase", title: "No jobs")
                } else {
                    ForEach(jobs) { MortJobCard(job: $0) }
                }
            }
            .padding(MortSpacing.md)
        }
        .mortScreen()
        .navigationTitle("All jobs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            jobs = (try? await services.admin.allJobs()) ?? []
            loading = false
        }
    }
}

struct AdminActionLogView: View {
    @Environment(\.services) private var services
    @State private var actions: [AdminAction] = []
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(spacing: MortSpacing.sm) {
                if loading {
                    MortLoadingView()
                } else if actions.isEmpty {
                    MortEmptyState(systemImage: "list.bullet.rectangle", title: "No actions logged")
                } else {
                    ForEach(actions) { ActionRow(action: $0) }
                }
            }
            .padding(MortSpacing.md)
        }
        .mortScreen()
        .navigationTitle("Action log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            actions = (try? await services.admin.actionLog()) ?? []
            loading = false
        }
    }
}
