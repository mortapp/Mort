//
//  SupportModels.swift
//  MORT iOS V8 — Models
//
//  Support never exposes internal moderation or security detail to the user.
//

import Foundation

nonisolated enum SupportCaseState: String, Codable, Sendable {
    case open
    case waitingOnYou
    case withSupport
    case safetyPriority
    case resolved
    case closed

    var label: String {
        switch self {
        case .open: "OPEN"
        case .waitingOnYou: "WAITING ON YOU"
        case .withSupport: "WITH SUPPORT"
        case .safetyPriority: "SAFETY PRIORITY"
        case .resolved: "RESOLVED"
        case .closed: "CLOSED"
        }
    }

    var tone: MortTone {
        switch self {
        case .open, .withSupport: .info
        case .waitingOnYou: .warning
        case .safetyPriority: .danger
        case .resolved: .success
        case .closed: .neutral
        }
    }

    var symbol: String {
        switch self {
        case .open: "bubble.left"
        case .waitingOnYou: "person.wave.2"
        case .withSupport: "headphones"
        case .safetyPriority: "shield.lefthalf.filled"
        case .resolved: "checkmark.circle"
        case .closed: "archivebox"
        }
    }
}

nonisolated struct SupportCase: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let subject: String
    let state: SupportCaseState
    let updatedAt: Date
    let lastMessagePreview: String
    /// True when a human agent is involved (vs. assisted answers).
    let withHumanAgent: Bool
    /// Related receipt/order reference, if the case is about a payment.
    let reference: String?

    var updatedText: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: updatedAt)
    }
}

nonisolated struct SupportTopic: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    /// Safety topics jump the queue and are labeled as such.
    let isSafety: Bool

    static let standard: [SupportTopic] = [
        .init(id: "safety", title: "A safety concern", detail: "Anything that made you feel unsafe. These come first.", symbol: "shield.lefthalf.filled", isSafety: true),
        .init(id: "payment", title: "A payment or receipt", detail: "Funding, settlement, tips, refunds, payouts.", symbol: "creditcard", isSafety: false),
        .init(id: "job", title: "A job or application", detail: "Scheduling, cancellations, no-shows.", symbol: "briefcase", isSafety: false),
        .init(id: "account", title: "My account", detail: "Sign-in, profile, guardian link, deletion.", symbol: "person.crop.circle", isSafety: false),
        .init(id: "other", title: "Something else", detail: "Tell us what's going on.", symbol: "bubble.left.and.bubble.right", isSafety: false),
    ]
}
