import Foundation
import Testing
@testable import MORTIOSV8

struct PasswordRecoveryTests {
    @Test("Only the canonical callback opens password recovery")
    func canonicalCallback() throws {
        let fragment = "access_token=access.jwt.token&refresh_token=refresh-value&expires_in=3600&type=recovery"
        let url = try #require(URL(string: "\(PasswordRecoveryLink.callbackURL)#\(fragment)"))
        #expect(PasswordRecoveryLink.route(url) == .recovery(PasswordRecoveryLink(
            accessToken: "access.jwt.token", refreshToken: "refresh-value", expiresIn: 3600
        )))
    }

    @Test(
        "Noncanonical URLs never open recovery",
        arguments: [
            "https://example.invalid/auth-callback",
            "com.mortapp.mobile://example.invalid/auth-callback",
            "com.mortapp.mobile://app:443/auth-callback",
            "com.mortapp.mobile://nobody@app/auth-callback",
            "com.mortapp.mobile://app/auth%2Dcallback",
            "com.mortapp.mobile://app/auth-callback/extra",
        ]
    )
    func noncanonicalCallback(_ base: String) throws {
        let url = try #require(URL(string: "\(base)#access_token=a.b.c&refresh_token=r&expires_in=3600&type=recovery"))
        #expect(PasswordRecoveryLink.route(url) == .unrelated)
    }

    @Test(
        "Malformed and provider-expired callbacks are unavailable",
        arguments: [
            "error=access_denied&error_code=otp_expired",
            "type=recovery&access_token=a.b.c&expires_in=3600",
            "type=recovery&access_token=a.b.c&refresh_token=r",
            "type=recovery&access_token=a.b.c&refresh_token=r&expires_in=0",
            "type=recovery&access_token=a.b.c&refresh_token=r&expires_in=86401",
            "type=recovery&access_token=a.b.c&refresh_token=r&expires_in=abc",
            "type=recovery&access_token=a.b.c&%61ccess_token=duplicate&refresh_token=r&expires_in=3600",
            "type=recovery&access_token=a.b.c&refresh_token=%20&expires_in=3600",
            "type=recovery&access_token=a.b.c&refresh_token=r&expires_in=3600&bad",
        ]
    )
    func malformedCallback(_ fragment: String) throws {
        let url = try #require(URL(string: "\(PasswordRecoveryLink.callbackURL)#\(fragment)"))
        #expect(PasswordRecoveryLink.route(url) == .unavailable)
    }

    @Test("Query and fragment cannot be mixed for recovery; ordinary OAuth is not intercepted")
    func unrelatedAuthCallback() throws {
        let base = PasswordRecoveryLink.callbackURL
        let oauth = try #require(URL(string: "\(base)?code=placeholder"))
        let mixed = try #require(URL(string: "\(base)?code=placeholder#type=recovery"))
        #expect(PasswordRecoveryLink.route(oauth) == .unrelated)
        #expect(PasswordRecoveryLink.route(mixed) == .unavailable)
    }

    @Test("Reset email requests the registered callback through GoTrue")
    func resetEmailRedirect() async throws {
        let transport = RecoveryProbe([.init(path: "/auth/v1/recover", method: "POST")])
        let client = makeClient(transport)
        try await LiveAuthService(client: client).sendPasswordReset(email: "qa@example.invalid")
        let requests = await transport.requests()
        let request = try #require(requests.first)
        let components = try #require(request.url.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)
        })
        #expect(components.queryItems == [
            URLQueryItem(name: "redirect_to", value: PasswordRecoveryLink.callbackURL),
        ])
        #expect(json(request)["email"] as? String == "qa@example.invalid")
    }

    @Test("Expired or malformed JWT and missing refresh token never go to Auth")
    func localClaimsChecks() async throws {
        let transport = RecoveryProbe([])
        let client = makeClient(transport)
        let expired = try token(exp: Self.clock.timeIntervalSince1970 - 1)
        await #expect(throws: MortError.unauthorized) {
            try await client.establishRecoverySession(accessToken: expired, refreshToken: "r", expiresIn: 3600)
        }
        await #expect(throws: MortError.unauthorized) {
            try await client.establishRecoverySession(accessToken: "not.a.jwt", refreshToken: "r", expiresIn: 3600)
        }
        let validShape = try token()
        await #expect(throws: MortError.unauthorized) {
            try await client.establishRecoverySession(accessToken: validShape, refreshToken: "", expiresIn: 3600)
        }
        #expect(await transport.requests().isEmpty)
    }

    @Test("GoTrue rejects an unverified bearer before refresh or any session write")
    func unverifiedBearerRejected() async throws {
        let transport = RecoveryProbe([.init(path: "/auth/v1/user", method: "GET", status: 401)])
        let client = makeClient(transport)
        let access = try token()
        await #expect(throws: MortError.unauthorized) {
            try await client.establishRecoverySession(accessToken: access, refreshToken: "r", expiresIn: 3600)
        }
        #expect(await client.storedSession() == nil)
        #expect(await transport.requests().count == 1)
    }

    @Test("GoTrue user ID must match the JWT subject")
    func userMismatchRejected() async throws {
        let transport = RecoveryProbe([try userReply(id: UUID())])
        let client = makeClient(transport)
        let access = try token()
        await #expect(throws: MortError.unauthorized) {
            try await client.establishRecoverySession(accessToken: access, refreshToken: "r", expiresIn: 3600)
        }
        #expect(await transport.requests().count == 1)
        #expect(await client.storedSession() == nil)
    }

    @Test("Access and refresh credentials must belong to the same GoTrue session")
    func refreshMismatchRejected() async throws {
        let transport = RecoveryProbe([try userReply(), try refreshReply(jwt: token(sessionID: UUID()))])
        let client = makeClient(transport)
        let access = try token()
        await #expect(throws: MortError.unauthorized) {
            try await client.establishRecoverySession(accessToken: access, refreshToken: "r", expiresIn: 3600)
        }
        await #expect(throws: MortError.unauthorized) {
            try await client.updateRecoveryPassword("not sent")
        }
        #expect(await transport.requests().count == 2)
        #expect(await client.storedSession() == nil)
    }

    @Test("Refresh exchange failure does not authorize a password update")
    func refreshFailureRejected() async throws {
        let transport = RecoveryProbe([
            try userReply(),
            .init(path: "/auth/v1/token", method: "POST", status: 400),
        ])
        let client = makeClient(transport)
        let access = try token()
        await #expect(throws: MortError.self) {
            try await client.establishRecoverySession(accessToken: access, refreshToken: "r", expiresIn: 3600)
        }
        await #expect(throws: MortError.unauthorized) {
            try await client.updateRecoveryPassword("not sent")
        }
        #expect(await transport.requests().count == 2)
    }

    @Test("A consumed recovery callback is rejected after a new client launches")
    func replayRejectedAfterRelaunch() async throws {
        let suite = "mort.recovery.test.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let access = try token()
        let initial = RecoveryProbe([try userReply(), try refreshReply(jwt: token())])
        let client = makeClient(initial, suite: suite)
        try await client.establishRecoverySession(accessToken: access, refreshToken: "r", expiresIn: 3600)

        let reloaded = RecoveryProbe([])
        let newClient = makeClient(reloaded, suite: suite)
        await #expect(throws: MortError.unauthorized) {
            try await newClient.establishRecoverySession(accessToken: access, refreshToken: "r", expiresIn: 3600)
        }
        #expect(await reloaded.requests().isEmpty)
        #expect(await newClient.storedSession() == nil)
    }

    @Test("Guarded update uses only the verified recovery bearer and logs out locally scoped")
    func guardedUpdate() async throws {
        let original = try token()
        let refreshed = try token(exp: Self.clock.timeIntervalSince1970 + 1800)
        let transport = RecoveryProbe([
            try userReply(),
            try refreshReply(jwt: refreshed),
            .init(path: "/functions/v1/password-guard", method: "POST", json: #"{"ok":true,"auth":{}}"#),
            .init(path: "/auth/v1/logout", method: "POST", status: 503),
        ])
        let client = makeClient(transport)
        let auth = LiveAuthService(client: client)
        try await auth.establishPasswordRecoverySession(accessToken: original, refreshToken: "supplied-r", expiresIn: 3600)
        #expect(await client.storedSession() == nil)
        try await auth.updatePassword("Synthetic-QA-only-Password-11!")

        let requests = await transport.requests()
        #expect(requests.count == 4)
        let user = try #require(requests.first)
        let refresh = try #require(requests.dropFirst().first)
        let guardCall = try #require(requests.dropFirst(2).first)
        let logout = try #require(requests.last)
        #expect(user.value(forHTTPHeaderField: "Authorization") == "Bearer \(original)")
        #expect(refresh.url?.query == "grant_type=refresh_token")
        #expect(json(refresh)["refresh_token"] as? String == "supplied-r")
        #expect(guardCall.value(forHTTPHeaderField: "Authorization") == "Bearer \(refreshed)")
        #expect(json(guardCall)["action"] as? String == "update_password")
        #expect(logout.url?.query == "scope=local")
        #expect(await client.storedSession() == nil)
        await #expect(throws: MortError.unauthorized) {
            try await auth.updatePassword("Cannot be retried")
        }
        #expect(await transport.requests().count == 4)
    }

    @Test("Password-guard policy rejection does not fall back to a direct Auth password write")
    func policyFailureRemainsGuarded() async throws {
        let transport = RecoveryProbe([
            try userReply(),
            try refreshReply(jwt: token()),
            .init(path: "/functions/v1/password-guard", method: "POST", status: 422,
                  json: #"{"ok":false,"code":"leaked_password_compromised"}"#),
        ])
        let client = makeClient(transport)
        let access = try token()
        try await client.establishRecoverySession(accessToken: access, refreshToken: "r", expiresIn: 3600)
        await #expect(throws: MortError.rejected("That password appears in a known data breach. Choose a different one.")) {
            try await client.updateRecoveryPassword("Synthetic-QA-only-rejection")
        }
        #expect(await transport.requests().count == 3)
    }

    private static let clock = Date(timeIntervalSince1970: 1_800_000_000)
    private static let userID = UUID(uuidString: "77a21cb3-c61a-4808-89cd-fc70a9890bc1")!
    private static let sessionID = UUID(uuidString: "b9a4a0f5-a2ee-43af-abcf-5534fa42e277")!

    private func makeClient(_ transport: RecoveryProbe, suite: String? = nil) -> SupabaseClient {
        SupabaseClient(
            config: SupabaseConfig(url: URL(string: "https://qa-mock.invalid")!, anonKey: "sb_publishable_fixture"),
            keychain: MortKeychain(service: "com.mort.ios.test.\(UUID().uuidString)"),
            recoveryReplayStore: PasswordRecoveryReplayStore(suiteName: suite ?? "mort.recovery.test.\(UUID().uuidString)"),
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            sendRequest: { request in try await transport.send(request) }
        )
    }

    private func token(
        sessionID: UUID = Self.sessionID,
        exp: Double = Self.clock.timeIntervalSince1970 + 3600
    ) throws -> String {
        let payload = try JSONSerialization.data(withJSONObject: [
            "sub": Self.userID.uuidString,
            "session_id": sessionID.uuidString,
            "exp": exp,
        ])
        let encoded = payload.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "header.\(encoded).fixture"
    }

    private func userReply(id: UUID = Self.userID) throws -> RecoveryProbe.Step {
        .init(path: "/auth/v1/user", method: "GET", json: try encoded(["id": id.uuidString]))
    }

    private func refreshReply(jwt: String) throws -> RecoveryProbe.Step {
        .init(path: "/auth/v1/token", method: "POST", json: try encoded([
            "access_token": jwt, "refresh_token": "rotated-fixture",
            "expires_in": 3600, "user": ["id": Self.userID.uuidString],
        ]))
    }

    private func encoded(_ object: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func json(_ request: URLRequest) -> [String: Any] {
        guard let data = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }
}

private actor RecoveryProbe {
    nonisolated struct Step: Sendable {
        let path: String
        let method: String
        var status = 200
        var json = "{}"
    }

    private enum ProbeError: Error { case unexpectedRequest }
    private var script: [Step]
    private var observed: [URLRequest] = []

    init(_ script: [Step]) { self.script = script }

    func send(_ request: URLRequest) throws -> (Data, URLResponse) {
        observed.append(request)
        guard !script.isEmpty, let url = request.url else { throw ProbeError.unexpectedRequest }
        let step = script.removeFirst()
        guard url.host == "qa-mock.invalid", url.path == step.path, request.httpMethod == step.method,
              let response = HTTPURLResponse(
                  url: url, statusCode: step.status, httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/json"]
              ) else { throw ProbeError.unexpectedRequest }
        return (Data(step.json.utf8), response)
    }

    func requests() -> [URLRequest] { observed }
}
