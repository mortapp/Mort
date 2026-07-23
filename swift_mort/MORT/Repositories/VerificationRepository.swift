import Foundation
import Supabase

protocol VerificationRepositoryProtocol: Sendable {
    func listMine() async throws -> [BusinessVerification]
    func submit(businessName: String, businessType: String, image: PreparedImage, notes: String?) async throws -> String
    func identityStatus() async throws -> IdentityVerificationSummary
    func createSandboxIdentitySession() async throws -> TrustSafetyActionResult
    func startIdentity(route: IdentityEvidenceRoute, exceptionReason: String?) async throws -> TrustSafetyActionResult
    func uploadIdentityEvidence(verificationID: UUID, evidenceType: IdentityEvidenceKind, image: PreparedImage) async throws -> String
    func submitIdentity(verificationID: UUID) async throws -> TrustSafetyActionResult
    func appealIdentity(verificationID: UUID, reason: String) async throws -> TrustSafetyActionResult
}

final class VerificationRepository: SupabaseRepository, VerificationRepositoryProtocol {
    private let storage: StorageRepositoryProtocol

    init(client: SupabaseClient, storage: StorageRepositoryProtocol) {
        self.storage = storage
        super.init(client: client)
    }

    func listMine() async throws -> [BusinessVerification] {
        try await translated {
            try await client.from("business_verifications")
                .select("id,business_name,business_type,status,created_at,updated_at")
                .eq("adult_id", value: try await currentUserID())
                .order("created_at", ascending: false).limit(20).execute().value
        }
    }

    func submit(businessName: String, businessType: String, image: PreparedImage, notes: String?) async throws -> String {
        try await storage.uploadVerification(
            submissionID: UUID(),
            businessName: businessName,
            businessType: businessType,
            image: image,
            notes: notes
        )
    }

    func identityStatus() async throws -> IdentityVerificationSummary {
        try await translated {
            _ = try await currentUserID()
            return try await client.rpc("get_my_identity_verification").execute().value
        }
    }

    func startIdentity(route: IdentityEvidenceRoute, exceptionReason: String?) async throws -> TrustSafetyActionResult {
        struct Params: Encodable {
            let p_evidence_route: String
            let p_attested: Bool
            let p_exception_reason: String?
        }
        return try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("start_identity_verification", params: Params(
                p_evidence_route: route.rawValue,
                p_attested: true,
                p_exception_reason: exceptionReason?.nilIfBlank
            )).execute().value
            return try result.requireSuccess(defaultMessage: "Identity verification could not be started.")
        }
    }

    func createSandboxIdentitySession() async throws -> TrustSafetyActionResult {
        struct Params: Encodable {
            let p_evidence_route: String
            let p_attested: Bool
            let p_exception_reason: String?
        }
        return try await translated {
            let result: TrustSafetyActionResult = try await client.rpc(
                "start_identity_verification",
                params: Params(
                    p_evidence_route: "sandbox_simulation",
                    p_attested: true,
                    p_exception_reason: nil
                )
            ).execute().value
            return try result.requireSuccess(defaultMessage: "The sandbox verification session could not be started.")
        }
    }

    func uploadIdentityEvidence(verificationID: UUID, evidenceType: IdentityEvidenceKind, image: PreparedImage) async throws -> String {
        throw MortError.backend(
            code: "identity_document_collection_disabled",
            message: "MORT does not accept direct identity-document uploads."
        )
    }

    func submitIdentity(verificationID: UUID) async throws -> TrustSafetyActionResult {
        struct Params: Encodable { let p_verification_id: UUID; let p_acknowledged: Bool }
        return try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("submit_identity_verification", params: Params(
                p_verification_id: verificationID,
                p_acknowledged: true
            )).execute().value
            return try result.requireSuccess(defaultMessage: "Identity verification could not be submitted.")
        }
    }

    func appealIdentity(verificationID: UUID, reason: String) async throws -> TrustSafetyActionResult {
        struct Params: Encodable { let p_verification_id: UUID; let p_reason: String }
        return try await translated {
            let result: TrustSafetyActionResult = try await client.rpc("submit_identity_verification_appeal", params: Params(
                p_verification_id: verificationID,
                p_reason: reason.trimmed
            )).execute().value
            return try result.requireSuccess(defaultMessage: "The appeal could not be submitted.")
        }
    }
}
