//
//  SupabaseClient.swift
//  MORT iOS V8 — Services / Supabase integration target
//
//  ============================================================
//  INTEGRATION TARGET — VS CODE WIRES THIS
//  ============================================================
//  This is a complete, dependency-free HTTP client for Supabase (auth, REST,
//  RPC, storage). It is intentionally NOT bound to the supabase-swift SDK so
//  the project builds without external packages; swap the transport for the
//  official SDK if the real MORT repo already uses it.
//
//  HARD RULES:
//   - Only the ANON key ever ships in the app. NEVER the service-role key.
//   - RLS is never bypassed: all requests carry the user's access token.
//   - No financial authority lives here — it forwards backend decisions.
//   - Values come from Config (build-time injected env), never hardcoded.
//

import Foundation

/// Supabase configuration read from build-time environment values.
nonisolated struct SupabaseConfig: Sendable {
    let url: URL
    let anonKey: String

    /// Resolves configuration from `Config`. Returns nil when the project has
    /// not been wired yet, so callers fail CLOSED instead of guessing.
    ///
    /// MORT ships a Supabase publishable key in the client. It is not a
    /// privileged credential; Auth + RLS remain the authorization boundary.
    static func fromEnvironment() -> SupabaseConfig? {
        let raw = Config.allValues
        guard
            let urlString = raw["EXPO_PUBLIC_SUPABASE_URL"], !urlString.isEmpty,
            let key = raw["EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY"], !key.isEmpty,
            key.hasPrefix("sb_publishable_"),
            let url = URL(string: urlString),
            url.scheme == "https"
        else { return nil }
        return SupabaseConfig(url: url, anonKey: key)
    }
}

/// Explicit JSON null sentinel for RPC arguments whose Postgres signatures
/// require nullable values. It is converted to NSNull immediately before
/// JSONSerialization and never leaves the transport boundary.
nonisolated struct SupabaseJSONNull: Sendable {
    init() {}
}

/// Stored session tokens. Persisted in the Keychain, never in UserDefaults.
nonisolated struct SupabaseSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userId: String

    var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-30) }
}

/// Minimal Supabase transport: auth, REST (PostgREST), RPC and storage.
actor SupabaseClient {
    private let config: SupabaseConfig
    private let session: MortKeychain
    private let sendRequest: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let recoveryReplayStore: PasswordRecoveryReplayStore
    private let now: @Sendable () -> Date
    private var recoverySession: PasswordRecoverySession?
    private var recoveryOperationInFlight = false

    init(
        config: SupabaseConfig,
        keychain: MortKeychain = MortKeychain(),
        recoveryReplayStore: PasswordRecoveryReplayStore = PasswordRecoveryReplayStore(),
        now: @escaping @Sendable () -> Date = { Date() },
        sendRequest: (@Sendable (URLRequest) async throws -> (Data, URLResponse))? = nil
    ) {
        self.config = config
        self.session = keychain
        self.recoveryReplayStore = recoveryReplayStore
        self.now = now
        if let sendRequest {
            self.sendRequest = sendRequest
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 25
            configuration.waitsForConnectivity = false
            let urlSession = URLSession(configuration: configuration)
            self.sendRequest = { request in try await urlSession.data(for: request) }
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    // MARK: - Session

    private var currentSession: SupabaseSession? {
        get { session.readSession() }
    }

    func storedSession() -> SupabaseSession? { session.readSession() }

    func store(session newSession: SupabaseSession) {
        session.writeSession(newSession)
    }

    func clearSession() {
        session.deleteSession()
    }

    func establishRecoverySession(accessToken: String, refreshToken: String, expiresIn: Int) async throws {
        let startedAt = now()
        guard !recoveryOperationInFlight,
              (1...PasswordRecoveryLink.maxLifetime).contains(expiresIn),
              PasswordRecoveryLink.isToken(refreshToken) else { throw MortError.unauthorized }
        let original = try PasswordRecoveryClaims.decode(accessToken, now: startedAt)
        guard !recoveryReplayStore.contains(original.sessionID, now: startedAt) else {
            throw MortError.unauthorized
        }
        recoveryOperationInFlight = true
        defer { recoveryOperationInFlight = false }

        let userRequest = try await makeRequest(
            path: "/auth/v1/user", method: "GET", query: [],
            authenticated: false, recoveryBearer: accessToken
        )
        let user: AuthTokenResponse.User = try await perform(userRequest)
        guard UUID(uuidString: user.id) == original.subject else { throw MortError.unauthorized }

        // Exchange the supplied refresh token to prove it belongs to this
        // same user and Auth session. Never install a mismatched token pair.
        let renewed: PasswordRecoveryRefreshResponse = try await post(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: ["refresh_token": refreshToken],
            authenticated: false
        )
        let validatedAt = now()
        let refreshed = try PasswordRecoveryClaims.decode(renewed.accessToken, now: validatedAt)
        guard refreshed.sessionID == original.sessionID,
              refreshed.subject == original.subject,
              UUID(uuidString: renewed.user.id) == original.subject,
              PasswordRecoveryLink.isToken(renewed.refreshToken),
              renewed.expiresIn > 0 else { throw MortError.unauthorized }

        let originalExpiry = Date(timeIntervalSince1970: original.expiration)
        let expiresAt = [
            originalExpiry,
            startedAt.addingTimeInterval(TimeInterval(expiresIn)),
            Date(timeIntervalSince1970: refreshed.expiration),
            validatedAt.addingTimeInterval(TimeInterval(renewed.expiresIn)),
        ].min() ?? validatedAt
        guard expiresAt > validatedAt else { throw MortError.unauthorized }
        recoveryReplayStore.consume(original.sessionID, expiresAt: originalExpiry, now: validatedAt)
        recoverySession = PasswordRecoverySession(
            accessToken: renewed.accessToken, subject: original.subject, expiresAt: expiresAt
        )
    }

    func updateRecoveryPassword(_ password: String) async throws {
        guard !recoveryOperationInFlight, let recovery = recoverySession else {
            throw MortError.unauthorized
        }
        guard recovery.expiresAt > now() else {
            recoverySession = nil
            throw MortError.unauthorized
        }
        recoveryOperationInFlight = true
        defer { recoveryOperationInFlight = false }

        var request = try await makeRequest(
            path: "/functions/v1/password-guard", method: "POST", query: [],
            authenticated: false, recoveryBearer: recovery.accessToken
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "action": "update_password",
            "password": password,
        ])
        let result: PasswordGuardResponse = try await perform(request, isRecoveryPasswordGuard: true)
        guard result.ok else { throw MortError.rejected("The password was not updated.") }

        recoverySession = nil
        if let primary = currentSession, UUID(uuidString: primary.userId) == recovery.subject {
            session.deleteSession()
        }
        // The guarded password change already succeeded. Revoke only this
        // scoped session if GoTrue is reachable; never claim remote logout.
        if let logout = try? await makeRequest(
            path: "/auth/v1/logout",
            method: "POST",
            query: [URLQueryItem(name: "scope", value: "local")],
            authenticated: false,
            recoveryBearer: recovery.accessToken
        ) {
            let _: EmptyResponse? = try? await perform(logout)
        }
    }

    /// Refreshes the access token when it is close to expiry.
    func validAccessToken() async throws -> String {
        guard let current = currentSession else { throw MortError.unauthorized }
        guard current.isExpired else { return current.accessToken }
        let refreshed: AuthTokenResponse = try await post(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: ["refresh_token": current.refreshToken],
            authenticated: false
        )
        let updated = SupabaseSession(
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(refreshed.expiresIn)),
            userId: refreshed.user.id
        )
        session.writeSession(updated)
        return updated.accessToken
    }

    // MARK: - Requests

    /// Canonical Edge Function route. Reject path traversal and arbitrary URL
    /// fragments before they reach URL construction.
    nonisolated static func edgeFunctionPath(for slug: String) -> String? {
        guard
            !slug.isEmpty,
            slug.range(
                of: #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#,
                options: .regularExpression
            ) != nil
        else { return nil }
        return "/functions/v1/\(slug)"
    }

    private func makeRequest(
        path: String,
        method: String,
        query: [URLQueryItem],
        authenticated: Bool,
        recoveryBearer: String? = nil
    ) async throws -> URLRequest {
        var components = URLComponents(
            url: config.url.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw MortError.unknown }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let recoveryBearer {
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("Bearer \(recoveryBearer)", forHTTPHeaderField: "Authorization")
        } else if authenticated {
            let token = try await validAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<T: Decodable>(
        _ request: URLRequest, isRecoveryPasswordGuard: Bool = false
    ) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sendRequest(request)
        } catch let error as URLError {
            throw Self.map(urlError: error)
        }
        guard let http = response as? HTTPURLResponse else { throw MortError.unknown }
        guard (200..<300).contains(http.statusCode) else {
            if isRecoveryPasswordGuard {
                let failure = try? decoder.decode(PasswordGuardFailure.self, from: data)
                switch failure?.code {
                case "leaked_password_compromised":
                    throw MortError.rejected("That password appears in a known data breach. Choose a different one.")
                case "password_complexity_required":
                    throw MortError.rejected("Use uppercase and lowercase letters, a number, and a symbol.")
                default:
                    break
                }
            }
            throw Self.map(status: http.statusCode, data: data)
        }
        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T {
            return empty
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MortError.unknown
        }
    }

    func get<T: Decodable>(
        path: String,
        query: [URLQueryItem] = [],
        authenticated: Bool = true
    ) async throws -> T {
        let request = try await makeRequest(path: path, method: "GET", query: query, authenticated: authenticated)
        return try await perform(request)
    }

    func post<T: Decodable>(
        path: String,
        query: [URLQueryItem] = [],
        body: [String: any Sendable],
        authenticated: Bool = true
    ) async throws -> T {
        var request = try await makeRequest(path: path, method: "POST", query: query, authenticated: authenticated)
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.foundationJSONObject(body))
        return try await perform(request)
    }

    func patch<T: Decodable>(
        path: String,
        query: [URLQueryItem] = [],
        body: [String: any Sendable],
        authenticated: Bool = true
    ) async throws -> T {
        var request = try await makeRequest(path: path, method: "PATCH", query: query, authenticated: authenticated)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.foundationJSONObject(body))
        return try await perform(request)
    }

    nonisolated static func foundationJSONObject(
        _ body: [String: any Sendable]
    ) -> [String: Any] {
        var result: [String: Any] = [:]
        result.reserveCapacity(body.count)
        for (key, value) in body {
            result[key] = value is SupabaseJSONNull ? NSNull() : value
        }
        return result
    }

    /// Calls a Postgres function. All MORT financial logic lives behind RPCs
    /// like this — the app only forwards arguments and renders results.
    func rpc<T: Decodable>(
        _ function: String,
        args: [String: any Sendable] = [:]
    ) async throws -> T {
        try await post(path: "/rest/v1/rpc/\(function)", body: args)
    }

    /// Calls an authenticated Supabase Edge Function. The function slug is
    /// validated locally and the request still carries only the public key +
    /// current user JWT; privileged credentials never enter the app.
    func function<T: Decodable>(
        _ slug: String,
        body: [String: any Sendable] = [:]
    ) async throws -> T {
        guard let path = Self.edgeFunctionPath(for: slug) else {
            throw MortError.notConfigured("Edge Function")
        }
        return try await post(path: path, body: body, authenticated: true)
    }

    /// Uploads job proof/evidence to Storage.
    func upload(bucket: String, path: String, data: Data, contentType: String) async throws {
        var request = try await makeRequest(
            path: "/storage/v1/object/\(bucket)/\(path)",
            method: "POST",
            query: [],
            authenticated: true
        )
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let _: EmptyResponse = try await perform(request)
    }

    // MARK: - Error mapping

    private static func map(urlError: URLError) -> MortError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .offline
        case .timedOut: .timeout
        default: .unknown
        }
    }

    private static func map(status: Int, data: Data) -> MortError {
        // Surface only the backend's safe `message`; never raw internals.
        let safeMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            .flatMap { ($0?["message"] ?? $0?["error_description"]) as? String }
        switch status {
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 409: return .rejected(safeMessage ?? "That conflicts with something that already exists.")
        case 422: return .rejected(safeMessage ?? "Some details weren't accepted.")
        case 429: return .rateLimited
        case 500...599: return .serverUnavailable
        default: return .rejected(safeMessage ?? MortError.unknown.userMessage)
        }
    }
}

// MARK: - Wire types

nonisolated struct EmptyResponse: Codable, Sendable {
    init() {}
}

nonisolated struct PasswordGuardResponse: Decodable, Sendable {
    let ok: Bool
    let auth: PasswordGuardAuthResponse?
}

private nonisolated struct PasswordGuardFailure: Decodable, Sendable {
    let code: String
}

nonisolated struct PasswordGuardAuthResponse: Decodable, Sendable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: AuthTokenResponse.User?
}

nonisolated struct AuthTokenResponse: Codable, Sendable {
    nonisolated struct User: Codable, Sendable {
        let id: String
        let email: String?
    }
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
}
