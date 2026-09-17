//
//  MortNotification.swift
//  MORT iOS V8 — Models
//
//  Push delivery is never fabricated: the app shows what the backend recorded.
//

import Foundation

nonisolated enum NotificationCategory: String, Codable, Sendable, CaseIterable {
    case job
    case application
    case message
    case payment
    case payout
    case safety
    case guardian
    case system

    var symbol: String {
        switch self {
        case .job: "briefcase"
        case .application: "paperplane"
        case .message: "bubble.left"
        case .payment: "creditcard"
        case .payout: "building.columns"
        case .safety: "shield.lefthalf.filled"
        case .guardian: "person.2"
        case .system: "gearshape"
        }
    }

    var tone: MortTone {
        switch self {
        case .safety: .danger
        case .payment, .payout: .success
        case .job, .application, .message, .guardian: .info
        case .system: .neutral
        }
    }
}

nonisolated struct MortNotification: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let category: NotificationCategory
    let title: String
    let body: String
    let receivedAt: Date
    let isRead: Bool
    /// Deep-link route this notification opens.
    let route: String?

    var timeText: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: receivedAt, relativeTo: Date())
    }
}
