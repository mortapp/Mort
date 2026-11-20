//
//  MORTIOSV8App.swift
//  MORT iOS V8 — App entry point
//
//  App lifecycle, dependency environment, session restoration, deep links,
//  scene phase handling and the resolved reduced-motion preference.
//

import SwiftUI

@main
struct MORTIOSV8App: App {
    @State private var dependencies = MortDependencies.resolve()
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some Scene {
        WindowGroup {
            MortRootView()
                .environment(\.mort, dependencies)
                .environment(dependencies.session)
                .environment(dependencies.settings)
                // Resolved motion preference: OS setting OR the MORT setting.
                .environment(
                    \.mortReducedMotion,
                    systemReduceMotion || dependencies.settings.reducedMotion
                )
                .preferredColorScheme(.dark)
                .tint(MortColor.silver2)
        }
    }
}

/// Root view: decides between entry/auth, onboarding and the signed-in app.
struct MortRootView: View {
    @Environment(\.mort) private var mort
    @Environment(MortSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.mortReducedMotion) private var reducedMotion
    @State private var recoveryInProgress = false
    @State private var recoveryFailed = false

    var body: some View {
        ZStack {
            MortColor.black.ignoresSafeArea()

            if recoveryInProgress {
                NavigationStack { PasswordRecoveryView { recoveryInProgress = false } }
            } else if recoveryFailed {
                NavigationStack { PasswordRecoveryUnavailableView { recoveryFailed = false } }
            } else {
                switch session.phase {
                case .restoring:
                    MortLaunchView()
                case .signedOut, .expired:
                    AuthEntryView()
                case .onboarding(let user):
                    OnboardingFlowView(user: user)
                case .active(let user):
                    MortTabView(user: user)
                }
            }
        }
        .animation(reducedMotion ? nil : MortMotion.ease, value: phaseKey)
        .task {
            await session.restore()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Returning to foreground: re-validate the session so an
                // expired token never leaves stale content on screen.
                Task { await revalidate() }
            case .background, .inactive:
                break
            @unknown default:
                break
            }
        }
        .onOpenURL { url in
            handleIncoming(url)
        }
        .overlay(alignment: .top) {
            if mort.mode.isPreview {
                PreviewDataBanner()
            }
        }
    }

    private var phaseKey: String {
        switch session.phase {
        case .restoring: "restoring"
        case .signedOut: "signedOut"
        case .expired: "expired"
        case .onboarding: "onboarding"
        case .active: "active"
        }
    }

    private func revalidate() async {
        guard case .active = session.phase else { return }
        // A lightweight probe; the session downgrades itself if rejected.
        await session.restore()
    }

    private func handleIncoming(_ url: URL) {
        // Stripe owns redirect-capable payment callbacks. Give it the URL
        // before ordinary MORT deep-link routing and before auth-state gating.
        if StripePaymentSheetAdapter.handleURLCallback(url) {
            return
        }

        // Supabase recovery links carry a short-lived session in the URL fragment.
        // Handle them before the ordinary signed-in deep-link gate.
        if let values = Self.recoveryParameters(from: url),
           values["type"] == "recovery",
           let access = values["access_token"],
           let refresh = values["refresh_token"],
           let expires = Int(values["expires_in"] ?? "3600") {
            Task {
                let accepted = await session.beginPasswordRecovery(
                    accessToken: access, refreshToken: refresh, expiresIn: expires
                )
                recoveryInProgress = accepted
                recoveryFailed = !accepted
            }
            return
        }

        // Ordinary app deep links require an authenticated session.
        guard case .active = session.phase else { return }
        NotificationCenter.default.post(
            name: .mortDeepLink,
            object: nil,
            userInfo: ["path": url.path]
        )
    }

    static func recoveryParameters(from url: URL) -> [String: String]? {
        guard url.scheme == "com.mortapp.mobile",
              url.host == "app",
              url.path == "/auth-callback",
              let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
              let components = URLComponents(string: "?\(fragment)") else { return nil }
        return Dictionary(components.queryItems?.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        } ?? [], uniquingKeysWith: { first, _ in first })
    }
}

extension Notification.Name {
    static let mortDeepLink = Notification.Name("mort.deepLink")
}

/// Launch view: the wordmark writes itself while the session is restored.
struct MortLaunchView: View {
    @Environment(MortSettingsStore.self) private var settings

    var body: some View {
        ZStack {
            MortAtmosphere()
            VStack(spacing: MortSpace.s6) {
                MortWordmark(animateIntro: !settings.wordmarkPlayed)
                    .frame(width: 214, height: 80)
                MortSpinner(size: 18)
            }
            MortAtmosphereForeground()
        }
        .onAppear { settings.wordmarkPlayed = true }
        .accessibilityLabel("MORT is starting")
    }
}

/// Honest banner shown whenever the app is not wired to the real backend.
/// Prevents fixture content from ever reading as real backend success.
struct PreviewDataBanner: View {
    var body: some View {
        HStack(spacing: MortSpace.s2) {
            Image(systemName: "eye.trianglebadge.exclamationmark")
                .font(.system(size: 11, weight: .semibold))
            Text("PREVIEW DATA — NOT CONNECTED TO MORT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
        }
        .foregroundStyle(MortColor.warning)
        .padding(.horizontal, MortSpace.s3)
        .padding(.vertical, MortSpace.s1 + 2)
        .background {
            Capsule().fill(MortColor.ink1.opacity(0.9))
        }
        .overlay {
            Capsule().strokeBorder(MortColor.warning.opacity(0.4), lineWidth: 1)
        }
        .padding(.top, MortSpace.s1)
        .accessibilityLabel("Preview data. This build is not connected to MORT.")
    }
}
