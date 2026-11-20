import Foundation

nonisolated struct PasswordRecoveryLink: Equatable, Sendable {
    static let callbackURL = "com.mortapp.mobile://app/auth-callback"
    static let maxLifetime = 86_400

    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum Route: Equatable, Sendable {
        case unrelated
        case unavailable
        case recovery(PasswordRecoveryLink)
    }

    static func route(_ url: URL) -> Route {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "com.mortapp.mobile",
              parts.percentEncodedHost == "app",
              parts.percentEncodedPath == "/auth-callback",
              parts.user == nil, parts.password == nil, parts.port == nil else {
            return .unrelated
        }
        guard let fragment = parts.percentEncodedFragment else {
            return parts.query == nil ? .unavailable : .unrelated
        }
        guard parts.query == nil, !fragment.isEmpty else { return .unavailable }

        var values: [String: String] = [:]
        for field in fragment.split(separator: "&", omittingEmptySubsequences: false) {
            let pair = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2,
                  let name = pair[0].removingPercentEncoding, !name.isEmpty,
                  let value = pair[1].removingPercentEncoding,
                  values[name] == nil else { return .unavailable }
            values[name] = value
        }
        guard values["error"] == nil, values["error_code"] == nil,
              values["error_description"] == nil else { return .unavailable }
        if let type = values["type"], type != "recovery" { return .unrelated }
        guard values["type"] == "recovery",
              let access = values["access_token"], isToken(access),
              let refresh = values["refresh_token"], isToken(refresh),
              let rawLifetime = values["expires_in"],
              rawLifetime.utf8.allSatisfy({ (48...57).contains($0) }),
              let lifetime = Int(rawLifetime), (1...maxLifetime).contains(lifetime) else {
            return .unavailable
        }
        return .recovery(Self(accessToken: access, refreshToken: refresh, expiresIn: lifetime))
    }

    static func isToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { (33...126).contains($0) }
    }
}
