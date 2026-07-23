import Foundation

enum VerificationEnvironment: String, Codable, Sendable {
    case sandbox
    case production
}

enum VerificationEvidenceType: String, Codable, Sendable {
    case governmentID = "government_id"
    case schoolID = "school_id"
    case selfieLiveness = "selfie_liveness"
    case addressEvidence = "address_evidence"
    case providerAssertion = "provider_assertion"
}

enum VerificationDecision: String, Codable, Sendable {
    case approved
    case rejected
    case needsReview = "needs_review"
}

enum VerificationFailureReason: String, Error, Codable, Sendable {
    case disabled
    case sandboxAccountRequired = "sandbox_account_required"
    case providerNotConfigured = "provider_not_configured"
    case signatureInvalid = "signature_invalid"
    case replayedEvent = "replayed_event"
    case accountBindingMismatch = "account_binding_mismatch"
    case unknownResult = "unknown_result"
}

struct VerificationSession: Codable, Hashable, Sendable {
    let id: UUID
    let environment: VerificationEnvironment
    let provider: String
    let providerReference: String
    let testMode: Bool
    let documentsAllowed: Bool
}

struct VerificationResult: Codable, Hashable, Sendable {
    let environment: VerificationEnvironment
    let decision: VerificationDecision
    let provider: String
    let providerReference: String
    let productionEligible: Bool
}

protocol IdentityVerificationProvider {
    func createSession() async throws -> VerificationSession
}

struct DisabledVerificationProvider: IdentityVerificationProvider {
    func createSession() async throws -> VerificationSession {
        throw MortError.backend(
            code: "identity_verification_disabled",
            message: "Identity verification is not accepting public submissions yet."
        )
    }
}

struct SandboxVerificationProvider: IdentityVerificationProvider {
    let create: () async throws -> TrustSafetyActionResult

    func createSession() async throws -> VerificationSession {
        let response = try await create()
        guard response.environment == VerificationEnvironment.sandbox.rawValue,
              response.testMode == true,
              let id = response.id,
              let provider = response.provider,
              let providerReference = response.providerReference else {
            throw MortError.backend(
                code: "sandbox_environment_mismatch",
                message: "The backend did not return an isolated sandbox session."
            )
        }
        return VerificationSession(
            id: id,
            environment: .sandbox,
            provider: provider,
            providerReference: providerReference,
            testMode: true,
            documentsAllowed: response.documentsAllowed == true
        )
    }
}

protocol ProductionVerificationProvider: IdentityVerificationProvider {}

struct UnavailableProductionVerificationProvider: ProductionVerificationProvider {
    func createSession() async throws -> VerificationSession {
        throw MortError.backend(
            code: "production_provider_not_configured",
            message: "Production identity verification is unavailable until an approved provider is connected."
        )
    }
}
