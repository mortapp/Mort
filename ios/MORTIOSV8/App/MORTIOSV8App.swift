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
    @State private var dependencies = MORTIOSV8App.initialDependencies()
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private static func initialDependencies() -> MortDependencies {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-mortOfflineSimulatorValidation") {
            return .preview(signedIn: false)
        }
        #endif
        return .resolve()
    }

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
    @State private var checkingRecoveryLink = false
    @State private var recoveryFormID = UUID()

    var body: some View {
        ZStack {
            MortColor.black.ignoresSafeArea()

            if recoveryInProgress {
                NavigationStack { PasswordRecoveryView { recoveryInProgress = false } }
                    .id(recoveryFormID)
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

        // Recovery links are handled before the ordinary signed-in route.
        switch PasswordRecoveryLink.route(url) {
        case .unavailable:
            guard !checkingRecoveryLink, !recoveryInProgress else { return }
            session.clearError()
            recoveryFailed = true
            return
        case .recovery(let link):
            guard !checkingRecoveryLink, !session.isWorking else { return }
            checkingRecoveryLink = true
            Task {
                defer { checkingRecoveryLink = false }
                let accepted = await session.beginPasswordRecovery(
                    accessToken: link.accessToken,
                    refreshToken: link.refreshToken,
                    expiresIn: link.expiresIn
                )
                if accepted {
                    recoveryFormID = UUID()
                    recoveryInProgress = true
                    recoveryFailed = false
                } else if !recoveryInProgress {
                    recoveryFailed = true
                }
            }
            return
        case .unrelated:
            break
        }

        // Ordinary app deep links require an authenticated session.
        guard case .active = session.phase else { return }
        NotificationCenter.default.post(
            name: .mortDeepLink,
            object: nil,
            userInfo: ["path": url.path]
        )
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
