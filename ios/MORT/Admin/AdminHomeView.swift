//
//  AdminHomeView.swift
//  MORT
//
//  Admin tab container + dashboard.
//

import SwiftUI

struct AdminHomeView: View {
    @State private var selection = 0

    private let tabs = [
        MortTabItem(id: 0, title: "Overview", systemImage: "square.grid.2x2"),
        MortTabItem(id: 1, title: "Reports", systemImage: "flag"),
        MortTabItem(id: 2, title: "Moderate", systemImage: "checkmark.shield"),
        MortTabItem(id: 3, title: "Users", systemImage: "person.3"),
        MortTabItem(id: 4, title: "Profile", systemImage: "person"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case 0: AdminDashboardView(goToReports: { selection = 1 }, goToModeration: { selection = 2 }, goToUsers: { selection = 3 })
                case 1: ReportsQueueView()
                case 2: ModerationQueueView()
                case 3: AdminUsersView()
                default: ProfileView()
                }
            }
            .frame(maxHeight: .infinity)

            MortTabBar(items: tabs, selection: $selection)
        }
        .background(MortColor.background.ignoresSafeArea())
    }
}

struct AdminDashboardView: View {
    @Environment(\.services) private var services

    var goToReports: () -> Void
    var goToModeration: () -> Void
    var goToUsers: () -> Void

    @State private var reports: [Report] = []
    @State private var flagged: [Message] = []
    @State private var users: [UserProfile] = []
    @State private var jobs: [Job] = []
    @State private var actions: [AdminAction] = []
    @State private var loading = true
    @State private var showJobs = false
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    Text("Admin").font(MortFont.largeTitle()).foregroundStyle(MortColor.primaryText)
                        .padding(.top, MortSpacing.sm)
                    MortSafetyBanner(staticMessage: "Moderate fairly. Protect minors first. Every action is logged.")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MortSpacing.sm) {
                        MetricTile(value: "\(reports.filter { $0.status == .open }.count)", label: "Open reports", icon: "flag.fill", tint: MortColor.danger, action: goToReports)
                        MetricTile(value: "\(flagged.count)", label: "Flagged messages", icon: "exclamationmark.bubble.fill", tint: MortColor.warning, action: goToModeration)
                        MetricTile(value: "\(users.count)", label: "Users", icon: "person.3.fill", tint: MortColor.roseGold, action: goToUsers)
                        MetricTile(value: "\(jobs.count)", label: "Jobs", icon: "briefcase.fill", tint: MortColor.silver) { showJobs = true }
                    }

                    Text("Recent admin actions").font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
                    if actions.isEmpty {
                        Text("No actions yet.").font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                    } else {
                        ForEach(actions.prefix(4)) { ActionRow(action: $0) }
                        MortButton(title: "View full action log", kind: .ghost) { showLog = true }
                    }
                }
                .padding(MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
            .mortScreen()
            .navigationDestination(isPresented: $showJobs) { AdminJobsView() }
            .navigationDestination(isPresented: $showLog) { AdminActionLogView() }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        loading = true
        reports = (try? await services.reports.fetchAll()) ?? []
        flagged = (try? await services.admin.flaggedMessages()) ?? []
        users = (try? await services.admin.allUsers()) ?? []
        jobs = (try? await services.admin.allJobs()) ?? []
        actions = (try? await services.admin.actionLog()) ?? []
        loading = false
    }
}

private struct MetricTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: MortSpacing.xs) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                Text(value).font(MortFont.title()).foregroundStyle(MortColor.primaryText)
                Text(label).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MortSpacing.md)
            .mortSurface()
        }
        .buttonStyle(.plain)
    }
}

struct ActionRow: View {
    let action: AdminAction
    var body: some View {
        MortCard {
            HStack(spacing: MortSpacing.sm) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(MortColor.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(action.action): \(action.target)").font(MortFont.callout()).foregroundStyle(MortColor.primaryText)
                    Text("by \(action.adminName)").font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                }
                Spacer()
                Text(action.createdAt, style: .relative).font(MortFont.caption()).foregroundStyle(MortColor.darkSilver)
            }
        }
    }
}

