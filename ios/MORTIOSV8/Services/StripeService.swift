//
//  StripeService.swift
//  MORT iOS V8 — Services / Stripe integration target
//
//  ============================================================
//  INTEGRATION TARGET — VS CODE WIRES THIS
//  ============================================================
//  This file defines the COMPLETE native payment-presentation boundary MORT
//  needs. It deliberately contains NO Stripe SDK import so the project builds
//  without external packages; `StripePaymentSheetAdapter` is the single place
//  to drop `import StripePaymentSheet` and the real PaymentSheet calls.
//
//  HARD RULES (non-negotiable):
//   - NEVER embed a publishable-live, secret or restricted key in source.
//     The publishable key is fetched from the backend at runtime.
//   - NEVER create a PaymentIntent on device. The backend creates it and
//     returns only the client secret.
//   - NEVER interpret a local sheet result as financial truth. After the
//     sheet completes, the app ALWAYS re-reads authoritative state from the
//     MORT backend (`PaymentRepository.fundingStatus`).
//   - Duplicate submission is blocked with a backend idempotency key.
//   - Pre-work funding is a PLATFORM charge. Do NOT convert this into a
//     destination charge: the Connect transfer happens separately, after
//     authoritative settlement.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// What the backend returns when funding starts. The client secret is the only
/// provider material the app is allowed to hold, and only in memory.
nonisolated struct PaymentIntentHandle: Sendable {
    /// Stripe PaymentIntent client secret, created BY THE BACKEND.
    let clientSecret: String
    /// Publishable key supplied by the backend at runtime (never hardcoded).
    let publishableKey: String
    /// Optional Stripe Customer ephemeral key for saved-method display.
    let customerEphemeralKeySecret: String?
    let customerId: String?
    /// Human label shown in the sheet.
    let merchantDisplayName: String
    /// Apple Pay merchant identifier, when Apple Pay is enabled.
    let applePayMerchantId: String?
}

/// The outcome of presenting the provider sheet. This is a UI-level result
/// ONLY — it is never treated as the authoritative payment state.
nonisolated enum ProviderSheetOutcome: Sendable, Equatable {
    /// The sheet reported completion. The backend must still confirm.
    case completed
    /// The user dismissed the sheet.
    case canceled
    /// The sheet failed locally, mapped to a safe reason.
    case failed(PaymentFailureReason)
}

/// The native payment-sheet boundary.
protocol ProviderPaymentSheet: Sendable {
    /// Presents the provider's payment sheet for a backend-created intent.
    @MainActor
    func present(handle: PaymentIntentHandle) async -> ProviderSheetOutcome

    /// Presents provider (Connect) onboarding for teen payouts.
    @MainActor
    func presentPayoutOnboarding(url: URL) async -> Bool
}

/// The production adapter.
///
/// INTEGRATION STEPS FOR VS CODE:
///  1. Add the Swift package `https://github.com/stripe/stripe-ios-spm`
///     (products: `StripePaymentSheet`).
///  2. `import StripePaymentSheet` below.
///  3. Replace the body of `present(handle:)` with:
///       StripeAPI.defaultPublishableKey = handle.publishableKey
///       var config = PaymentSheet.Configuration()
///       config.merchantDisplayName = handle.merchantDisplayName
///       if let cid = handle.customerId, let ek = handle.customerEphemeralKeySecret {
///           config.customer = .init(id: cid, ephemeralKeySecret: ek)
///       }
///       if let merchantId = handle.applePayMerchantId {
///           config.applePay = .init(merchantId: merchantId, merchantCountryCode: "US")
///       }
///       config.style = .alwaysDark   // matches the MORT shell
///       let sheet = PaymentSheet(paymentIntentClientSecret: handle.clientSecret,
///                                configuration: config)
///       // present from the active scene's root view controller
///  4. Map the SDK result to `ProviderSheetOutcome` WITHOUT inferring success
///     for the MORT backend — the caller re-reads `fundingStatus` regardless.
///  5. Add the `CFBundleURLTypes` entry + `returnURL` for redirect-based
///     methods (see the handoff's Info.plist section).
///
/// Until step 1-3 are done this adapter fails CLOSED: it reports a provider
/// failure and the UI shows an honest "temporarily unavailable" state rather
/// than a fake confirmation.
nonisolated final class StripePaymentSheetAdapter: ProviderPaymentSheet {
    init() {}

    @MainActor
    func present(handle: PaymentIntentHandle) async -> ProviderSheetOutcome {
        // NOT WIRED YET — fail closed. Never fabricate a provider success.
        .failed(.providerUnavailable)
    }

    @MainActor
    func presentPayoutOnboarding(url: URL) async -> Bool {
        #if canImport(UIKit)
        // Connect onboarding is a normal web flow; opening it is safe and does
        // not imply the account became ready. Readiness is re-read from the
        // backend via `PayoutRepository.refreshPayoutReadiness()`.
        guard UIApplication.shared.canOpenURL(url) else { return false }
        return await UIApplication.shared.open(url)
        #else
        return false
        #endif
    }
}

/// Test/preview double. Clearly isolated: it never runs in production paths.
nonisolated final class PreviewPaymentSheet: ProviderPaymentSheet {
    private let outcome: ProviderSheetOutcome

    init(outcome: ProviderSheetOutcome = .completed) {
        self.outcome = outcome
    }

    @MainActor
    func present(handle: PaymentIntentHandle) async -> ProviderSheetOutcome {
        try? await Task.sleep(for: .milliseconds(650))
        return outcome
    }

    @MainActor
    func presentPayoutOnboarding(url: URL) async -> Bool { true }
}
