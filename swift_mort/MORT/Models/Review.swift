import Foundation

struct MortReview: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let jobID: UUID
    let reviewerID: UUID
    let subjectID: UUID
    let rating: Int
    let body: String?
    let moderationStatus: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, rating, body
        case jobID = "job_id"
        case reviewerID = "reviewer_id"
        case subjectID = "subject_id"
        case moderationStatus = "moderation_status"
        case createdAt = "created_at"
    }
}

struct ReviewInput: Encodable, Sendable {
    let jobID: UUID
    let reviewerID: UUID
    let subjectID: UUID
    let rating: Int
    let body: String?

    enum CodingKeys: String, CodingKey {
        case rating, body
        case jobID = "job_id"
        case reviewerID = "reviewer_id"
        case subjectID = "subject_id"
    }
}

