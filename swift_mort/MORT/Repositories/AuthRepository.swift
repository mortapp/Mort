import Foundation
import Supabase

struct AuthResult: Equatable, Sendable {
    let userID: UUID
    let email: String?
    let requiresEmailConfirmation: Bool
}

protocol AuthRepositoryProtocol: Sendable {
    func signUp(email: String, password: String) async throws -> AuthResult
    func signIn(email: String, password: String) async throws -> AuthResult
    func restoreUser() async throws -> AuthResult?
    func sendPasswordReset(email: String) async throws
    func updatePassword(_ password: String) async throws
    func handleDeepLink(_ url: URL) async throws
    func signOut() async throws
}

final class AuthRepository: SupabaseRepository, AuthRepositoryProtocol {
    func signUp(email: String, password: String) async throws -> AuthResult {
        try await translated {
            let response = try await client.auth.signUp(
                email: email.trimmed,
                password: password,
                redirectTo: URL(string: "mort://auth/confirmation")
            )
            return AuthResult(
                userID: response.user.id,
                email: response.user.email,
                requiresEmailConfirmation: response.session == nil
            )
        }
    }

    func signIn(email: String, password: String) async throws -> AuthResult {
        try await translated {
            let session = try await client.auth.signIn(email: email.trimmed, password: password)
            return AuthResult(userID: session.user.id, email: session.user.email, requiresEmailConfirmation: false)
        }
    }

    func restoreUser() async throws -> AuthResult? {
        do {
            let session = try await client.auth.session
            return AuthResult(userID: session.user.id, email: session.user.email, requiresEmailConfirmation: false)
        } catch {
            return nil
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await translated {
            try await client.auth.resetPasswordForEmail(
                email.trimmed,
                redirectTo: URL(string: "mort://auth/recovery")
            )
        }
    }

    func updatePassword(_ password: String) async throws {
        try await translated {
            try await client.auth.update(user: UserAttributes(password: password))
        }
    }

    func handleDeepLink(_ url: URL) async throws {
        try await translated { _ = try await client.auth.session(from: url) }
    }

    func signOut() async throws {
        try await translated { try await client.auth.signOut() }
    }
}
