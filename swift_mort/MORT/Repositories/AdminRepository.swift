import Foundation
import Supabase

protocol AdminRepositoryProtocol: Sendable {
    func monetizationOverview() async throws -> [String: JSONValue]
    func queue(_ queue: AdminQueue, limit: Int) async throws -> [AdminRecord]
    func update(queue: AdminQueue, id: String, values: [String: JSONValue]) async throws
    func reviewIdentity(id: UUID, action: String, decisionCode: String?) async throws
    func updateIncident(id: UUID, status: String, publicNote: String, restrictedNote: String?) async throws
    func restrictUser(id: UUID, status: String) async throws
}

enum AdminQueue: String, CaseIterable, Identifiable, Hashable, Sendable {
    case users
    case jobs
    case reports
    case verifications
    case adultIDReview
    case teenSchoolIDReview
    case teenAlternativeEvidence
    case businessVerifications
    case verificationAppeals
    case personMismatch
    case sexualSafety
    case groomingSignals
    case abductionConcerns
    case threatsViolence
    case propertyTheft
    case accountSharing
    case incidentCases
    case evidencePreservation
    case lawfulRequests
    case messages
    case safetyPings
    case support
    case reviews
    case monetization
    case actionLogs

    var id: String { rawValue }
    var title: String {
        switch self {
        case .users: "Users"
        case .jobs: "Jobs"
        case .reports: "Reports"
        case .verifications: "Identity review"
        case .adultIDReview: "Adult ID review"
        case .teenSchoolIDReview: "Teen school-ID review"
        case .teenAlternativeEvidence: "Teen alternative evidence"
        case .businessVerifications: "Business verification"
        case .verificationAppeals: "Verification appeals"
        case .personMismatch: "Person mismatch"
        case .sexualSafety: "Sexual-safety reports"
        case .groomingSignals: "Grooming signals"
        case .abductionConcerns: "Abduction concerns"
        case .threatsViolence: "Threats and violence"
        case .propertyTheft: "Property and theft"
        case .accountSharing: "Account sharing"
        case .incidentCases: "Incident cases"
        case .evidencePreservation: "Evidence preservation"
        case .lawfulRequests: "Lawful requests"
        case .messages: "Flagged messages"
        case .safetyPings: "Safety pings"
        case .support: "Support"
        case .reviews: "Reviews"
        case .monetization: "Monetization"
        case .actionLogs: "Action logs"
        }
    }

    var table: String {
        switch self {
        case .users: "profiles"
        case .jobs: "jobs"
        case .reports: "reports"
        case .verifications, .adultIDReview, .teenSchoolIDReview,
             .teenAlternativeEvidence, .verificationAppeals: "identity_verifications"
        case .businessVerifications: "business_verifications"
        case .personMismatch, .sexualSafety, .groomingSignals,
             .abductionConcerns, .threatsViolence, .propertyTheft,
             .accountSharing, .incidentCases, .evidencePreservation: "safety_incidents"
        case .lawfulRequests: "incident_law_enforcement_requests"
        case .messages: "messages"
        case .safetyPings: "safety_pings"
        case .support: "support_tickets"
        case .reviews: "reviews"
        case .monetization: "paywall_events"
        case .actionLogs: "admin_action_logs"
        }
    }

    var isIdentityQueue: Bool {
        [.verifications, .adultIDReview, .teenSchoolIDReview, .teenAlternativeEvidence, .verificationAppeals].contains(self)
    }

    var isIncidentQueue: Bool {
        [.personMismatch, .sexualSafety, .groomingSignals, .abductionConcerns,
         .threatsViolence, .propertyTheft, .accountSharing, .incidentCases,
         .evidencePreservation].contains(self)
    }
}

final class AdminRepository: SupabaseRepository, AdminRepositoryProtocol {
    func monetizationOverview() async throws -> [String: JSONValue] {
        try await translated { try await client.rpc("admin_monetization_overview").execute().value }
    }

    func queue(_ queue: AdminQueue, limit: Int = 50) async throws -> [AdminRecord] {
        struct Params: Encodable { let p_limit: Int }
        return try await translated {
            _ = try await currentUserID()
            if queue == .users {
                return try await client.rpc("admin_list_profiles", params: Params(p_limit: limit)).execute().value
            }
            var query = client.from(queue.table).select()
            switch queue {
            case .verifications:
                query = query.or("status.eq.verification_pending,status.eq.manual_review,status.eq.additional_information_required,status.eq.appeal_pending")
            case .adultIDReview:
                query = query.eq("account_role", value: "adult")
            case .teenSchoolIDReview:
                query = query.eq("account_role", value: "teen").eq("evidence_route", value: "school_photo_id")
            case .teenAlternativeEvidence:
                query = query.eq("account_role", value: "teen").neq("evidence_route", value: "school_photo_id")
            case .verificationAppeals:
                query = query.eq("status", value: "appeal_pending")
            case .personMismatch:
                query = query.eq("category", value: "identity_mismatch")
            case .sexualSafety:
                query = query.or("category.eq.sexual_harassment,category.eq.sexual_conduct,category.eq.inappropriate_touching,category.eq.inappropriate_images")
            case .groomingSignals:
                query = query.or("category.eq.child_safety_concern,category.eq.off_platform_pressure,category.eq.personal_information_request")
            case .abductionConcerns:
                query = query.eq("category", value: "kidnapping_abduction_concern")
            case .threatsViolence:
                query = query.or("category.eq.threats,category.eq.assault,category.eq.attempted_assault,category.eq.weapons")
            case .propertyTheft:
                query = query.or("category.eq.property_damage,category.eq.theft")
            case .accountSharing:
                query = query.or("category.eq.account_sharing,category.eq.impersonation,category.eq.fake_document")
            case .evidencePreservation:
                query = query.or("legal_hold.eq.true,preservation_status.eq.preserve_relevant_records")
            default:
                break
            }
            return try await query.order("created_at", ascending: false).limit(limit).execute().value
        }
    }

    func update(queue: AdminQueue, id: String, values: [String: JSONValue]) async throws {
        try await translated {
            _ = try await currentUserID()
            guard !queue.isIdentityQueue, !queue.isIncidentQueue else {
                throw MortError.invalidInput("Sensitive admin records require a specialized audited action.")
            }
            try await client.from(queue.table).update(values).eq("id", value: id).execute()
        }
    }

    func reviewIdentity(id: UUID, action: String, decisionCode: String?) async throws {
        struct Params: Encodable {
            let p_verification_id: UUID
            let p_action: String
            let p_decision_code: String?
            let p_identity_match_result: String
            let p_liveness_result: String
            let p_email_result: String
            let p_phone_result: String
            let p_address_result: String
            let p_expires_at: String?
        }
        try await translated {
            _ = try await currentUserID()
            let approving = action == "approve"
            let result: TrustSafetyActionResult = try await client.rpc("admin_review_identity_verification", params: Params(
                p_verification_id: id,
                p_action: action,
                p_decision_code: decisionCode?.nilIfBlank,
                p_identity_match_result: approving ? "manual_pass" : "not_checked",
                p_liveness_result: approving ? "manual_pass" : "not_checked",
                p_email_result: approving ? "manual_pass" : "not_checked",
                p_phone_result: approving ? "manual_pass" : "not_checked",
                p_address_result: approving ? "manual_pass" : "not_checked",
                p_expires_at: approving ? ISO8601DateFormatter().string(from: Date().addingTimeInterval(31_536_000)) : nil
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The identity review action was rejected.")
        }
    }

    func updateIncident(id: UUID, status: String, publicNote: String, restrictedNote: String?) async throws {
        struct Params: Encodable {
            let p_incident_id: UUID
            let p_status: String
            let p_public_status_note: String
            let p_restricted_note: String?
            let p_severity: String?
        }
        try await translated {
            _ = try await currentUserID()
            let result: TrustSafetyActionResult = try await client.rpc("admin_update_incident_case", params: Params(
                p_incident_id: id,
                p_status: status,
                p_public_status_note: publicNote,
                p_restricted_note: restrictedNote?.nilIfBlank,
                p_severity: nil
            )).execute().value
            _ = try result.requireSuccess(defaultMessage: "The incident update was rejected.")
        }
    }

    func restrictUser(id: UUID, status: String) async throws {
        try await translated {
            _ = try await currentUserID()
            try await client.from("profiles").update(["account_status": status]).eq("id", value: id).execute()
        }
    }
}
