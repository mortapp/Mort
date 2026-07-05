//
//  RootView.swift
//  MORT
//
//  Top-level router: splash → onboarding → role-based home.
//  Routes via SessionStore.phase and the active UserRole.
//

import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        ZStack {
            MortColor.background.ignoresSafeArea()

            switch session.phase {
            case .splash:
                SplashView { session.finishSplash() }
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlowView()
                    .transition(.opacity)
            case .underageBlocked:
                UnderageBlockedView()
                    .transition(.opacity)
            case .home:
                RoleHomeView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .tint(MortColor.roseGold)
    }
}

/// Routes to the correct dashboard for the active role.
struct RoleHomeView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        switch session.currentRole {
        case .teen: TeenHomeView()
        case .adult, .business: AdultHomeView()
        case .guardian: ParentHomeView()
        case .admin: AdminHomeView()
        }
    }
}

