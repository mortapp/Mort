//
//  SupabaseTransportContractTests.swift
//  MORT iOS V8
//
//  Public client configuration and Edge Function routing are part of the
//  shipping client contract. Secrets must never be accepted here.
//

import Foundation
import Testing
@testable import MORTIOSV8

struct SupabaseTransportContractTests {
    @Test("Shipping iOS build resolves the public MORT Supabase endpoint")
    func publicConfigurationIsPresent() throws {
        let config = try #require(SupabaseConfig.fromEnvironment())
        #expect(config.url.absoluteString == "https://jxbnrkasktbhtiujkhay.supabase.co")
        #expect(config.anonKey.hasPrefix("sb_publishable_"))
        #expect(!config.anonKey.contains("service_role"))
        #expect(!config.anonKey.hasPrefix("sb_secret_"))
    }

    @Test("Edge Function paths are canonical and reject unsafe slugs")
    func edgeFunctionPaths() {
        #expect(SupabaseClient.edgeFunctionPath(for: MortBackendContract.EdgeFunction.stripeConfig)
                == "/functions/v1/stripe-config")
        #expect(SupabaseClient.edgeFunctionPath(for: MortBackendContract.EdgeFunction.paymentIntent)
                == "/functions/v1/stripe-create-job-payment-intent")
        #expect(SupabaseClient.edgeFunctionPath(for: "../stripe-config") == nil)
        #expect(SupabaseClient.edgeFunctionPath(for: "stripe/config") == nil)
        #expect(SupabaseClient.edgeFunctionPath(for: "") == nil)
    }



    @Test("RPC transport converts explicit nullable arguments to JSON null")
    func explicitNullEncoding() {
        let object = SupabaseClient.foundationJSONObject([
            "required": "value",
            "optional": SupabaseJSONNull(),
        ])
        #expect(object["required"] as? String == "value")
        #expect(object["optional"] is NSNull)
    }

    @Test("Edge Function invocation rejects unsafe slugs before network or auth")
    func edgeFunctionInvocationFailsClosedForUnsafeSlug() async throws {
        let config = try #require(SupabaseConfig.fromEnvironment())
        let client = SupabaseClient(config: config)

        await #expect(throws: MortError.self) {
            let _: EdgeProbeResponse = try await client.function(
                "../stripe-config",
                body: [:]
            )
        }
    }

    @Test("Ordinary Auth token grants decode the snake-case response", arguments: [
        "password", "id_token", "refresh_token",
    ])
    func ordinaryAuthTokenResponseDecodes(_ grant: String) async throws {
        let url = try #require(URL(string: "https://qa-mock.invalid"))
        let client = SupabaseClient(
            config: SupabaseConfig(url: url, anonKey: "sb_publishable_fixture"),
            sendRequest: { request in
                let endpoint = try #require(request.url)
                try #require(endpoint.host == "qa-mock.invalid")
                try #require(endpoint.path == "/auth/v1/token")
                try #require(endpoint.query == "grant_type=\(grant)")
                try #require(request.httpMethod == "POST")
                let response = try #require(HTTPURLResponse(
                    url: endpoint, statusCode: 200, httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                ))
                let body = #"{"access_token":"fixture-access","refresh_token":"fixture-refresh","expires_in":3600,"user":{"id":"fixture-user"}}"#
                return (Data(body.utf8), response)
            }
        )
        let result: AuthTokenResponse = try await client.post(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: grant)],
            body: [:],
            authenticated: false
        )
        #expect(result.accessToken == "fixture-access")
        #expect(result.refreshToken == "fixture-refresh")
        #expect(result.expiresIn == 3600)
        #expect(result.user.id == "fixture-user")
    }
}

private nonisolated struct EdgeProbeResponse: Decodable, Sendable {
    let ok: Bool?
}
