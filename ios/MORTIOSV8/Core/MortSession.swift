//
//  MortSession.swift
//  MORT iOS V8 — Core
//
//  Authentication and session state.
//
//  AUTHORITY: the backend owns authentication. This type never invents a
//  signed-in session — every transition comes from an AuthService result.
//

import SwiftUI

/// The app's top-level authentication phase.
nonisolated enum SessionPhase: Equatable, Sendable {
    /// Restoring a persisted session at launch.
    case restoring
    /// No session — show entry/auth.
    case signedOut
    /// Signed in but onboarding is incomplete.
    case onboarding(MortUser)
    /// Signed in and ready.
    case active(MortUser)
    /// Session ended because the token was rejected.
    case expired

    var user: MortUser? {
        switch self {
        case .onboarding(let u), .active(let u): u
        case .restoring, .signedOut, .expired: nil
        }
    }
}

@Observable
@MainActor
final class MortSession {
    private(set) var phase: SessionPhase = .restoring
    private(set) var authError: MortError?
    private(set) var isWorking = false

    /// Network reachability, surfaced to every screen for honest offline UI.
    var isOnline: Bool = true

    private let auth: any AuthService

    init(auth: any AuthService) {
        self.auth = auth
    }

    var role: MortRole? { phase.user?.role }

    /// Restores a persisted session at launch. Fails CLOSED to signedOut.
    func restore() async {
        phase = .restoring
        do {
            if let user = try await auth.restoreSession() {
                phase = user.displayName.isEmpty ? .onboarding(user) : .active(user)
            } else {
                phase = .signedOut
            }
        } catch {
            // Never assume a session on failure.
            phase = .signedOut
        }
    }

    func signIn(email: String, password: String) async {
        isWorking = true
        authError = nil
        do {
            let user = try await auth.signIn(email: email, password: password)
            phase = user.displayName.isEmpty ? .onboarding(user) : .active(user)
            MortHaptic.success()
        } catch let error as MortError {
            authError = error
            MortHaptic.failure()
        } catch {
            authError = .unknown
            MortHaptic.failure()
        }
        isWorking = false
    }

    func signUp(email: String, password: String, role: MortRole) async {
        isWorking = true
        authError = nil
        do {
            let user = try await auth.signUp(email: email, password: password, role: role)
            phase = .onboarding(user)
            MortHaptic.success()
        } catch let error as MortError {
            authError = error
            MortHaptic.failure()
        } catch {
            authError = .unknown
            MortHaptic.failure()
        }
        isWorking = false
    }

    func signInWithApple() async {
        isWorking = true
        authError = nil
        do {
            let user = try await auth.signInWithApple()
            phase = user.displayName.isEmpty ? .onboarding(user) : .active(user)
        } catch let error as MortError {
            authError = error
        } catch {
            authError = .unknown
        }
        isWorking = false
    }

    func signInWithGoogle() async {
        isWorking = true
        authError = nil
        do {
            let user = try await auth.signInWithGoogle()
            phase = user.displayName.isEmpty ? .onboarding(user) : .active(user)
        } catch let error as MortError {
            authError = error
        } catch {
            authError = .unknown
        }
        isWorking = false
    }

    func sendPasswordReset(email: String) async -> Bool {
        isWorking = true
        authError = nil
        defer { isWorking = false }
        do {
            try await auth.sendPasswordReset(email: email)
            return true
        } catch let error as MortError {
            authError = error
            return false
        } catch {
            authError = .unknown
            return false
        }
    }

    func completeOnboarding(with draft: MortProfileDraft) async {
        guard let user = phase.user else { return }
        isWorking = true
        do {
            let updated = try await auth.completeOnboarding(userId: user.id, draft: draft)
            phase = .active(updated)
        } catch {
            // Keep the user in onboarding rather than faking completion.
            authError = (error as? MortError) ?? .unknown
        }
        isWorking = false
    }

    func signOut() async {
        try? await auth.signOut()
        phase = .signedOut
        authError = nil
    }

    func deleteAccount() async -> Bool {
        guard let user = phase.user else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.deleteAccount(userId: user.id)
            phase = .signedOut
            return true
        } catch let error as MortError {
            authError = error
            return false
        } catch {
            authError = .unknown
            return false
        }
    }

    func clearError() { authError = nil }
}
