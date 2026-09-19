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
import StripePaymentSheet
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
    /// Registered custom-scheme return route for redirect-capable payment methods.
    /// Keep this in sync with ios/project.yml.
    nonisolated static let returnURLString = "com.mortapp.mobile://stripe-redirect"

    init() {}

    @MainActor
    func present(handle: PaymentIntentHandle) async -> ProviderSheetOutcome {
        #if canImport(UIKit)
        // Both values are provider-created, short-lived presentation material.
        // Reject malformed input rather than handing arbitrary strings to the SDK.
        guard
            handle.clientSecret.hasPrefix("pi_"),
            handle.clientSecret.contains("_secret_"),
            handle.publishableKey.hasPrefix("pk_test_") || handle.publishableKey.hasPrefix("pk_live_"),
            let presenter = Self.topViewController()
        else {
            return .failed(.providerUnavailable)
        }

        StripeAPI.defaultPublishableKey = handle.publishableKey

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = handle.merchantDisplayName
        configuration.style = .alwaysDark
        configuration.returnURL = Self.returnURLString

        // The backend currently creates legacy Customer ephemeral keys.
        // Only configure saved-method access when both pieces are present;
        // PaymentSheet can still collect a new method without them.
        if
            let customerId = handle.customerId,
            !customerId.isEmpty,
            let ephemeralKey = handle.customerEphemeralKeySecret,
            !ephemeralKey.isEmpty
        {
            configuration.customer = .init(
                id: customerId,
                ephemeralKeySecret: ephemeralKey
            )
        }

        // Apple Pay is opt-in. Never invent a merchant identifier on-device.
        if let merchantId = handle.applePayMerchantId, !merchantId.isEmpty {
            configuration.applePay = .init(
                merchantId: merchantId,
                merchantCountryCode: "US"
            )
        }

        let paymentSheet = PaymentSheet(
            paymentIntentClientSecret: handle.clientSecret,
            configuration: configuration
        )
        let result = await paymentSheet.present(from: presenter)

        // IMPORTANT: this is only a UI/provider-sheet result. The caller must
        // reconcile with the MORT backend before treating money as moved.
        switch result {
        case .completed:
            return .completed
        case .canceled:
            return .canceled
        case .failed:
            return .failed(.unknown)
        }
        #else
        return .failed(.providerUnavailable)
        #endif
    }

    @MainActor
    static func handleURLCallback(_ url: URL) -> Bool {
        StripeAPI.handleURLCallback(with: url)
    }

    #if canImport(UIKit)
    @MainActor
    private static func topViewController() -> UIViewController? {
        let base = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        return topViewController(from: base)
    }

    @MainActor
    private static func topViewController(from base: UIViewController?) -> UIViewController? {
        if let navigation = base as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(from: presented)
        }
        return base
    }
    #endif

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
