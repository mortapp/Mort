import Foundation

struct MortNotification: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let recipientID: UUID?
    let title: String
    let body: String
    let readAt: String?
    let createdAt: String?
    let data: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case id, title, body, data
        case recipientID = "recipient_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }

    var isUnread: Bool { readAt == nil }
}

