import CryptoKit
import Foundation

nonisolated struct PasswordRecoveryClaims: Decodable, Sendable {
    let subject: UUID
    let sessionID: UUID
    let expiration: Double

    private enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case sessionID = "session_id"
        case expiration = "exp"
    }

    static func decode(_ token: String, now: Date) throws -> Self {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3, segments.allSatisfy({ segment in
            !segment.isEmpty && segment.utf8.allSatisfy {
                (65...90).contains($0) || (97...122).contains($0)
                    || (48...57).contains($0) || $0 == 45 || $0 == 95
            }
        }) else { throw MortError.unauthorized }
        var payload = segments[1].replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONDecoder().decode(Self.self, from: data),
              claims.expiration.isFinite,
              claims.expiration > now.timeIntervalSince1970 else {
            throw MortError.unauthorized
        }
        // Reading claims is only a sanity check. GoTrue validates the bearer
        // and refresh credentials before anything can authorize a reset.
        return claims
    }
}

/// A recovery credential is separate from the ordinary Keychain session. It
/// never authorizes general app requests or inherits automatic token refresh.
nonisolated struct PasswordRecoverySession: Sendable {
    let accessToken: String
    let subject: UUID
    let expiresAt: Date
}

nonisolated struct PasswordRecoveryRefreshResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: AuthTokenResponse.User
}

/// Stores only an expiring digest of a consumed session ID, never credentials.
nonisolated struct PasswordRecoveryReplayStore: Sendable {
    private let key = "mort.consumed-recovery-sessions.v1"
    let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    func contains(_ sessionID: UUID, now: Date) -> Bool {
        activeEntries(now: now)[digest(sessionID)] != nil
    }

    func consume(_ sessionID: UUID, expiresAt: Date, now: Date) {
        var entries = activeEntries(now: now)
        entries[digest(sessionID)] = expiresAt.timeIntervalSince1970
        defaults.set(entries, forKey: key)
    }

    private var defaults: UserDefaults {
        suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    private func activeEntries(now: Date) -> [String: Double] {
        let entries = defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
        return entries.filter { $0.value > now.timeIntervalSince1970 }
    }

    private func digest(_ sessionID: UUID) -> String {
        Data(SHA256.hash(data: Data(sessionID.uuidString.utf8))).base64EncodedString()
    }
}
