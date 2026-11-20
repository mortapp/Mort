//
//  StripeReturnRouteTests.swift
//  MORT iOS V8
//
//  Redirect-capable payment methods must return through one deterministic
//  custom URL scheme that the SwiftUI app forwards back to Stripe.
//

import Testing
@testable import MORTIOSV8

struct StripeReturnRouteTests {
    @Test("Stripe PaymentSheet uses the registered MORT custom return URL")
    func returnURLIsCanonical() {
        #expect(StripePaymentSheetAdapter.returnURLString == "com.mortapp.mobile://stripe-redirect")
    }

    @Test("Supabase recovery callback fragment is parsed while signed out")
    func recoveryCallbackFragmentIsParsed() {
        let url = URL(string: "com.mortapp.mobile://app/auth-callback#access_token=access.jwt.token&refresh_token=refresh-value&expires_in=3600&type=recovery")!
        let values = MortRootView.recoveryParameters(from: url)
        #expect(values?["type"] == "recovery")
        #expect(values?["access_token"] == "access.jwt.token")
        #expect(values?["refresh_token"] == "refresh-value")
        #expect(values?["expires_in"] == "3600")
    }

    @Test("Recovery fragments from non-canonical URLs are ignored")
    func nonCanonicalRecoveryURLIsRejected() {
        let url = URL(string: "https://attacker.example/auth-callback#access_token=access.jwt.token&type=recovery")!
        #expect(MortRootView.recoveryParameters(from: url) == nil)
    }
}
