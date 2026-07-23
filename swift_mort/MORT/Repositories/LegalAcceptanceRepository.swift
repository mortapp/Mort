import Foundation
import Supabase

protocol LegalAcceptanceRepositoryProtocol: Sendable {
    func requirements() async throws -> LegalRequirementsResponse
    func version(id: UUID) async throws -> PublishedLegalVersion
    func accept(versionID: UUID, teenSummaryViewed: Bool, signature: String?) async throws -> LegalAcceptanceResult
    func decline(versionID: UUID, reason: String) async throws -> GenericRPCResult
}

final class LegalAcceptanceRepository: SupabaseRepository, LegalAcceptanceRepositoryProtocol {
    func requirements() async throws -> LegalRequirementsResponse {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_my_legal_requirements").execute().value
        }
    }

    func version(id: UUID) async throws -> PublishedLegalVersion {
        try await translated {
            let rows: [PublishedLegalVersion] = try await client
                .from("legal_document_versions")
                .select("id,document_id,version_label,content_hash,content_markdown,effective_at,publication_status")
                .eq("id", value: id)
                .eq("publication_status", value: "published")
                .limit(1)
                .execute().value
            guard let version = rows.first else { throw MortError.invalidResponse }
            return version
        }
    }

    func accept(versionID: UUID, teenSummaryViewed: Bool, signature: String?) async throws -> LegalAcceptanceResult {
        struct Params: Encodable {
            let p_document_version_id: UUID
            let p_affirmative_checkbox: Bool
            let p_teen_summary_viewed: Bool
            let p_electronic_signature_text: String?
            let p_platform: String
            let p_app_version: String
            let p_language_code: String
        }
        return try await translated {
            let result: LegalAcceptanceResult = try await client.rpc(
                "submit_legal_acceptance",
                params: Params(
                    p_document_version_id: versionID,
                    p_affirmative_checkbox: true,
                    p_teen_summary_viewed: teenSummaryViewed,
                    p_electronic_signature_text: signature?.nilIfBlank,
                    p_platform: "ios",
                    p_app_version: Self.appVersion,
                    p_language_code: Locale.current.identifier
                )
            ).execute().value
            guard result.ok else {
                throw MortError.backend(code: result.code ?? "legal_acceptance_failed", message: nil)
            }
            return result
        }
    }

    func decline(versionID: UUID, reason: String) async throws -> GenericRPCResult {
        struct Params: Encodable {
            let p_document_version_id: UUID
            let p_reason_code: String
            let p_platform: String
            let p_app_version: String
        }
        return try await translated {
            let result: GenericRPCResult = try await client.rpc(
                "decline_legal_document",
                params: Params(
                    p_document_version_id: versionID,
                    p_reason_code: reason,
                    p_platform: "ios",
                    p_app_version: Self.appVersion
                )
            ).execute().value
            return try result.requireSuccess(defaultMessage: "The legal-document response could not be saved.")
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unversioned"
    }
}

protocol JobContractRepositoryProtocol: Sendable {
    func contract(applicationID: UUID) async throws -> JobContractRecord?
    func contracts() async throws -> [JobContractRecord]
    func versions(contractID: UUID) async throws -> [JobContractVersionRecord]
    func acceptances(contractID: UUID) async throws -> [JobContractAcceptanceRecord]
    func confirm(versionID: UUID, confirmation: String) async throws -> GenericRPCResult
    func changes(contractID: UUID) async throws -> [JobContractChangeRecord]
    func requestChange(contractID: UUID, patch: [String: JSONValue], reason: String) async throws -> GenericRPCResult
    func respondToChange(id: UUID, accept: Bool) async throws -> GenericRPCResult
    func obligations(contractID: UUID) async throws -> [PaymentObligationRecord]
    func disputes(contractID: UUID) async throws -> [PaymentDisputeRecord]
    func dispute(id: UUID) async throws -> PaymentDisputeRecord
    func disputeTimeline(id: UUID) async throws -> [PaymentDisputeTimelineRecord]
    func reportNonpayment(obligationID: UUID, statement: String) async throws -> GenericRPCResult
    func submitDisputeStatement(disputeID: UUID, statement: String) async throws -> GenericRPCResult
    func evidenceExport(disputeID: UUID) async throws -> [String: JSONValue]
}

final class JobContractRepository: SupabaseRepository, JobContractRepositoryProtocol {
    private let contractFields = "id,job_id,application_id,teen_id,adult_id,status,active_version_id,classification_status,created_at"

    func contract(applicationID: UUID) async throws -> JobContractRecord? {
        try await translated {
            let rows: [JobContractRecord] = try await client.from("job_contracts")
                .select(contractFields)
                .eq("application_id", value: applicationID)
                .limit(1)
                .execute().value
            return rows.first
        }
    }

    func contracts() async throws -> [JobContractRecord] {
        try await translated {
            try await client.from("job_contracts")
                .select(contractFields)
                .order("created_at", ascending: false)
                .execute().value
        }
    }

    func versions(contractID: UUID) async throws -> [JobContractVersionRecord] {
        try await translated {
            try await client.from("job_contract_versions")
                .select("id,contract_id,version_number,status,content_hash,teen_public_identifier,adult_public_identifier,agreed_scope,excluded_work,location_type,exact_location_release_state,service_date,start_window,expected_end_window,amount_type,hourly_rate_cents,maximum_approved_hours,fixed_total_cents,currency_code,payment_preference,payment_due_rule,authorized_expenses,equipment,hazards,expected_people_present,supervision,proof_requirements,completion_requirements,cancellation_terms,material_change_process,dispute_process,safety_agreement_version")
                .eq("contract_id", value: contractID)
                .order("version_number", ascending: false)
                .execute().value
        }
    }

    func acceptances(contractID: UUID) async throws -> [JobContractAcceptanceRecord] {
        try await translated {
            try await client.from("job_contract_acceptances")
                .select("id,contract_version_id,user_id,party_role,content_hash,accepted_at")
                .eq("contract_id", value: contractID)
                .order("accepted_at")
                .execute().value
        }
    }

    func confirm(versionID: UUID, confirmation: String) async throws -> GenericRPCResult {
        struct Params: Encodable {
            let p_contract_version_id: UUID
            let p_affirmative_checkbox: Bool
            let p_confirmation_text: String
            let p_platform: String
            let p_app_version: String
        }
        return try await action(
            "confirm_job_contract_version",
            Params(
                p_contract_version_id: versionID,
                p_affirmative_checkbox: true,
                p_confirmation_text: confirmation,
                p_platform: "ios",
                p_app_version: Self.appVersion
            ),
            "The exact contract version could not be confirmed."
        )
    }

    func changes(contractID: UUID) async throws -> [JobContractChangeRecord] {
        try await translated {
            try await client.from("job_contract_change_requests")
                .select("id,contract_id,requested_by,change_categories,proposed_terms,proposed_content_hash,reason,status,requested_at")
                .eq("contract_id", value: contractID)
                .order("requested_at", ascending: false)
                .execute().value
        }
    }

    func requestChange(contractID: UUID, patch: [String: JSONValue], reason: String) async throws -> GenericRPCResult {
        struct Params: Encodable { let p_contract_id: UUID; let p_patch: [String: JSONValue]; let p_reason: String }
        return try await action(
            "request_job_contract_change",
            Params(p_contract_id: contractID, p_patch: patch, p_reason: reason),
            "The material-change request could not be created."
        )
    }

    func respondToChange(id: UUID, accept: Bool) async throws -> GenericRPCResult {
        struct Params: Encodable { let p_change_request_id: UUID; let p_accept: Bool; let p_affirmative_checkbox: Bool }
        return try await action(
            "respond_job_contract_change",
            Params(p_change_request_id: id, p_accept: accept, p_affirmative_checkbox: accept),
            "The material-change response could not be saved."
        )
    }

    func obligations(contractID: UUID) async throws -> [PaymentObligationRecord] {
        try await translated {
            try await client.from("job_payment_obligations")
                .select("id,contract_id,amount_cents,currency_code,payment_preference,due_rule,due_at,status,became_due_at,satisfied_at,disputed_at")
                .eq("contract_id", value: contractID)
                .order("created_at", ascending: false)
                .execute().value
        }
    }

    func disputes(contractID: UUID) async throws -> [PaymentDisputeRecord] {
        try await translated {
            try await client.from("payment_disputes")
                .select(Self.disputeFields)
                .eq("contract_id", value: contractID)
                .order("opened_at", ascending: false)
                .execute().value
        }
    }

    func dispute(id: UUID) async throws -> PaymentDisputeRecord {
        try await translated {
            let rows: [PaymentDisputeRecord] = try await client.from("payment_disputes")
                .select(Self.disputeFields)
                .eq("id", value: id)
                .limit(1)
                .execute().value
            guard let dispute = rows.first else { throw MortError.invalidResponse }
            return dispute
        }
    }

    func disputeTimeline(id: UUID) async throws -> [PaymentDisputeTimelineRecord] {
        try await translated {
            try await client.from("payment_dispute_timeline")
                .select("id,event_type,event_summary,created_at")
                .eq("dispute_id", value: id)
                .order("created_at")
                .execute().value
        }
    }

    func reportNonpayment(obligationID: UUID, statement: String) async throws -> GenericRPCResult {
        struct Params: Encodable { let p_obligation_id: UUID; let p_worker_statement: String }
        return try await action(
            "report_nonpayment",
            Params(p_obligation_id: obligationID, p_worker_statement: statement),
            "The private nonpayment report could not be opened."
        )
    }

    func submitDisputeStatement(disputeID: UUID, statement: String) async throws -> GenericRPCResult {
        struct Params: Encodable { let p_dispute_id: UUID; let p_statement: String }
        return try await action(
            "submit_payment_dispute_statement",
            Params(p_dispute_id: disputeID, p_statement: statement),
            "The private dispute statement could not be saved."
        )
    }

    func evidenceExport(disputeID: UUID) async throws -> [String: JSONValue] {
        struct Params: Encodable { let p_dispute_id: UUID }
        return try await translated {
            let result: [String: JSONValue] = try await client.rpc(
                "request_payment_evidence_export",
                params: Params(p_dispute_id: disputeID)
            ).execute().value
            guard result["ok"]?.boolValue == true else {
                throw MortError.backend(
                    code: result["code"]?.stringValue ?? "evidence_export_failed",
                    message: "The authorized evidence export could not be generated."
                )
            }
            return result
        }
    }

    private func action<Params: Encodable & Sendable>(
        _ function: String,
        _ params: Params,
        _ defaultMessage: String
    ) async throws -> GenericRPCResult {
        try await translated {
            let result: GenericRPCResult = try await client.rpc(function, params: params).execute().value
            return try result.requireSuccess(defaultMessage: defaultMessage)
        }
    }

    private static let disputeFields = "id,obligation_id,contract_id,status,guilt_determined,classification_status,worker_statement,poster_statement,retaliation_review_active,publication_paused,opened_at"
    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unversioned"
    }
}

protocol FirstPartyTrustRepositoryProtocol: Sendable {
    func status() async throws -> FirstPartyTrustStatus
    func teamAssignments() async throws -> [TeamRoleAssignmentRecord]
    func appearanceCases() async throws -> [AppearanceReviewCaseRecord]
    func assignAppearanceReviewer(caseID: UUID, reviewerID: UUID, position: Int, purpose: String) async throws -> GenericRPCResult
}

final class FirstPartyTrustRepository: SupabaseRepository, FirstPartyTrustRepositoryProtocol {
    func status() async throws -> FirstPartyTrustStatus {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_first_party_trust_status").execute().value
        }
    }

    func teamAssignments() async throws -> [TeamRoleAssignmentRecord] {
        try await translated {
            try await client.from("team_role_assignments")
                .select("id,user_id,role_key,environment_scope,access_status,approval_reason,access_reason,expires_at")
                .order("created_at", ascending: false)
                .execute().value
        }
    }

    func appearanceCases() async throws -> [AppearanceReviewCaseRecord] {
        try await translated {
            try await client.from("appearance_review_cases")
                .select("id,subject_user_id,review_state,final_result,synthetic_qa,contains_real_face_data")
                .order("created_at", ascending: false)
                .execute().value
        }
    }

    func assignAppearanceReviewer(caseID: UUID, reviewerID: UUID, position: Int, purpose: String) async throws -> GenericRPCResult {
        struct Params: Encodable {
            let p_case_id: UUID
            let p_reviewer_id: UUID
            let p_review_position: Int
            let p_purpose: String
            let p_expires_at: Date
        }
        return try await translated {
            let result: GenericRPCResult = try await client.rpc(
                "admin_assign_appearance_reviewer",
                params: Params(
                    p_case_id: caseID,
                    p_reviewer_id: reviewerID,
                    p_review_position: position,
                    p_purpose: purpose,
                    p_expires_at: Date().addingTimeInterval(24 * 60 * 60)
                )
            ).execute().value
            return try result.requireSuccess(defaultMessage: "The bounded reviewer assignment could not be created.")
        }
    }
}
