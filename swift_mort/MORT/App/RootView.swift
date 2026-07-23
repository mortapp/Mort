import SwiftUI

struct RootView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var session = session

        ZStack {
            Group {
                switch session.phase {
                case .restoring:
                    MortLoadingState(label: "Restoring your session")
                case .signedOut:
                    AuthView()
                case let .awaitingEmailConfirmation(email):
                    EmailConfirmationView(email: email)
                case .onboarding:
                    OnboardingView()
                case .ready:
                    RoleRootView(role: session.profile?.role ?? .teen)
                case let .restricted(status):
                    RestrictedAccountView(status: status)
                case .passwordRecovery:
                    PasswordRecoveryView()
                case let .failed(message):
                    MortErrorState(message: message) {
                        Task { await session.restore() }
                    }
                }
            }
            if shouldShowAppLock { AppLockView().zIndex(20) }
        }
        .mortScreen()
        .alert("MORT", isPresented: Binding(
            get: { session.alertMessage != nil },
            set: { if !$0 { session.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { session.alertMessage = nil }
        } message: {
            Text(session.alertMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: container.appLock.didEnterBackground()
            case .active: container.appLock.didBecomeActive()
            default: break
            }
        }
    }

    private var shouldShowAppLock: Bool {
        guard container.appLock.isLocked else { return false }
        if case .ready = session.phase { return true }
        return false
    }
}
