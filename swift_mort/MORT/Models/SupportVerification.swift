import Foundation

struct SupportTicket: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let subject: String
    let status: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, subject, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BusinessVerification: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let businessName: String
    let businessType: String
    let status: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case businessName = "business_name"
        case businessType = "business_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

