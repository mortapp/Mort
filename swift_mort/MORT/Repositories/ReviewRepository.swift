import Foundation
import Supabase

protocol ReviewRepositoryProtocol: Sendable {
    func create(jobID: UUID, subjectID: UUID, rating: Int, body: String?) async throws -> MortReview
    func currentUsersReview(jobID: UUID) async throws -> MortReview?
    func received() async throws -> [MortReview]
}

final class ReviewRepository: SupabaseRepository, ReviewRepositoryProtocol {
    func create(jobID: UUID, subjectID: UUID, rating: Int, body: String?) async throws -> MortReview {
        guard 1...5 ~= rating else { throw MortError.invalidInput("Choose a rating from 1 to 5.") }
        return try await translated {
            let input = ReviewInput(jobID: jobID, reviewerID: try await currentUserID(), subjectID: subjectID, rating: rating, body: body?.nilIfBlank)
            return try await client.from("reviews").insert(input).select().single().execute().value
        }
    }

    func currentUsersReview(jobID: UUID) async throws -> MortReview? {
        try await translated {
            let rows: [MortReview] = try await client.from("reviews").select().eq("job_id", value: jobID)
                .eq("reviewer_id", value: try await currentUserID()).limit(1).execute().value
            return rows.first
        }
    }

    func received() async throws -> [MortReview] {
        try await translated {
            try await client.from("reviews").select().eq("subject_id", value: try await currentUserID())
                .eq("moderation_status", value: "approved").order("created_at", ascending: false).execute().value
        }
    }
}

