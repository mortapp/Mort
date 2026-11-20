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
}
