//
//  PaymentState.swift
//  MORT iOS V8 — Payment OS Models
//
//  The Payment OS state machine presentation table.
//
//  ARCHITECTURE (do NOT redesign into a destination-charge UX):
//    PRE-WORK PLATFORM FUNDING
//      -> PROVIDER CONFIRMATION
//      -> JOB FUNDED / STARTABLE
//      -> WORK
//      -> AUTHORITATIVE SETTLEMENT
//      -> SEPARATE CONNECT TRANSFER
//      -> COMPONENT REFUND IF REQUIRED
//      -> OPTIONAL POST-WORK TIP
//
//  Every state below is reported BY THE BACKEND. Swift never decides a
//  payment outcome, and the UI fails closed when no terminal state exists.
//

import Foundation

/// Payment states as the UI may present them.
nonisolated enum PaymentState: String, Codable, Sendable, CaseIterable {
    /// Review screen: quote loaded, nothing submitted.
    case ready
    /// Submitted; in flight with the provider.
    case processing
    /// Provider requires extra verification (e.g. bank app / 3DS).
    case requiresAction
    /// Backend + provider CONFIRMED the funding. Means JOB FUNDED.
    /// Does NOT mean the teen was paid or earnings were settled.
    case funded
    /// Provider declined with a safe mapped reason.
    case declined
    /// Network interrupted mid-charge; outcome not known by the client.
    case failedNetwork
    /// Provider unreachable before the charge could complete.
    case providerUnavailable
    /// Backend reports still-checking.
    case pending
    /// User cancelled before completion.
    case cancelled
    /// Outcome unknown; needs reconciliation with the backend.
    case unknown
    /// A second submission was blocked while one was already in flight.
    case duplicateBlocked
    /// The displayed quote is no longer valid and must be refreshed.
    case quoteExpired

    /// Terminal states that must never be re-submitted blindly.
    var isTerminal: Bool {
        switch self {
        case .funded, .declined, .cancelled: true
        default: false
        }
    }

    /// True when NO receipt exists for this state. Strict rule:
    /// failed transactions receive no receipt, ever.
    var producesNoReceipt: Bool {
        switch self {
        case .declined, .failedNetwork, .providerUnavailable, .cancelled,
             .duplicateBlocked, .quoteExpired:
            true
        case .ready, .processing, .requiresAction, .funded, .pending, .unknown:
            false
        }
    }
}

/// Visual presentation for a payment state. Tone NEVER travels alone:
/// tone + symbol + label always ship together.
nonisolated struct PaymentStatePresentation: Sendable {
    let tone: MortTone
    let symbol: String
    let label: String
    /// What this state means, in plain honest language.
    let purpose: String
    /// What the user should do next.
    let guidance: String
    let showsSpinner: Bool
    /// Shows the explicit "no receipt was created" banner.
    let showsNoReceiptBanner: Bool
    /// Shows the duplicate-payment protection reassurance.
    let showsDuplicateSafety: Bool

    static func of(_ state: PaymentState) -> PaymentStatePresentation {
        switch state {
        case .ready:
            .init(
                tone: .info, symbol: "shield.lefthalf.filled", label: "READY TO FUND",
                purpose: "This holds the job funds on the MORT platform.",
                guidance: "Funding the job lets the work start. Your worker is paid after the job is confirmed.",
                showsSpinner: false, showsNoReceiptBanner: false, showsDuplicateSafety: false
            )
        case .processing:
            .init(
                tone: .info, symbol: "arrow.triangle.2.circlepath", label: "PROCESSING",
                purpose: "We're confirming this with your payment provider.",
                guidance: "Keep this screen open. Don't submit again — we've got this one.",
                showsSpinner: true, showsNoReceiptBanner: false, showsDuplicateSafety: true
            )
        case .requiresAction:
            .init(
                tone: .warning, symbol: "hand.raised", label: "VERIFICATION NEEDED",
                purpose: "Your bank wants to confirm it's really you.",
                guidance: "Continue to your bank's verification, then come back here.",
                showsSpinner: false, showsNoReceiptBanner: false, showsDuplicateSafety: true
            )
        case .funded:
            .init(
                tone: .success, symbol: "checkmark.circle", label: "JOB FUNDED",
                purpose: "The funds are held by MORT for this job.",
                guidance: "Your worker can start. Earnings are settled after the job is confirmed complete.",
                showsSpinner: false, showsNoReceiptBanner: false, showsDuplicateSafety: false
            )
        case .declined:
            .init(
                tone: .danger, symbol: "xmark.circle", label: "DECLINED",
                purpose: "Your payment provider didn't approve this payment.",
                guidance: "Nothing was charged. You can try a different payment method.",
                showsSpinner: false, showsNoReceiptBanner: true, showsDuplicateSafety: false
            )
        case .failedNetwork:
            .init(
                tone: .danger, symbol: "wifi.exclamationmark", label: "CONNECTION LOST",
                purpose: "The connection dropped before we got an answer.",
                guidance: "Check the payment status before trying again — we don't want to fund this twice.",
                showsSpinner: false, showsNoReceiptBanner: true, showsDuplicateSafety: true
            )
        case .providerUnavailable:
            .init(
                tone: .warning, symbol: "exclamationmark.icloud", label: "PROVIDER UNAVAILABLE",
                purpose: "Our payment provider isn't reachable right now.",
                guidance: "Nothing was charged. Please try again in a few minutes.",
                showsSpinner: false, showsNoReceiptBanner: true, showsDuplicateSafety: false
            )
        case .pending:
            .init(
                tone: .warning, symbol: "hourglass", label: "STILL CHECKING",
                purpose: "This payment hasn't finished confirming yet.",
                guidance: "We're still checking with your provider. You don't need to pay again.",
                showsSpinner: false, showsNoReceiptBanner: false, showsDuplicateSafety: true
            )
        case .cancelled:
            .init(
                tone: .neutral, symbol: "slash.circle", label: "CANCELLED",
                purpose: "This payment was cancelled before it completed.",
                guidance: "Nothing was charged. You can return to the job and fund it when you're ready.",
                showsSpinner: false, showsNoReceiptBanner: true, showsDuplicateSafety: false
            )
        case .unknown:
            .init(
                tone: .warning, symbol: "questionmark.circle", label: "CHECKING STATUS",
                purpose: "We don't have a final answer for this payment yet.",
                guidance: "We're reconciling with your provider. Don't submit again — check the status here.",
                showsSpinner: false, showsNoReceiptBanner: false, showsDuplicateSafety: true
            )
        case .duplicateBlocked:
            .init(
                tone: .warning, symbol: "exclamationmark.shield", label: "ALREADY SUBMITTED",
                purpose: "We blocked a second payment for this job.",
                guidance: "Your first payment is still being processed. Check its status instead of paying again.",
                showsSpinner: false, showsNoReceiptBanner: true, showsDuplicateSafety: true
            )
        case .quoteExpired:
            .init(
                tone: .warning, symbol: "clock.arrow.circlepath", label: "AMOUNT EXPIRED",
                purpose: "This total is out of date and can't be used.",
                guidance: "Refresh the amount so you're funding the correct total.",
                showsSpinner: false, showsNoReceiptBanner: true, showsDuplicateSafety: false
            )
        }
    }
}

/// Safe, user-facing failure reasons. The BACKEND maps raw provider codes to
/// these keys — raw codes must never reach the client or the screen.
nonisolated enum PaymentFailureReason: String, Codable, Sendable, CaseIterable {
    case cardDeclined
    case insufficientFunds
    case expiredCard
    case incorrectDetails
    case bankRejected
    case verificationFailed
    case networkInterrupted
    case providerUnavailable
    case riskBlocked
    case unknown

    var title: String {
        switch self {
        case .cardDeclined: "Your card was declined"
        case .insufficientFunds: "Not enough available funds"
        case .expiredCard: "That card has expired"
        case .incorrectDetails: "Some card details didn't match"
        case .bankRejected: "Your bank rejected the payment"
        case .verificationFailed: "Verification wasn't completed"
        case .networkInterrupted: "The connection dropped"
        case .providerUnavailable: "Payments are temporarily unavailable"
        case .riskBlocked: "This payment needs a review"
        case .unknown: "This payment didn't go through"
        }
    }

    var detail: String {
        switch self {
        case .cardDeclined: "Your bank didn't approve it. Trying a different method usually works."
        case .insufficientFunds: "The account didn't have enough available balance for this total."
        case .expiredCard: "Add an updated card and try funding the job again."
        case .incorrectDetails: "Double-check the card details, or use a different payment method."
        case .bankRejected: "Your bank blocked this one. They can tell you why."
        case .verificationFailed: "The extra verification step wasn't finished."
        case .networkInterrupted: "We're not sure whether it went through. Check the status first."
        case .providerUnavailable: "Nothing was charged. Please try again shortly."
        case .riskBlocked: "Our team needs to review this before it can go through."
        case .unknown: "No money was taken. You can try again or use another method."
        }
    }
}
