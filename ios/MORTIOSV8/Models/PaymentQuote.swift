//
//  PaymentQuote.swift
//  MORT iOS V8 — Payment OS Models
//
//  The authoritative funding quote. Every number here comes FROM THE BACKEND.
//  The client must not compute or re-derive a total it then charges.
//

import Foundation

/// A masked payment method. The app only ever sees masks — never PAN or CVV.
nonisolated struct PaymentMethodRef: Identifiable, Codable, Hashable, Sendable {
    let id: String
    /// e.g. "Visa", "Apple Pay", "Mastercard".
    let label: String
    /// Masked tail only, e.g. "•••• 4242". Provided by the server vault.
    let mask: String
    let symbol: String
    let isDefault: Bool
    /// Backend flag: expired/unusable methods are shown disabled, not hidden.
    let isUsable: Bool
}

/// Pre-work funding quote: base + MORT service fee = authoritative total.
///
/// Fee reference configuration is 8% of base, $1 minimum, $5 maximum, and it
/// is CONFIGURABLE — never an irreversible constant. The values arrive from
/// backend config; the client only displays them.
nonisolated struct PaymentQuote: Codable, Hashable, Sendable {
    let jobId: String
    let jobTitle: String
    let workerHandle: String
    /// Display order number, when the backend has issued one. Pre-funding quotes may not have one yet.\n    let orderNumber: String?\n    /// Worker base pay in cents (authoritative).
    let baseCents: Int64
    /// MORT platform service fee in cents (authoritative, adult side only).
    let feeCents: Int64
    /// The authoritative total the provider will be asked to fund.
    let totalCents: Int64
    /// Human-readable fee explanation text driven by backend config.
    let feeExplanation: String
    /// When this quote stops being valid. Expired quotes must be refreshed.
    let expiresAt: Date
    let method: PaymentMethodRef?

    var base: Money { Money(cents: baseCents) }
    var fee: Money { Money(cents: feeCents) }
    var total: Money { Money(cents: totalCents) }

    var isExpired: Bool { Date() >= expiresAt }
}

/// MORT fee configuration — CONFIGURABLE, backend-owned.
nonisolated struct MortFeeConfig: Codable, Hashable, Sendable {
    let percentBasisPoints: Int   // 800 = 8%
    let minimumCents: Int64       // 100 = $1
    let maximumCents: Int64       // 500 = $5

    static let reference = MortFeeConfig(
        percentBasisPoints: 800,
        minimumCents: 100,
        maximumCents: 500
    )

    var percentText: String { "\(percentBasisPoints / 100)%" }

    /// Preview/explanatory projection ONLY. The charged fee always comes from
    /// the backend quote — never from this function.
    func previewFee(forBaseCents base: Int64) -> Int64 {
        let raw = base * Int64(percentBasisPoints) / 10_000
        return min(max(raw, minimumCents), maximumCents)
    }

    var explanation: String {
        "MORT's service fee is \(percentText) of base pay (min \(Money(cents: minimumCents).formatted), max \(Money(cents: maximumCents).formatted)). It's added on top — never taken out of what your worker earns, and never charged on a tip."
    }
}

/// Settlement after the work is confirmed. Neither party may authoritatively
/// choose `compensatedBaseCents` — the backend decides it.
nonisolated struct SettlementResult: Codable, Hashable, Sendable {
    nonisolated enum Outcome: String, Codable, Sendable {
        case settledInFull
        case settledWithРartialRefund
        case settledWithRefund
        case disputed
        case processing
        case failedNeedsReconciliation

        var label: String {
            switch self {
            case .settledInFull: "SETTLED IN FULL"
            case .settledWithРartialRefund, .settledWithRefund: "SETTLED WITH REFUND"
            case .disputed: "DISPUTED"
            case .processing: "SETTLEMENT PROCESSING"
            case .failedNeedsReconciliation: "NEEDS RECONCILIATION"
            }
        }

        var tone: MortTone {
            switch self {
            case .settledInFull: .success
            case .settledWithРartialRefund, .settledWithRefund: .info
            case .disputed: .danger
            case .processing: .warning
            case .failedNeedsReconciliation: .warning
            }
        }

        var symbol: String {
            switch self {
            case .settledInFull: "checkmark.circle"
            case .settledWithРartialRefund, .settledWithRefund: "arrow.uturn.left.circle"
            case .disputed: "exclamationmark.triangle"
            case .processing: "hourglass"
            case .failedNeedsReconciliation: "questionmark.circle"
            }
        }
    }

    let jobId: String
    let orderNumber: String
    /// What the adult originally funded pre-work.
    let fundedBaseCents: Int64
    /// What the backend authoritatively decided the work compensated.
    let compensatedBaseCents: Int64
    /// MORT fee retained by the platform.
    let feeRetainedCents: Int64
    /// MORT fee refunded to the adult, if any.
    let feeRefundedCents: Int64
    /// Total refunded to the adult (base component + fee component).
    let adultRefundCents: Int64
    let outcome: Outcome
    let explanation: String

    var fundedBase: Money { Money(cents: fundedBaseCents) }
    var compensatedBase: Money { Money(cents: compensatedBaseCents) }
    var feeRetained: Money { Money(cents: feeRetainedCents) }
    var feeRefunded: Money { Money(cents: feeRefundedCents) }
    var adultRefund: Money { Money(cents: adultRefundCents) }
    var hasRefund: Bool { adultRefundCents > 0 }
}
