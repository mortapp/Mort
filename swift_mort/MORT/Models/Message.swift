import Foundation

struct MessageThread: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let jobID: UUID?
    let applicationID: UUID?
    let teenID: UUID?
    let adultID: UUID?
    let guardianID: UUID?
    let updatedAt: String?
    let unreadCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case jobID = "job_id"
        case applicationID = "application_id"
        case teenID = "teen_id"
        case adultID = "adult_id"
        case guardianID = "guardian_id"
        case updatedAt = "updated_at"
        case unreadCount = "unread_count"
    }

    var unread: Int { max(0, unreadCount ?? 0) }
}

struct MortMessage: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let threadID: UUID
    let senderID: UUID
    let body: String
    let scannerStatus: String
    let scannerReason: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, body
        case threadID = "thread_id"
        case senderID = "sender_id"
        case scannerStatus = "scanner_status"
        case scannerReason = "scanner_reason"
        case createdAt = "created_at"
    }

    var isBlocked: Bool { scannerStatus == "blocked" }
    var isFlagged: Bool { scannerStatus == "flagged" }
}
