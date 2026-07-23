import Foundation
import LocalAuthentication

enum BiometricCapability: Equatable, Sendable {
    case faceID
    case touchID
    case opticID
    case deviceOwnerAuthentication
    case unavailable

    var title: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .deviceOwnerAuthentication: "Device authentication"
        case .unavailable: "Unavailable"
        }
    }
}

enum BiometricAuthenticationResult: Equatable, Sendable {
    case authenticated(BiometricCapability)
    case passcodeFallbackAuthenticated
    case permissionDenied
    case notEnrolled
    case failedMatch
    case cancelled
    case systemCancelled
    case lockedOut
    case unavailable
    case failed

    var succeeded: Bool {
        switch self {
        case .authenticated, .passcodeFallbackAuthenticated: true
        default: false
        }
    }
}

enum SensitiveAction: String, CaseIterable, Sendable {
    case openAfterTimeout
    case revealPrivateAddress
    case changePaymentPreferences
    case changeVerificationSettings
    case viewIncidentRecords
    case deleteAccount
    case exportAccountData
    case revokeSessions
    case highRiskAccountAction
    case confirmArrival
    case submitProof

    var reason: String {
        switch self {
        case .openAfterTimeout: "Unlock MORT after inactivity."
        case .revealPrivateAddress: "Reveal the accepted job's private location."
        case .changePaymentPreferences: "Change payment preference information."
        case .changeVerificationSettings: "Change verification and account-trust settings."
        case .viewIncidentRecords: "View sensitive incident records."
        case .deleteAccount: "Confirm this account deletion request."
        case .exportAccountData: "Confirm this account data export."
        case .revokeSessions: "Revoke account sessions."
        case .highRiskAccountAction: "Confirm this high-risk account action."
        case .confirmArrival: "Confirm the accepted-job arrival handshake."
        case .submitProof: "Confirm this work proof submission."
        }
    }
}

struct SensitiveActionReauthenticationPolicy: Equatable, Sendable {
    let action: SensitiveAction
    let validityDuration: TimeInterval
    let allowPasscodeFallback: Bool

    static func policy(for action: SensitiveAction) -> SensitiveActionReauthenticationPolicy {
        SensitiveActionReauthenticationPolicy(
            action: action,
            validityDuration: action == .openAfterTimeout ? 300 : 60,
            allowPasscodeFallback: true
        )
    }
}

@MainActor
protocol DeviceAuthenticationEvaluating: AnyObject {
    var biometryType: LABiometryType { get }
    func canEvaluate(_ policy: LAPolicy) -> Bool
    func evaluate(_ policy: LAPolicy, reason: String) async throws -> Bool
}

@MainActor
private final class SystemDeviceAuthenticationEvaluator: DeviceAuthenticationEvaluating {
    private let context = LAContext()

    var biometryType: LABiometryType { context.biometryType }

    func canEvaluate(_ policy: LAPolicy) -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(policy, error: &error)
    }

    func evaluate(_ policy: LAPolicy, reason: String) async throws -> Bool {
        try await context.evaluatePolicy(policy, localizedReason: reason)
    }
}

@MainActor
final class DeviceAuthenticationService {
    private let evaluatorFactory: () -> any DeviceAuthenticationEvaluating

    init(evaluatorFactory: @escaping () -> any DeviceAuthenticationEvaluating = { SystemDeviceAuthenticationEvaluator() }) {
        self.evaluatorFactory = evaluatorFactory
    }

    func capability() -> BiometricCapability {
        let evaluator = evaluatorFactory()
        guard evaluator.canEvaluate(.deviceOwnerAuthenticationWithBiometrics) else {
            return evaluator.canEvaluate(.deviceOwnerAuthentication) ? .deviceOwnerAuthentication : .unavailable
        }
        switch evaluator.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .deviceOwnerAuthentication
        }
    }

    func authenticate(policy: SensitiveActionReauthenticationPolicy) async -> BiometricAuthenticationResult {
        let evaluator = evaluatorFactory()
        let capability = capability(for: evaluator)
        guard capability != .unavailable else { return .unavailable }

        if evaluator.canEvaluate(.deviceOwnerAuthenticationWithBiometrics) {
            do {
                if try await evaluator.evaluate(.deviceOwnerAuthenticationWithBiometrics, reason: policy.action.reason) {
                    return .authenticated(capability)
                }
                return .failedMatch
            } catch {
                let mapped = map(error)
                if policy.allowPasscodeFallback,
                   mapped == .lockedOut || mapped == .permissionDenied || laErrorCode(error) == .userFallback,
                   evaluator.canEvaluate(.deviceOwnerAuthentication) {
                    return await authenticateWithPasscode(evaluator, reason: policy.action.reason)
                }
                return mapped
            }
        }
        guard policy.allowPasscodeFallback, evaluator.canEvaluate(.deviceOwnerAuthentication) else { return .unavailable }
        return await authenticateWithPasscode(evaluator, reason: policy.action.reason)
    }

    private func capability(for evaluator: any DeviceAuthenticationEvaluating) -> BiometricCapability {
        guard evaluator.canEvaluate(.deviceOwnerAuthenticationWithBiometrics) else {
            return evaluator.canEvaluate(.deviceOwnerAuthentication) ? .deviceOwnerAuthentication : .unavailable
        }
        switch evaluator.biometryType {
        case .faceID: .faceID
        case .touchID: .touchID
        case .opticID: .opticID
        default: .deviceOwnerAuthentication
        }
    }

    private func authenticateWithPasscode(
        _ evaluator: any DeviceAuthenticationEvaluating,
        reason: String
    ) async -> BiometricAuthenticationResult {
        do {
            return try await evaluator.evaluate(.deviceOwnerAuthentication, reason: reason)
                ? .passcodeFallbackAuthenticated
                : .failed
        } catch { return map(error) }
    }

    private func map(_ error: Error) -> BiometricAuthenticationResult {
        guard let code = laErrorCode(error) else { return .failed }
        switch code {
        case .authenticationFailed: return .failedMatch
        case .userCancel, .userFallback: return .cancelled
        case .appCancel, .systemCancel: return .systemCancelled
        case .biometryLockout: return .lockedOut
        case .biometryNotEnrolled: return .notEnrolled
        case .biometryNotAvailable, .passcodeNotSet: return .permissionDenied
        default: return .failed
        }
    }

    private func laErrorCode(_ error: Error) -> LAError.Code? {
        let value = error as NSError
        guard value.domain == LAError.errorDomain else { return nil }
        return LAError.Code(rawValue: value.code)
    }
}
