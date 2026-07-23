import Foundation
import CryptoKit
import OSLog
import Supabase

protocol StorageRepositoryProtocol: Sendable {
    func uploadAvatar(_ image: PreparedImage, replacing previousPath: String?) async throws -> String
    func removeAvatar(path: String?) async throws
    func signedAvatarURL(profileID: UUID, path: String?) async throws -> URL?
    func uploadProof(applicationID: UUID, submissionID: UUID, image: PreparedImage, note: String?) async throws -> String
    func uploadVerification(submissionID: UUID, businessName: String, businessType: String, image: PreparedImage, notes: String?) async throws -> String
    func uploadIdentityEvidence(verificationID: UUID, evidenceType: IdentityEvidenceKind, image: PreparedImage) async throws -> String
    func uploadIncidentEvidence(incidentID: UUID, evidenceType: String, image: PreparedImage) async throws -> String
    func signedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL
}

final class StorageRepository: SupabaseRepository, StorageRepositoryProtocol {
    static let avatarBucket = "profile-avatars"
    static let proofBucket = "proof-uploads"
    static let verificationBucket = "verification-uploads"
    static let reportBucket = "report-uploads"
    static let identityEvidenceBucket = "identity-evidence"
    static let incidentEvidenceBucket = "incident-evidence"

    private let profileRepository: ProfileRepositoryProtocol
    private let logger = Logger(subsystem: "com.mortapp.mobile", category: "storage")

    init(client: SupabaseClient, profileRepository: ProfileRepositoryProtocol) {
        self.profileRepository = profileRepository
        super.init(client: client)
    }

    func uploadAvatar(_ image: PreparedImage, replacing previousPath: String?) async throws -> String {
        try await translated {
            let userID = try await currentUserID()
            let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            try await upload(bucket: Self.avatarBucket, path: path, data: image.data)
            do {
                try await profileRepository.setAvatarPath(path)
            } catch {
                await removeAfterFailedTransaction(bucket: Self.avatarBucket, path: path)
                throw error
            }
            if let previousPath, previousPath != path {
                do { try await client.storage.from(Self.avatarBucket).remove(paths: [previousPath]) }
                catch { logger.warning("Old avatar cleanup failed after replacement: \(error.localizedDescription, privacy: .public)") }
            }
            return path
        }
    }

    func removeAvatar(path: String?) async throws {
        try await translated {
            try await profileRepository.setAvatarPath(nil)
            if let path { try await client.storage.from(Self.avatarBucket).remove(paths: [path]) }
        }
    }

    func signedAvatarURL(profileID: UUID, path: String?) async throws -> URL? {
        guard let path = path?.nilIfBlank else { return nil }
        return try await translated {
            if profileID == try await currentUserID() {
                return try await signedURL(bucket: Self.avatarBucket, path: path, expiresIn: 3_600)
            }
            struct Response: Decodable { let signedURL: URL }
            let response: Response = try await client.functions.invoke(
                "avatar-url",
                options: FunctionInvokeOptions(body: ["profileId": profileID.uuidString.lowercased()])
            )
            return response.signedURL
        }
    }

    func uploadProof(applicationID: UUID, submissionID: UUID, image: PreparedImage, note: String?) async throws -> String {
        struct Params: Encodable {
            let p_proof_id: UUID
            let p_application_id: UUID
            let p_storage_path: String
            let p_note: String?
        }
        return try await translated {
            let userID = try await currentUserID()
            let path = "\(userID.uuidString.lowercased())/\(submissionID.uuidString.lowercased()).jpg"
            try await upload(bucket: Self.proofBucket, path: path, data: image.data)
            do {
                let result: ProofRPCResult = try await client.rpc("submit_application_proof", params: Params(
                    p_proof_id: submissionID,
                    p_application_id: applicationID,
                    p_storage_path: path,
                    p_note: note?.nilIfBlank
                )).execute().value
                guard result.ok else { throw MortError.backend(code: result.code ?? "unknown_permission_failure", message: result.message) }
                return path
            } catch {
                await removeAfterFailedTransaction(bucket: Self.proofBucket, path: path)
                throw error
            }
        }
    }

    func uploadVerification(
        submissionID: UUID,
        businessName: String,
        businessType: String,
        image: PreparedImage,
        notes: String?
    ) async throws -> String {
        struct Params: Encodable {
            let p_verification_id: UUID
            let p_storage_path: String
            let p_business_name: String
            let p_business_type: String
            let p_notes: String?
        }
        return try await translated {
            let userID = try await currentUserID()
            let path = "\(userID.uuidString.lowercased())/\(submissionID.uuidString.lowercased()).jpg"
            try await upload(bucket: Self.verificationBucket, path: path, data: image.data)
            do {
                let result: ProofRPCResult = try await client.rpc("submit_business_verification", params: Params(
                    p_verification_id: submissionID,
                    p_storage_path: path,
                    p_business_name: businessName.trimmed,
                    p_business_type: businessType.trimmed,
                    p_notes: notes?.nilIfBlank
                )).execute().value
                guard result.ok else { throw MortError.backend(code: result.code ?? "unknown_permission_failure", message: result.message) }
                return path
            } catch {
                await removeAfterFailedTransaction(bucket: Self.verificationBucket, path: path)
                throw error
            }
        }
    }

    func uploadIdentityEvidence(
        verificationID: UUID,
        evidenceType: IdentityEvidenceKind,
        image: PreparedImage
    ) async throws -> String {
        struct Params: Encodable {
            let p_verification_id: UUID
            let p_evidence_id: UUID
            let p_storage_path: String
            let p_evidence_type: String
            let p_sha256: String
        }
        return try await translated {
            let userID = try await currentUserID()
            let evidenceID = UUID()
            let path = "\(userID.uuidString.lowercased())/\(verificationID.uuidString.lowercased())/\(evidenceType.rawValue)-\(evidenceID.uuidString.lowercased()).jpg"
            try await upload(bucket: Self.identityEvidenceBucket, path: path, data: image.data)
            do {
                let hash = SHA256.hash(data: image.data).map { String(format: "%02X", $0) }.joined()
                let result: TrustSafetyActionResult = try await client.rpc("register_identity_evidence", params: Params(
                    p_verification_id: verificationID,
                    p_evidence_id: evidenceID,
                    p_storage_path: path,
                    p_evidence_type: evidenceType.rawValue,
                    p_sha256: hash
                )).execute().value
                _ = try result.requireSuccess(defaultMessage: "The identity evidence could not be registered.")
                return path
            } catch {
                await removeAfterFailedTransaction(bucket: Self.identityEvidenceBucket, path: path)
                throw error
            }
        }
    }

    func uploadIncidentEvidence(
        incidentID: UUID,
        evidenceType: String,
        image: PreparedImage
    ) async throws -> String {
        struct Params: Encodable {
            let p_incident_id: UUID
            let p_evidence_id: UUID
            let p_storage_path: String
            let p_evidence_type: String
            let p_sha256: String
        }
        return try await translated {
            let userID = try await currentUserID()
            let evidenceID = UUID()
            let path = "\(userID.uuidString.lowercased())/\(incidentID.uuidString.lowercased())/\(evidenceID.uuidString.lowercased()).jpg"
            try await upload(bucket: Self.incidentEvidenceBucket, path: path, data: image.data)
            do {
                let hash = SHA256.hash(data: image.data).map { String(format: "%02X", $0) }.joined()
                let result: TrustSafetyActionResult = try await client.rpc("register_incident_evidence", params: Params(
                    p_incident_id: incidentID,
                    p_evidence_id: evidenceID,
                    p_storage_path: path,
                    p_evidence_type: String(evidenceType.trimmed.prefix(80)),
                    p_sha256: hash
                )).execute().value
                _ = try result.requireSuccess(defaultMessage: "The incident evidence could not be registered.")
                return path
            } catch {
                await removeAfterFailedTransaction(bucket: Self.incidentEvidenceBucket, path: path)
                throw error
            }
        }
    }

    func signedURL(bucket: String, path: String, expiresIn: Int = 600) async throws -> URL {
        guard [Self.avatarBucket, Self.proofBucket, Self.verificationBucket, Self.reportBucket, Self.identityEvidenceBucket, Self.incidentEvidenceBucket].contains(bucket) else {
            throw MortError.invalidInput("Unknown private storage bucket.")
        }
        return try await client.storage.from(bucket).createSignedURL(path: path, expiresIn: expiresIn)
    }

    private func upload(bucket: String, path: String, data: Data) async throws {
        try await client.storage.from(bucket).upload(
            path,
            data: data,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)
        )
    }

    private func removeAfterFailedTransaction(bucket: String, path: String) async {
        do { try await client.storage.from(bucket).remove(paths: [path]) }
        catch { logger.error("Orphan upload cleanup failed: \(error.localizedDescription, privacy: .public)") }
    }
}
