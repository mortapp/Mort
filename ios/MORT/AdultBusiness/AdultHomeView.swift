//
//  AdultHomeView.swift
//  MORT
//
//  Adult/Business tab container + dashboard.
//

import SwiftUI

struct AdultHomeView: View {
    @State private var selection = 0

    private let tabs = [
        MortTabItem(id: 0, title: "Home", systemImage: "house"),
        MortTabItem(id: 1, title: "My jobs", systemImage: "briefcase"),
        MortTabItem(id: 2, title: "Messages", systemImage: "bubble.left"),
        MortTabItem(id: 3, title: "Alerts", systemImage: "bell"),
        MortTabItem(id: 4, title: "Profile", systemImage: "person"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case 0: AdultDashboardView(goToJobs: { selection = 1 })
                case 1: ManageJobsView()
                case 2: MessagesListView()
                case 3: NotificationsView()
                default: ProfileView()
                }
            }
            .frame(maxHeight: .infinity)

            MortTabBar(items: tabs, selection: $selection)
        }
        .background(MortColor.background.ignoresSafeArea())
    }
}

struct AdultDashboardView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    var goToJobs: () -> Void

    @State private var jobs: [Job] = []
    @State private var loading = true
    @State private var showPost = false
    @State private var showDisputes = false

    private var isBusiness: Bool { session.currentRole == .business }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    header
                    MortSafetyBanner(staticMessage: "Post only safe, legal, daytime jobs. MORT scans posts and removes unsafe activity.")
                    quickActions
                    overview
                }
                .padding(MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
            .mortScreen()
            .navigationDestination(isPresented: $showDisputes) { ReportsDisputesView() }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showPost) { PostJobView { Task { await load() } } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isBusiness ? "Business dashboard" : "Welcome back,")
                .font(MortFont.body()).foregroundStyle(MortColor.secondaryText)
            Text(session.profile?.displayName ?? "Poster")
                .font(MortFont.largeTitle()).foregroundStyle(MortColor.primaryText)
        }
        .padding(.top, MortSpacing.sm)
    }

    private var quickActions: some View {
        HStack(spacing: MortSpacing.sm) {
            DashTile(icon: "plus.circle.fill", title: "Post job", tint: MortColor.roseGold) { showPost = true }
            DashTile(icon: "exclamationmark.bubble.fill", title: "Disputes", tint: MortColor.warning) { showDisputes = true }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            HStack {
                Text("Your jobs").font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
                Spacer()
                Button("Manage", action: goToJobs).font(MortFont.caption()).foregroundStyle(MortColor.roseGold)
            }
            if loading {
                MortLoadingView()
            } else if jobs.isEmpty {
                MortEmptyState(systemImage: "plus.rectangle.on.folder", title: "No jobs yet", message: "Post your first safe local job.", actionTitle: "Post a job") { showPost = true }
            } else {
                ForEach(jobs.prefix(3)) { MortJobCard(job: $0) }
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
