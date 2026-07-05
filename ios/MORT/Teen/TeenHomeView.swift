//
//  TeenHomeView.swift
//  MORT
//
//  Teen tab container + dashboard.
//

import SwiftUI

struct TeenHomeView: View {
    @Environment(SessionStore.self) private var session
    @State private var selection = 0

    private let tabs = [
        MortTabItem(id: 0, title: "Home", systemImage: "house"),
        MortTabItem(id: 1, title: "Jobs", systemImage: "briefcase"),
        MortTabItem(id: 2, title: "Messages", systemImage: "bubble.left"),
        MortTabItem(id: 3, title: "Safety", systemImage: "shield"),
        MortTabItem(id: 4, title: "Profile", systemImage: "person"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case 0: TeenDashboardView(goToJobs: { selection = 1 }, goToSafety: { selection = 3 })
                case 1: JobsFeedView()
                case 2: MessagesListView()
                case 3: SafetyCheckInView()
                default: ProfileView()
                }
            }
            .frame(maxHeight: .infinity)

            MortTabBar(items: tabs, selection: $selection)
        }
        .background(MortColor.background.ignoresSafeArea())
    }
}

struct TeenDashboardView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    var goToJobs: () -> Void
    var goToSafety: () -> Void

    @State private var jobs: [Job] = []
    @State private var notifications: [NotificationItem] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    greeting
                    MortSafetyBanner(staticMessage: "Stay safe: keep chats inside MORT and only take safe daytime jobs.")
                    quickActions
                    nearbyJobs
                    if !notifications.isEmpty { recentActivity }
                }
                .padding(MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
            .mortScreen()
            .navigationDestination(for: Job.self) { JobDetailView(job: $0) }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome back,").font(MortFont.body()).foregroundStyle(MortColor.secondaryText)
            Text(session.profile?.displayName ?? "Hustler")
                .font(MortFont.largeTitle()).foregroundStyle(MortColor.primaryText)
        }
        .padding(.top, MortSpacing.sm)
    }

    private var quickActions: some View {
        HStack(spacing: MortSpacing.sm) {
            DashTile(icon: "magnifyingglass", title: "Find jobs", tint: MortColor.roseGold, action: goToJobs)
            DashTile(icon: "shield.lefthalf.filled", title: "Check in", tint: MortColor.success, action: goToSafety)
        }
    }

    private var nearbyJobs: some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            HStack {
                Text("Jobs near you").font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
                Spacer()
                Button("See all", action: goToJobs).font(MortFont.caption()).foregroundStyle(MortColor.roseGold)
            }
            if loading {
                MortLoadingView()
            } else if jobs.isEmpty {
                MortEmptyState(systemImage: "tray", title: "No safe jobs are available yet.")
            } else {
                ForEach(jobs.prefix(3)) { job in
                    NavigationLink(value: job) { MortJobCard(job: job) }.buttonStyle(.plain)
                }
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            Text("Recent activity").font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
            ForEach(notifications.prefix(2)) { MortNotificationRow(item: $0) }
        }
    }

    private func load() async {
        guard let me = session.profile else { return }
        loading = true
        jobs = (try? await services.jobs.fetchJobs()) ?? []
        notifications = (try? await services.notifications.fetch(for: me.id)) ?? []
        loading = false
    }
}

struct DashTile: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title).font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MortSpacing.md)
            .mortSurface()
        }
        .buttonStyle(.plain)
    }
}
