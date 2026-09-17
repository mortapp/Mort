//
//  Receipt.swift
//  MORT iOS V8 — Payment OS Models
//
//  RECEIPT RULES (immutable, backend-issued):
//   - Receipts are IMMUTABLE. The client renders; it never rewrites.
//   - Funding confirmation is NOT teen earnings.
//   - Payout status must NOT mutate the earnings receipt.
//   - Failed transactions receive NO receipt.
//   - Late tips create SEPARATE receipts.
//   - Refunds / adjustments / reversals create LINKED receipts.
//   - The leading receipt letter is RANDOM, never encodes type, and must
//     never be styled or interpreted by type. Letters I, O and L are unused.
//   - Privacy: handles + masked references only.
//

import Foundation

/// Document categories the renderer supports.
nonisolated enum ReceiptType: String, Codable, Sendable, CaseIterable, Identifiable {
    case adultJobPayment
    case teenEarnings
    case storePurchase
    case lateTip
    case fullRefund
    case partialRefund
    case adjustment
    case reversal

    var id: String { rawValue }

    /// The explicit document title printed on the paper.
    var documentTitle: String {
        switch self {
        case .adultJobPayment: "JOB PAYMENT RECEIPT"
        case .teenEarnings: "EARNINGS RECEIPT"
        case .storePurchase: "PURCHASE RECEIPT"
        case .lateTip: "TIP RECEIPT"
        case .fullRefund: "REFUND RECEIPT"
        case .partialRefund: "PARTIAL REFUND RECEIPT"
        case .adjustment: "ADJUSTMENT RECEIPT"
        case .reversal: "REVERSAL RECEIPT"
        }
    }

    /// True for documents that must show a linked-parent box.
    var isLinkedDocument: Bool {
        switch self {
        case .lateTip, .fullRefund, .partialRefund, .adjustment, .reversal: true
        case .adultJobPayment, .teenEarnings, .storePurchase: false
        }
    }
}

/// One printed line on the receipt paper.
nonisolated struct ReceiptLine: Identifiable, Codable, Hashable, Sendable {
    nonisolated enum Emphasis: String, Codable, Sendable {
        /// Normal line item.
        case normal
        /// Subtotal above a dashed rule.
        case subtotal
        /// The dominant total — largest type on the paper.
        case total
        /// Quiet explanatory line (e.g. "DEDUCTIONS  $0.00").
        case quiet
    }

    let id: String
    let label: String
    /// Rendered amount in cents. nil renders a label-only note line.
    let amountCents: Int64?
    let emphasis: Emphasis
    /// Optional small note printed under the line.
    let note: String?

    var amount: Money? { amountCents.map(Money.init(cents:)) }
}

/// A key/value identity or reference row on the paper.
nonisolated struct ReceiptRow: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let label: String
    let value: String
}

/// A linked receipt reference — this box IS the immutability chain made
/// visible. The parent document is always described as "Unchanged".
nonisolated struct ReceiptLink: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let rows: [ReceiptRow]
    /// Always "Unchanged" for parent documents by policy.
    let status: String
}

/// A complete backend-issued receipt document. IMMUTABLE.
nonisolated struct Receipt: Identifiable, Codable, Hashable, Sendable {
    /// Receipt number, e.g. "K-260915-04827". Leading letter is random and
    /// carries no meaning — never style or branch on it.
    let id: String
    let type: ReceiptType
    /// 4-digit display order number, e.g. "0042".
    let orderNumber: String
    /// Backend-authoritative issue timestamp (displayed device-local).
    let issuedAt: Date
    let identityRows: [ReceiptRow]
    let serviceTitle: String
    /// Up to three description lines. Must never be clipped.
    let serviceLines: [String]
    let lines: [ReceiptLine]
    /// Status shown on the paper: tone + label + optional sub-line.
    let statusTone: MortTone
    let statusLabel: String
    let statusSub: String?
    /// Masked method label, e.g. "Visa •••• 4242".
    let methodLabel: String?
    let methodMask: String?
    let referenceRows: [ReceiptRow]
    let links: [ReceiptLink]
    /// Standard privacy note printed at the bottom.
    let privacyNote: String
    /// Mandatory on export/earnings documents.
    let notATaxDocumentNote: String?

    var issuedAtText: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: issuedAt)
    }
}
