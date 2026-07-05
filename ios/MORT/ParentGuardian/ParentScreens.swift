//
//  ParentScreens.swift
//  MORT
//
//  Linked teen overview, safety alerts, teen activity, and guardian settings.
//

import SwiftUI

struct LinkedTeensView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    @State private var links: [GuardianLink] = []
    @State private var pings: [SafetyPing] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "Linked teens", subtitle: "Overview and activity")
                content
            }
            .mortScreen()
            .navigationDestination(for: GuardianLink.self) { link in
                TeenActivityView(link: link, pings: pings.filter { $0.teenId == link.teenId })
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView()
        } else if links.isEmpty {
            MortEmptyState(systemImage: "person.2.slash", title: "No teens linked", message: "Ask your teen to share their guardian link from their Safety tab.")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(links) { link in
                        NavigationLink(value: link) {
                            MortCard {
                                HStack(spacing: MortSpacing.sm) {
                                    MortAvatar(name: link.teenName)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(link.teenName).font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                                        Text(status(for: link).label).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(MortColor.darkSilver)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func status(for link: GuardianLink) -> CheckInStatus {
        pings.first(where: { $0.teenId == link.teenId })?.status ?? .unknown
    }

    private func load() async {
        guard let me = session.profile else { return }
        loading = true
        links = (try? await services.safety.linkedTeens(forGuardian: me.id)) ?? []
        pings = (try? await services.safety.recentPings(forGuardian: me.id)) ?? []
        loading = false
    }
}

struct TeenActivityView: View {
    let link: GuardianLink
    let pings: [SafetyPing]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.md) {
                HStack(spacing: MortSpacing.sm) {
                    MortAvatar(name: link.teenName, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.teenName).font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
                        Text("Linked guardian: \(link.guardianName)").font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                    }
                }
                MortSafetyBanner(staticMessage: "You can see safety check-ins and activity summaries — never private messages.")

                Text("Check-in history").font(MortFont.title2()).foregroundStyle(MortColor.primaryText)
                if pings.isEmpty {
                    MortEmptyState(systemImage: "shield", title: "No check-ins yet")
                } else {
                    ForEach(pings) { PingRow(ping: $0) }
                }
            }
            .padding(MortSpacing.md)
        }
        .mortScreen()
        .navigationTitle("Teen activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct SafetyAlertsView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    @State private var pings: [SafetyPing] = []
    @State private var loading = true

    private var alerts: [SafetyPing] {
        pings.filter { $0.status == .needsHelp || $0.status == .enRoute }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "Safety alerts", subtitle: "Check-ins that may need attention")
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
        } else if alerts.isEmpty {
            MortEmptyState(systemImage: "checkmark.shield.fill", title: "All clear", message: "No safety alerts right now. We'll notify you if anything needs attention.")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(alerts) { PingRow(ping: $0) }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func load() async {
        guard let me = session.profile else { return }
        loading = true
        pings = (try? await services.safety.recentPings(forGuardian: me.id)) ?? []
        loading = false
    }
}

struct GuardianSettingsView: View {
    @State private var alertOnNeedsHelp = true
    @State private var alertOnLateJobs = true
    @State private var weeklySummary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    MortSafetyBanner(staticMessage: "Choose which safety events alert you. MORT never shares your teen's private messages.")
                    MortCard {
                        VStack(spacing: MortSpacing.sm) {
                            settingToggle("Alert when a teen needs help", $alertOnNeedsHelp)
                            Divider().overlay(MortColor.stroke)
                            settingToggle("Alert on late-night job activity", $alertOnLateJobs)
                            Divider().overlay(MortColor.stroke)
                            settingToggle("Weekly activity summary", $weeklySummary)
                        }
                    }
                }
                .padding(MortSpacing.md)
            }
            .mortScreen()
            .safeAreaInset(edge: .top) {
                MortTopBar(title: "Guardian settings").background(MortColor.background)
            }
        }
    }

    private func settingToggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title).font(MortFont.callout()).foregroundStyle(MortColor.primaryText)
        }
        .tint(MortColor.roseGold)
    }
}
