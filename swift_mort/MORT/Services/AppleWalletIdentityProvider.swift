import Foundation

enum WalletIdentityAttribute: String, Codable, Sendable {
    case ageOverThreshold = "age_over_threshold"
    case ageBand = "age_band"
    case givenName = "given_name"
    case familyName = "family_name"
}

struct WalletIdentityRequest: Codable, Hashable, Sendable {
    let serverNonce: String
    let accountBindingReference: String
    let attributes: [WalletIdentityAttribute]
    let purposeByAttribute: [String: String]
    let retentionSeconds: Int
}

struct WalletIdentityPresentation: Codable, Hashable, Sendable {
    let sessionID: UUID
    let eventID: String
    let opaquePayloadSHA256: String
    let presentedAt: Date
}

struct WalletIdentityVerificationResult: Codable, Hashable, Sendable {
    let verified: Bool
    let ageRequirementMet: Bool?
    let issuer: String?
    let credentialType: String?
    let expiresAt: Date?
    let failureCode: String?
    let backendValidated: Bool
}

protocol AppleWalletIdentityProvider: Sendable {
    var isAvailable: Bool { get }
    func request(_ request: WalletIdentityRequest) async throws -> WalletIdentityPresentation
}

struct DisabledAppleWalletIdentityProvider: AppleWalletIdentityProvider {
    let isAvailable = false

    func request(_ request: WalletIdentityRequest) async throws -> WalletIdentityPresentation {
        throw MortError.backend(
            code: "apple_wallet_identity_disabled",
            message: "Apple Wallet identity is disabled until MORT has Apple Developer membership, the required entitlement, backend validation, legal review, and real-device testing."
        )
    }
}
