//
//  StripeReturnRouteTests.swift
//  MORT iOS V8
//
//  Redirect-capable payment methods must return through one deterministic
//  custom URL scheme that the SwiftUI app forwards back to Stripe.
//

import Foundation
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

    @Test("Expired or used recovery links surface their error instead of tokens")
    func expiredRecoveryLinkIsRecognised() {
        let url = URL(string: "com.mortapp.mobile://app/auth-callback#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired")!
        let values = MortRootView.recoveryParameters(from: url)
        #expect(values?["error_code"] == "otp_expired")
        #expect(values?["access_token"] == nil)
    }

    @Test("Password reset emails redirect to the callback the app accepts")
    func passwordResetRedirectMatchesCallback() {
        let redirect = URL(string: LiveAuthService.passwordRecoveryRedirect + "#access_token=a.b.c&refresh_token=r&expires_in=60&type=recovery")!
        #expect(MortRootView.recoveryParameters(from: redirect)?["type"] == "recovery")
    }
}
