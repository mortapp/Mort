import Foundation

enum ReportTarget: Sendable, Equatable, Hashable {
    case user(UUID)
    case job(UUID)
    case message(UUID)
    case review(UUID)
}

struct ReportInput: Encodable, Sendable {
    let reporterID: UUID
    let targetUserID: UUID?
    let targetJobID: UUID?
    let targetMessageID: UUID?
    let targetReviewID: UUID?
    let reason: String
    let details: String?

    enum CodingKeys: String, CodingKey {
        case reason, details
        case reporterID = "reporter_id"
        case targetUserID = "target_user_id"
        case targetJobID = "target_job_id"
        case targetMessageID = "target_message_id"
        case targetReviewID = "target_review_id"
    }
}

struct ReportSummary: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let reason: String
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, reason, status
        case createdAt = "created_at"
    }
}

struct BlockRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let blockerID: UUID
    let blockedID: UUID
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case blockerID = "blocker_id"
        case blockedID = "blocked_id"
        case createdAt = "created_at"
    }
}

struct SafetyPing: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let teenID: UUID
    let status: String
    let note: String?
    let createdAt: String?
    let teen: ProfileSummary?

    enum CodingKeys: String, CodingKey {
        case id, status, note, teen
        case teenID = "teen_id"
        case createdAt = "created_at"
    }
}
