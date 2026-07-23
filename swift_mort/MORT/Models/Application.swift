import Foundation

struct MortApplication: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let jobID: UUID
    let teenID: UUID
    let status: String
    let note: String?
    let guardianID: UUID?
    let job: Job?
    let availabilityConfirmed: Bool
    let createdAt: String?
    let viewedAt: String?
    let withdrawnAt: String?
    let teen: ProfileSummary?

    enum CodingKeys: String, CodingKey {
        case id, status, note, teen
        case jobID = "job_id"
        case teenID = "teen_id"
        case guardianID = "guardian_id"
        case job = "jobs"
        case availabilityConfirmed = "availability_confirmed"
        case createdAt = "created_at"
        case viewedAt = "viewed_at"
        case withdrawnAt = "withdrawn_at"
    }
}

struct ApplicationEligibility: Codable, Hashable, Sendable {
    let eligible: Bool
    let code: String
    let message: String
    let guardianRequiredForThisJob: Bool
    let guardianLinked: Bool
    let verificationRequirement: String
    let scheduleType: String

    enum CodingKeys: String, CodingKey {
        case eligible, code, message
        case guardianRequiredForThisJob = "guardian_required_for_this_job"
        case guardianLinked = "guardian_linked"
        case verificationRequirement = "verification_requirement"
        case scheduleType = "schedule_type"
    }
}

struct ApplicationStatusEvent: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let applicationID: UUID
    let fromStatus: String?
    let toStatus: String
    let actorID: UUID?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationID = "application_id"
        case fromStatus = "from_status"
        case toStatus = "to_status"
        case actorID = "actor_id"
        case createdAt = "created_at"
    }
}

