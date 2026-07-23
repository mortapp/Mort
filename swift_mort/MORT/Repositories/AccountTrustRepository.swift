import Foundation
import Supabase

protocol AccountTrustRepositoryProtocol: Sendable {
    func profile() async throws -> AccountTrustProfile
    func eligibility(action: String, jobID: UUID?) async throws -> MarketplaceTrustEligibility
    func updateDeviceSecurity(enabled: Bool, lockAfterMinutes: Int) async throws -> AccountTrustActionResult
    func requestSchoolAffiliation(email: String) async throws -> AccountTrustActionResult
    func redeemPartnerCode(_ code: String) async throws -> AccountTrustActionResult
    func requestBusinessRegistryMatch(jurisdiction: String, legalName: String, registrationNumber: String, entityType: String?, sourceURL: String) async throws -> AccountTrustActionResult
    func requestBusinessRepresentativeClaim(checkID: UUID, relationship: String) async throws -> AccountTrustActionResult
    func setIndicatorVisibility(signalType: String, visible: Bool) async throws -> AccountTrustActionResult
    func submitAppeal(reason: String, signalID: UUID?) async throws -> AccountTrustActionResult
    func adminQueue(_ queue: String, accessReason: String, caseID: String) async throws -> TrustAdminQueueResponse
}

final class AccountTrustRepository: SupabaseRepository, AccountTrustRepositoryProtocol {
    func profile() async throws -> AccountTrustProfile {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_my_account_trust_profile").execute().value
        }
    }

    func eligibility(action: String, jobID: UUID?) async throws -> MarketplaceTrustEligibility {
        struct Params: Encodable { let p_action: String; let p_job_id: UUID? }
        return try await translated {
            _ = try await currentUserID()
            return try await client.rpc(
                "get_marketplace_trust_eligibility",
                params: Params(p_action: action, p_job_id: jobID)
            ).execute().value
        }
    }

    func updateDeviceSecurity(enabled: Bool, lockAfterMinutes: Int) async throws -> AccountTrustActionResult {
        struct Params: Encodable { let p_device_reauthentication_enabled: Bool; let p_lock_after_minutes: Int }
        return try await action(
            "update_account_security_preferences",
            Params(p_device_reauthentication_enabled: enabled, p_lock_after_minutes: lockAfterMinutes),
            "Device security settings could not be updated."
        )
    }

    func requestSchoolAffiliation(email: String) async throws -> AccountTrustActionResult {
        struct Params: Encodable { let p_school_email: String }
        return try await action(
            "request_school_email_affiliation",
            Params(p_school_email: email.trimmed.lowercased()),
            "School affiliation could not be requested."
        )
    }

    func redeemPartnerCode(_ code: String) async throws -> AccountTrustActionResult {
        struct Params: Encodable { let p_code: String }
        return try await action(
            "redeem_partner_invite_code",
            Params(p_code: code.trimmed.uppercased()),
            "The partner code could not be redeemed."
        )
    }

    func requestBusinessRegistryMatch(
        jurisdiction: String,
        legalName: String,
        registrationNumber: String,
        entityType: String?,
        sourceURL: String
    ) async throws -> AccountTrustActionResult {
        struct Params: Encodable {
            let p_jurisdiction: String
            let p_legal_business_name: String
            let p_registration_number: String
            let p_entity_type: String?
            let p_official_source_url: String
        }
        return try await action(
            "request_business_registry_match",
            Params(
                p_jurisdiction: jurisdiction.trimmed.uppercased(),
                p_legal_business_name: legalName.trimmed,
                p_registration_number: registrationNumber.trimmed.uppercased(),
                p_entity_type: entityType?.nilIfBlank,
                p_official_source_url: sourceURL.trimmed
            ),
            "The business registry request could not be created."
        )
    }

    func requestBusinessRepresentativeClaim(checkID: UUID, relationship: String) async throws -> AccountTrustActionResult {
        struct Params: Encodable {
            let p_business_registry_check_id: UUID
            let p_relationship_type: String
            let p_attested: Bool
        }
        return try await action(
            "request_business_representative_claim",
            Params(p_business_registry_check_id: checkID, p_relationship_type: relationship, p_attested: true),
            "The representative claim could not be recorded."
        )
    }

    func setIndicatorVisibility(signalType: String, visible: Bool) async throws -> AccountTrustActionResult {
        struct Params: Encodable { let p_signal_type: String; let p_visible: Bool }
        return try await action(
            "set_trust_signal_visibility",
            Params(p_signal_type: signalType, p_visible: visible),
            "The indicator visibility could not be changed."
        )
    }

    func submitAppeal(reason: String, signalID: UUID?) async throws -> AccountTrustActionResult {
        struct Params: Encodable { let p_reason: String; let p_signal_id: UUID? }
        return try await action(
            "submit_account_trust_appeal",
            Params(p_reason: reason.trimmed, p_signal_id: signalID),
            "The trust appeal could not be submitted."
        )
    }

    func adminQueue(_ queue: String, accessReason: String, caseID: String) async throws -> TrustAdminQueueResponse {
        struct Params: Encodable { let p_queue: String; let p_access_reason: String; let p_case_id: String }
        return try await translated {
            _ = try await currentUserID()
            let result: TrustAdminQueueResponse = try await client.rpc(
                "get_admin_trust_review_queue",
                params: Params(p_queue: queue, p_access_reason: accessReason.trimmed, p_case_id: caseID.trimmed)
            ).execute().value
            guard result.ok else { throw MortError.backend(code: result.code ?? "trust_queue_denied", message: "This trust queue is unavailable for the current admin role.") }
            return result
        }
    }

    private func action<Params: Encodable>(
        _ function: String,
        _ params: Params,
        _ defaultMessage: String
    ) async throws -> AccountTrustActionResult {
        try await translated {
            _ = try await currentUserID()
            let result: AccountTrustActionResult = try await client.rpc(function, params: params).execute().value
            return try result.requireSuccess(defaultMessage: defaultMessage)
        }
    }
}
