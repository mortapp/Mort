//
//  MortMessage.swift
//  MORT iOS V8 — Models
//

import Foundation

nonisolated enum MessageDelivery: String, Codable, Sendable {
    case sending, sent, delivered, read, failed

    var symbol: String? {
        switch self {
        case .sending: "clock"
        case .sent: "checkmark"
        case .delivered: "checkmark.circle"
        case .read: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle"
        }
    }

    var label: String {
        switch self {
        case .sending: "Sending"
        case .sent: "Sent"
        case .delivered: "Delivered"
        case .read: "Read"
        case .failed: "Not sent"
        }
    }
}

nonisolated struct MortMessage: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let conversationId: String
    let authorHandle: String
    let authorDisplayName: String
    let body: String
    let sentAt: Date
    let fromMe: Bool
    let delivery: MessageDelivery
    /// Approved evidence attachment reference (job proof only).
    let attachmentName: String?

    var timeText: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: sentAt)
    }
}

nonisolated enum ConversationRestriction: String, Codable, Sendable {
    case none
    /// The other person blocked this thread, or was blocked.
    case blocked
    /// Thread is read-only because the job ended.
    case archived
    /// Safety team restricted the thread.
    case restricted

    var notice: String? {
        switch self {
        case .none: nil
        case .blocked: "This conversation is blocked. You can't send new messages."
        case .archived: "This job is finished. The conversation is read-only."
        case .restricted: "MORT restricted this conversation while we review a report."
        }
    }
}

nonisolated struct MortConversation: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let counterpartyHandle: String
    let counterpartyDisplayName: String
    let counterpartyInitials: String
    let preview: String
    let updatedAt: Date
    let unreadCount: Int
    /// Job context is always visible — messages exist because of a job.
    let jobTitle: String
    let jobId: String
    let restriction: ConversationRestriction

    var timeText: String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(updatedAt) {
            f.timeStyle = .short
        } else {
            f.dateFormat = "MMM d"
        }
        return f.string(from: updatedAt)
    }
}
