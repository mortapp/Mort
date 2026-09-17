//
//  MortTabView.swift
//  MORT iOS V8 — Navigation
//
//  Role-aware tab navigation. Teen, adult and guardian get different tab sets
//  because they use genuinely different parts of the product.
//
//  Monochrome navigation: no colored tab tint, silver selection only.
//

import SwiftUI

/// The tabs available in the app, per role.
nonisolated enum MortTab: String, Hashable, Identifiable, CaseIterable, Sendable {
    case home
    case discover
    case jobs
    case messages
    case safety
    case guardianHome
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .discover: "Find work"
        case .jobs: "Jobs"
        case .messages: "Messages"
        case .safety: "Safety"
        case .guardianHome: "Teens"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .discover: "magnifyingglass"
        case .jobs: "briefcase"
        case .messages: "bubble.left.and.bubble.right"
        case .safety: "shield.lefthalf.filled"
        case .guardianHome: "person.2"
        case .profile: "person.crop.circle"
        }
    }

    static func tabs(for role: MortRole) -> [MortTab] {
        switch role {
        case .teen: [.home, .discover, .jobs, .messages, .safety, .profile]
        case .adult: [.home, .jobs, .messages, .profile]
        case .guardian: [.guardianHome, .messages, .safety, .profile]
        }
    }
}

struct MortTabView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @State private var selection: MortTab = .home
    @State private var navigators: [MortTab: MortNavigator] = [:]

    private var tabs: [MortTab] { MortTab.tabs(for: user.role) }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(tabs) { tab in
                MortTabStack(tab: tab, user: user, navigator: navigator(for: tab))
                    .tabItem {
                        Label(tab.title, systemImage: tab.symbol)
                    }
                    .tag(tab)
            }
        }
        .tint(MortColor.silver2)
        .onAppear {
            configureTabBar()
            if !tabs.contains(selection) {
                selection = tabs.first ?? .home
            }
        }
        .onReceive(of: .mortDeepLink) { note in
            guard let path = note.userInfo?["path"] as? String else { return }
            routeDeepLink(path)
        }
    }

    private func navigator(for tab: MortTab) -> MortNavigator {
        if let existing = navigators[tab] { return existing }
        let created = MortNavigator()
        navigators[tab] = created
        return created
    }

    /// Deep links land in the most sensible tab, then push their route.
    private func routeDeepLink(_ path: String) {
        let target: MortTab
        if path.hasPrefix("/messages") {
            target = .messages
        } else if path.hasPrefix("/safety") {
            target = tabs.contains(.safety) ? .safety : (tabs.first ?? .home)
        } else if path.hasPrefix("/jobs") {
            target = tabs.contains(.jobs) ? .jobs : (tabs.first ?? .home)
        } else {
            target = tabs.first ?? .home
        }
        selection = target
        navigator(for: target).handleDeepLink(path)
    }

    /// Dark, hairline-topped tab bar so content scrolls under it legibly.
    private func configureTabBar() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(MortColor.ink2.opacity(0.94))
        appearance.shadowColor = UIColor(MortColor.hairline2)

        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor(MortColor.textMuted)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(MortColor.textMuted)]
        item.selected.iconColor = UIColor(MortColor.ice1)
        item.selected.titleTextAttributes = [.foregroundColor: UIColor(MortColor.ice1)]
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: UIColor(MortColor.textPrimary)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(MortColor.textPrimary)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(MortColor.silver2)
        #endif
    }
}

/// One navigation stack per tab, with the shared destination resolver.
struct MortTabStack: View {
    let tab: MortTab
    let user: MortUser
    let navigator: MortNavigator

    var body: some View {
        NavigationStack(path: Binding(
            get: { navigator.path },
            set: { navigator.path = $0 }
        )) {
            rootView
                .navigationDestination(for: MortRoute.self) { route in
                    MortRouteDestination(route: route, user: user)
                        .environment(navigator)
                }
        }
        .environment(navigator)
        .sheet(item: Binding(
            get: { navigator.sheet },
            set: { navigator.sheet = $0 }
        )) { sheet in
            MortSheetDestination(sheet: sheet, user: user)
                .environment(navigator)
        }
        .fullScreenCover(item: Binding(
            get: { navigator.fullScreen },
            set: { navigator.fullScreen = $0 }
        )) { cover in
            MortFullScreenDestination(cover: cover, user: user)
                .environment(navigator)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch tab {
        case .home:
            switch user.role {
            case .teen: TeenDashboardView(user: user)
            case .adult: AdultDashboardView(user: user)
            case .guardian: GuardianHomeView(user: user)
            }
        case .discover:
            DiscoverView()
        case .jobs:
            MyJobsView(user: user)
        case .messages:
            ConversationListView()
        case .safety:
            SafetyCenterView(user: user)
        case .guardianHome:
            GuardianHomeView(user: user)
        case .profile:
            ProfileHomeView(user: user)
        }
    }
}

// MARK: - Helpers

extension View {
    /// Sheet presentation with an `Identifiable` optional binding.
    func sheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
    }

    /// Full-screen cover with an `Identifiable` optional binding.
    func fullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        fullScreenCover(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
    }

    /// Observes a `NotificationCenter` name on the main actor.
    func onReceive(
        of name: Notification.Name,
        perform action: @escaping (Notification) -> Void
    ) -> some View {
        onReceive(publisherName: name, action: action)
    }
}

private extension View {
    func onReceive(
        publisherName: Notification.Name,
        action: @escaping (Notification) -> Void
    ) -> some View {
        task {
            for await note in NotificationCenter.default.notifications(named: publisherName) {
                action(note)
            }
        }
    }
}
