import Foundation
import Observation

@MainActor
@Observable
final class BiometricReauthenticationService {
    private let authentication: DeviceAuthenticationService
    private var approvals: [SensitiveAction: Date] = [:]
    private(set) var lastResult: BiometricAuthenticationResult?

    init(authentication: DeviceAuthenticationService) {
        self.authentication = authentication
    }

    func capability() -> BiometricCapability { authentication.capability() }

    func authorize(_ action: SensitiveAction) async -> Bool {
        let policy = SensitiveActionReauthenticationPolicy.policy(for: action)
        let result = await authentication.authenticate(policy: policy)
        lastResult = result
        if result.succeeded {
            approvals[action] = Date().addingTimeInterval(policy.validityDuration)
            return true
        }
        approvals[action] = nil
        return false
    }

    func consumeAuthorization(for action: SensitiveAction, now: Date = Date()) -> Bool {
        guard let expiresAt = approvals[action], expiresAt > now else {
            approvals[action] = nil
            return false
        }
        approvals[action] = nil
        return true
    }

    func isAuthorized(_ action: SensitiveAction, now: Date = Date()) -> Bool {
        guard let expiresAt = approvals[action] else { return false }
        return expiresAt > now
    }
}
