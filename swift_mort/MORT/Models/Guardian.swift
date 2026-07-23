import Foundation

struct GuardianPreferences: Codable, Hashable, Sendable {
    let linkID: UUID
    var safetyPingAlerts: Bool
    var jobCheckinAlerts: Bool
    var acceptedJobSummary: Bool
    var safetyWarningAlerts: Bool
    var weeklyDigest: Bool
    var optionalJobApprovalEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case linkID = "link_id"
        case safetyPingAlerts = "safety_ping_alerts"
        case jobCheckinAlerts = "job_checkin_alerts"
        case acceptedJobSummary = "accepted_job_summary"
        case safetyWarningAlerts = "safety_warning_alerts"
        case weeklyDigest = "weekly_digest"
        case optionalJobApprovalEnabled = "optional_job_approval_enabled"
    }
}

struct GuardianConnection: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let teenID: UUID
    let guardianID: UUID?
    let status: String
    let inviteCode: String?
    let inviteEmail: String?
    let createdAt: String?
    let preferences: GuardianPreferences?
    let teen: ProfileSummary?
    let guardian: ProfileSummary?

    enum CodingKeys: String, CodingKey {
        case id, status, teen, guardian
        case teenID = "teen_id"
        case guardianID = "guardian_id"
        case inviteCode = "invite_code"
        case inviteEmail = "invite_email"
        case createdAt = "created_at"
        case preferences = "guardian_preferences"
    }
}

struct GuardianPolicy: Codable, Hashable, Sendable {
    let ok: Bool
    let code: String?
    let message: String?
    let linked: Bool?
    let paused: Bool?
    let guardianRequired: Bool?
    let linkID: UUID?

    enum CodingKeys: String, CodingKey {
        case ok, code, message, linked, paused
        case guardianRequired = "guardian_required"
        case linkID = "link_id"
    }
}
