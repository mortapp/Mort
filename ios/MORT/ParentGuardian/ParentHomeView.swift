//
//  ParentHomeView.swift
//  MORT
//
//  Parent/Guardian tab container + dashboard.
//

import SwiftUI

struct ParentHomeView: View {
    @State private var selection = 0

    private let tabs = [
        MortTabItem(id: 0, title: "Home", systemImage: "house"),
        MortTabItem(id: 1, title: "Teens", systemImage: "person.2"),
        MortTabItem(id: 2, title: "Alerts", systemImage: "bell"),
        MortTabItem(id: 3, title: "Settings", systemImage: "gearshape"),
        MortTabItem(id: 4, title: "Profile", systemImage: "person"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case 0: ParentDashboardView(goToTeens: { selection = 1 })
                case 1: LinkedTeensView()
                case 2: SafetyAlertsView()
                case 3: GuardianSettingsView()
                default: ProfileView()
                }
            }
            .frame(maxHeight: .infinity)

            MortTabBar(items: tabs, selection: $selection)
        }
        .background(MortColor.background.ignoresSafeArea())
    }
}

struct ParentDashboardView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    var goToTeens: () -> Void

    @State private var links: [GuardianLink] = []
    @State private var pings: [SafetyPing] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    header
                    MortSafetyBanner(staticMessage: "You can monitor check-ins and safety alerts, but never private messages. Privacy keeps teens safe too.")
                    statusOverview
                    recentCheckIns
                }
                .padding(MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
            .mortScreen()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Guardian dashboard").font(MortFont.body()).foregroundStyle(MortColor.secondaryText)
            Text(session.profile?.displayName ?? "Guardian")
                .font(MortFont.largeTitle()).foregroundStyle(MortColor.primaryText)
        }
        .padding(.top, MortSpacing.sm)
    }

    private var statusOverview: some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            HStack {
                Text("Linked teens").font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
                Spacer()
                Button("View all", action: goToTeens).font(MortFont.caption()).foregroundStyle(MortColor.roseGold)
            }
            if loading {
                MortLoadingView()
            } else if links.isEmpty {
                MortEmptyState(systemImage: "person.2.slash", title: "No teens linked", message: "Ask your teen to share their guardian link code.")
            } else {
                ForEach(links) { link in
                    MortCard {
                        HStack(spacing: MortSpacing.sm) {
                            MortAvatar(name: link.teenName)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(link.teenName).font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                                Text("Linked \(link.linkedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                            }
                            Spacer()
                            MortBadge(text: statusFor(link).label, color: color(for: statusFor(link)), systemImage: "shield.fill")
                        }
                    }
                }
            }
        }
    }

    private var recentCheckIns: some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            Text("Recent check-ins").font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
            if pings.isEmpty {
                Text("No recent check-ins.").font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
            } else {
                ForEach(pings.prefix(4)) { PingRow(ping: $0) }
            }
        }
    }

    private func statusFor(_ link: GuardianLink) -> CheckInStatus {
        pings.first(where: { $0.teenId == link.teenId })?.status ?? .unknown
    }

    private func color(for status: CheckInStatus) -> Color {
        switch status {
        case .safe: return MortColor.success
        case .enRoute: return MortColor.warning
        case .needsHelp: return MortColor.danger
        case .unknown: return MortColor.darkSilver
        }
    }

    private func load() async {
        guard let me = session.profile else { return }
        loading = true
        links = (try? await services.safety.linkedTeens(forGuardian: me.id)) ?? []
        pings = (try? await services.safety.recentPings(forGuardian: me.id)) ?? []
        loading = false
    }
}

struct PingRow: View {
    let ping: SafetyPing
    private var color: Color {
        switch ping.status {
        case .safe: return MortColor.success
        case .enRoute: return MortColor.warning
        case .needsHelp: return MortColor.danger
        case .unknown: return MortColor.darkSilver
        }
    }
    var body: some View {
        MortCard {
            HStack(spacing: MortSpacing.sm) {
                Image(systemName: "shield.fill").foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ping.teenName) · \(ping.status.label)").font(MortFont.callout()).foregroundStyle(MortColor.primaryText)
                    if !ping.note.isEmpty {
                        Text(ping.note).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                    }
                }
                Spacer()
                Text(ping.createdAt, style: .relative).font(MortFont.caption()).foregroundStyle(MortColor.darkSilver)
            }
        }
    }
}
