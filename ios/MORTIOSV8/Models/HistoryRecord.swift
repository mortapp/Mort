//
//  HistoryRecord.swift
//  MORT iOS V8 — Models
//
//  Job & Payment History: ONE chronological timeline with refining filters.
//  Rows show handles and masked references only.
//

import Foundation

nonisolated enum HistoryFilter: String, Codable, Sendable, CaseIterable, Identifiable {
    case all, jobs, payments, receipts, earnings, tips, refunds, failed, adjustments, disputed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .jobs: "Jobs"
        case .payments: "Payments"
        case .receipts: "Receipts"
        case .earnings: "Earnings"
        case .tips: "Tips"
        case .refunds: "Refunds"
        case .failed: "Failed"
        case .adjustments: "Adjustments"
        case .disputed: "Disputed"
        }
    }

    /// Filters available to a given role.
    static func available(for role: MortRole) -> [HistoryFilter] {
        switch role {
        case .teen:
            [.all, .jobs, .earnings, .tips, .receipts, .adjustments, .disputed]
        case .adult:
            [.all, .jobs, .payments, .receipts, .tips, .refunds, .failed, .adjustments, .disputed]
        case .guardian:
            [.all, .jobs, .earnings, .receipts]
        }
    }
}

nonisolated enum HistoryKind: String, Codable, Sendable {
    case job
    case payment
    case earning
    case tip
    case refund
    case adjustment
    case failedPayment
    case storePurchase
    case dispute

    var symbol: String {
        switch self {
        case .job: "briefcase"
        case .payment: "creditcard"
        case .earning: "arrow.down.circle"
        case .tip: "hand.thumbsup"
        case .refund: "arrow.uturn.left.circle"
        case .adjustment: "slider.horizontal.3"
        case .failedPayment: "xmark.circle"
        case .storePurchase: "bag"
        case .dispute: "exclamationmark.triangle"
        }
    }

    func matches(_ filter: HistoryFilter) -> Bool {
        switch filter {
        case .all: true
        case .jobs: self == .job
        case .payments: self == .payment || self == .storePurchase
        case .receipts: self != .job && self != .dispute
        case .earnings: self == .earning
        case .tips: self == .tip
        case .refunds: self == .refund
        case .failed: self == .failedPayment
        case .adjustments: self == .adjustment
        case .disputed: self == .dispute
        }
    }
}

/// One row in the unified timeline.
nonisolated struct HistoryRecord: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: HistoryKind
    let title: String
    /// Counterparty handle, e.g. "@marcus".
    let counterpartyHandle: String
    /// Signed amount in cents. Negative = money out for this role.
    let amountCents: Int64
    let occurredAt: Date
    let statusLabel: String
    let statusTone: MortTone
    let statusSymbol: String
    /// Receipt this row opens, if a receipt exists.
    let receiptNumber: String?
    let orderNumber: String?
    /// True when NO receipt was issued (failed payments) — the row shows an
    /// explicit icon + note, never a colour-only hint.
    let noReceiptIssued: Bool
    let jobId: String?

    var amount: Money { Money(cents: amountCents) }

    /// "SEPTEMBER 2026" — month grouping key so long lists never become a
    /// wall of identical cards.
    var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: occurredAt).uppercased()
    }

    var year: Int {
        Calendar.current.component(.year, from: occurredAt)
    }

    var dayText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: occurredAt)
    }

    /// Search matches receipt #, order #, job title, and handle.
    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        if title.lowercased().contains(q) { return true }
        if counterpartyHandle.lowercased().contains(q) { return true }
        if let r = receiptNumber?.lowercased(), r.contains(q) { return true }
        if let o = orderNumber?.lowercased(), o.contains(q) { return true }
        return false
    }
}

/// Annual export states. [DO NOT FAKE] — no file means no success.
nonisolated enum ExportState: String, Codable, Sendable {
    case ready
    case preparing
    case readyToSave
    case failed

    var label: String {
        switch self {
        case .ready: "READY TO EXPORT"
        case .preparing: "PREPARING YOUR EXPORT"
        case .readyToSave: "EXPORT READY"
        case .failed: "EXPORT FAILED"
        }
    }

    var tone: MortTone {
        switch self {
        case .ready: .info
        case .preparing: .warning
        case .readyToSave: .success
        case .failed: .danger
        }
    }

    var symbol: String {
        switch self {
        case .ready: "square.and.arrow.down"
        case .preparing: "hourglass"
        case .readyToSave: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        }
    }
}
