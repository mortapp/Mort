import Foundation
import Observation
import Supabase

enum SessionPhase: Equatable {
    case restoring
    case signedOut
    case awaitingEmailConfirmation(String)
    case onboarding
    case ready
    case restricted(String)
    case passwordRecovery
    case failed(String)
}

enum SessionDestination: Equatable {
    case signedOut
    case onboarding
    case ready(UserRole)
    case restricted(String)
}

enum SessionRouting {
    static func destination(hasUser: Bool, profile: Profile?) -> SessionDestination {
        guard hasUser else { return .signedOut }
        guard let profile, profile.isOnboarded, let role = profile.role else { return .onboarding }
        guard profile.isActive else { return .restricted(profile.accountStatus) }
        return .ready(role)
    }
}

@MainActor
@Observable
final class SessionStore {
    private let client: SupabaseClient
    private let authRepository: AuthRepositoryProtocol
    private let profileRepository: ProfileRepositoryProtocol
    private let revenueCat: RevenueCatService
    private let router: Router
    private var authTask: Task<Void, Never>?
    private var pendingNotificationURL: URL?

    private(set) var phase: SessionPhase = .restoring
    private(set) var userID: UUID?
    private(set) var email: String?
    private(set) var profile: Profile?
    private(set) var isWorking = false
    var alertMessage: String?

    init(
        client: SupabaseClient,
        authRepository: AuthRepositoryProtocol,
        profileRepository: ProfileRepositoryProtocol,
        revenueCat: RevenueCatService,
        router: Router
    ) {
        self.client = client
        self.authRepository = authRepository
        self.profileRepository = profileRepository
        self.revenueCat = revenueCat
        self.router = router
    }

    func start() async {
        guard authTask == nil else { return }
        phase = .restoring
        await restore()
        authTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in client.auth.authStateChanges {
                guard !Task.isCancelled else { break }
                switch event {
                case .signedOut:
                    await clearSession()
                case .passwordRecovery:
                    userID = session?.user.id
                    email = session?.user.email
                    phase = .passwordRecovery
                case .signedIn, .initialSession, .tokenRefreshed, .userUpdated:
                    if let session { await establish(userID: session.user.id, email: session.user.email) }
                default:
                    break
                }
            }
        }
    }

    func restore() async {
        do {
            if let user = try await authRepository.restoreUser() {
                await establish(userID: user.userID, email: user.email)
            } else {
                phase = .signedOut
            }
        } catch {
            phase = .failed(BackendErrorTranslator.translate(error).localizedDescription)
        }
    }

    func signIn(email: String, password: String) async {
        guard validateCredentials(email: email, password: password) else { return }
        await perform {
            let result = try await authRepository.signIn(email: email, password: password)
            await establish(userID: result.userID, email: result.email)
        }
    }

    func signUp(email: String, password: String) async {
        guard validateCredentials(email: email, password: password) else { return }
        await perform {
            let result = try await authRepository.signUp(email: email, password: password)
            if result.requiresEmailConfirmation {
                self.email = result.email
                phase = .awaitingEmailConfirmation(result.email ?? email)
            } else {
                await establish(userID: result.userID, email: result.email)
            }
        }
    }

    func sendPasswordReset(email: String) async {
        if let error = MortValidators.email(email) { alertMessage = error; return }
        await perform {
            try await authRepository.sendPasswordReset(email: email)
            alertMessage = "Check your email for a secure password reset link."
        }
    }

    func updateRecoveredPassword(_ password: String) async {
        if let error = MortValidators.password(password) { alertMessage = error; return }
        await perform {
            try await authRepository.updatePassword(password)
            alertMessage = "Password updated."
            await refreshProfile()
        }
    }

    func handleDeepLink(_ url: URL) async {
        await perform { try await authRepository.handleDeepLink(url) }
    }

    func handleIncomingURL(_ url: URL) async {
        switch NotificationDestinationResolver.linkResolution(for: url, role: profile?.role) {
        case .notNotification:
            await handleDeepLink(url)
        case let .destination(route):
            if phase == .ready {
                router.push(route)
            } else {
                pendingNotificationURL = url
            }
        }
    }

    func refreshProfile() async {
        guard userID != nil else { phase = .signedOut; return }
        do {
            profile = try await profileRepository.currentProfile()
            applyRouting()
        } catch {
            phase = .failed(BackendErrorTranslator.translate(error).localizedDescription)
        }
    }

    func signOut() async {
        pendingNotificationURL = nil
        await perform {
            await revenueCat.logOut()
            try await authRepository.signOut()
            await clearSession()
        }
    }

    private func establish(userID: UUID, email: String?) async {
        self.userID = userID
        self.email = email
        do {
            profile = try await profileRepository.currentProfile()
            applyRouting()
            do {
                try await revenueCat.configure(userID: userID)
            } catch {
                alertMessage = "Your MORT account is ready, but optional purchases are unavailable in this build."
            }
        } catch {
            phase = .failed(BackendErrorTranslator.translate(error).localizedDescription)
        }
    }

    private func applyRouting() {
        switch SessionRouting.destination(hasUser: userID != nil, profile: profile) {
        case .signedOut: phase = .signedOut
        case .onboarding: phase = .onboarding
        case .ready:
            phase = .ready
            openPendingNotification()
        case let .restricted(status): phase = .restricted(status)
        }
    }

    private func clearSession() async {
        userID = nil
        email = nil
        profile = nil
        router.reset()
        phase = .signedOut
    }

    private func openPendingNotification() {
        guard let url = pendingNotificationURL,
              case let .destination(route) = NotificationDestinationResolver.linkResolution(
                  for: url,
                  role: profile?.role
              )
        else { return }
        pendingNotificationURL = nil
        router.push(route)
    }

    private func validateCredentials(email: String, password: String) -> Bool {
        if let error = MortValidators.email(email) { alertMessage = error; return false }
        if let error = MortValidators.password(password) { alertMessage = error; return false }
        return true
    }

    private func perform(_ operation: () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        do { try await operation() }
        catch { alertMessage = BackendErrorTranslator.translate(error).localizedDescription }
    }
}
