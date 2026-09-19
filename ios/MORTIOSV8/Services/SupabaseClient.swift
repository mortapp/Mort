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
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(config: SupabaseConfig, keychain: MortKeychain = MortKeychain()) {
        self.config = config
        self.session = keychain
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.waitsForConnectivity = false
        self.urlSession = URLSession(configuration: configuration)

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
        authenticated: Bool
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
        if authenticated {
            let token = try await validAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            throw Self.map(urlError: error)
        }
        guard let http = response as? HTTPURLResponse else { throw MortError.unknown }
        guard (200..<300).contains(http.statusCode) else {
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

nonisolated struct AuthTokenResponse: Codable, Sendable {
    nonisolated struct User: Codable, Sendable {
        let id: String
        let email: String?
    }
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}
