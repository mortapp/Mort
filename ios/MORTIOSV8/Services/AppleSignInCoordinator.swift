//
//  AppleSignInCoordinator.swift
//  MORT iOS V8 — Services
//
//  Native Sign in with Apple.
//
//  REQUIRES:
//   - The "Sign in with Apple" capability on the app target.
//   - An `.entitlements` file containing
//     `com.apple.developer.applesignin = [Default]`.
//     (See the handoff's entitlements section — a capability without an
//      entitlements file will not work.)
//
//  The identity token is forwarded to Supabase, which is the authority that
//  decides whether a session exists. This coordinator never creates one.
//

import Foundation
import AuthenticationServices
import CryptoKit

/// The material Supabase needs to exchange for a session.
nonisolated struct AppleCredential: Sendable {
    let identityToken: String
    /// The un-hashed nonce; Supabase verifies it against the token's hash.
    let rawNonce: String
    let fullName: String?
    let email: String?
}

@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<AppleCredential, Error>?
    private var currentNonce: String?

    /// Presents the native Apple sheet and returns the credential.
    func requestCredential() async throws -> AppleCredential {
        let nonce = Self.randomNonce()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                continuation?.resume(throwing: MortError.unauthorized)
                continuation = nil
                return
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            continuation?.resume(returning: AppleCredential(
                identityToken: token,
                rawNonce: nonce,
                fullName: name.isEmpty ? nil : name,
                email: credential.email
            ))
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let mapped: MortError
            if let authError = error as? ASAuthorizationError {
                mapped = switch authError.code {
                case .canceled: .rejected("Sign in was cancelled.")
                case .notHandled, .failed, .invalidResponse: .unauthorized
                default: .unknown
                }
            } else {
                mapped = .unknown
            }
            continuation?.resume(throwing: mapped)
            continuation = nil
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            #if canImport(UIKit)
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
            #else
            ASPresentationAnchor()
            #endif
        }
    }
}

#if canImport(UIKit)
import UIKit
#endif
