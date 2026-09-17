//
//  SupabaseTransportContractTests.swift
//  MORT iOS V8
//
//  Public client configuration and Edge Function routing are part of the
//  shipping client contract. Secrets must never be accepted here.
//

import Testing
@testable import MORTIOSV8

struct SupabaseTransportContractTests {
    @Test("Shipping iOS build resolves the public MORT Supabase endpoint")
    func publicConfigurationIsPresent() throws {
        let config = try #require(SupabaseConfig.fromEnvironment())
        #expect(config.url.absoluteString == "https://rakjydmgwwgtdislanbt.supabase.co")
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
}
