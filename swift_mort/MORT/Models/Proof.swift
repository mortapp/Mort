import Foundation

struct ProofUpload: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let applicationID: UUID
    let uploadedBy: UUID
    let storagePath: String
    let note: String?
    let status: String
    let reviewedBy: UUID?
    let reviewNote: String?
    let reviewedAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, note, status
        case applicationID = "application_id"
        case uploadedBy = "uploaded_by"
        case storagePath = "storage_path"
        case reviewedBy = "reviewed_by"
        case reviewNote = "review_note"
        case reviewedAt = "reviewed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var statusTitle: String {
        switch status {
        case "submitted": "Awaiting review"
        case "approved": "Approved"
        case "resubmission_requested": "New proof requested"
        case "rejected": "Needs attention"
        default: status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
