import LocalAuthentication
import XCTest
@testable import MORT

@MainActor
final class DeviceAuthenticationServiceTests: XCTestCase {
    func testUnavailableBiometrics() async {
        let evaluator = AuthenticationEvaluatorStub(biometricsAvailable: false, ownerAuthenticationAvailable: false)
        let service = DeviceAuthenticationService { evaluator }

        XCTAssertEqual(service.capability(), .unavailable)
        let result = await service.authenticate(policy: policy())
        XCTAssertEqual(result, .unavailable)
    }

    func testDeniedPermission() async {
        let evaluator = AuthenticationEvaluatorStub(
            biometricsAvailable: true,
            biometricError: laError(.biometryNotAvailable)
        )
        let service = DeviceAuthenticationService { evaluator }

        let result = await service.authenticate(policy: policy(allowFallback: false))
        XCTAssertEqual(result, .permissionDenied)
    }

    func testFailedMatch() async {
        let evaluator = AuthenticationEvaluatorStub(
            biometricsAvailable: true,
            biometricError: laError(.authenticationFailed)
        )
        let service = DeviceAuthenticationService { evaluator }

        let result = await service.authenticate(policy: policy(allowFallback: false))
        XCTAssertEqual(result, .failedMatch)
    }

    func testCancelledPrompt() async {
        let evaluator = AuthenticationEvaluatorStub(
            biometricsAvailable: true,
            biometricError: laError(.userCancel)
        )
        let service = DeviceAuthenticationService { evaluator }

        let result = await service.authenticate(policy: policy())
        XCTAssertEqual(result, .cancelled)
    }

    func testLockoutWithoutFallback() async {
        let evaluator = AuthenticationEvaluatorStub(
            biometricsAvailable: true,
            biometricError: laError(.biometryLockout)
        )
        let service = DeviceAuthenticationService { evaluator }

        let result = await service.authenticate(policy: policy(allowFallback: false))
        XCTAssertEqual(result, .lockedOut)
    }

    func testPasscodeFallback() async {
        let evaluator = AuthenticationEvaluatorStub(
            biometricsAvailable: true,
            ownerAuthenticationAvailable: true,
            biometricError: laError(.userFallback),
            ownerResult: true
        )
        let service = DeviceAuthenticationService { evaluator }

        let result = await service.authenticate(policy: policy())
        XCTAssertEqual(result, .passcodeFallbackAuthenticated)
    }

    func testSuccessfulReauthentication() async {
        let evaluator = AuthenticationEvaluatorStub(
            biometryType: .faceID,
            biometricsAvailable: true,
            biometricResult: true
        )
        let service = DeviceAuthenticationService { evaluator }

        let result = await service.authenticate(policy: policy())
        XCTAssertEqual(result, .authenticated(.faceID))
    }

    func testFailureLeavesSensitiveActionBlocked() async {
        let evaluator = AuthenticationEvaluatorStub(
            biometricsAvailable: true,
            biometricError: laError(.authenticationFailed)
        )
        let authentication = DeviceAuthenticationService { evaluator }
        let gate = BiometricReauthenticationService(authentication: authentication)

        let authorized = await gate.authorize(.revealPrivateAddress)
        XCTAssertFalse(authorized)
        XCTAssertFalse(gate.isAuthorized(.revealPrivateAddress))
        XCTAssertFalse(gate.consumeAuthorization(for: .revealPrivateAddress))
    }

    func testSuccessUnlocksOnlyRequestedActionAndIsOneShot() async {
        let evaluator = AuthenticationEvaluatorStub(biometricsAvailable: true, biometricResult: true)
        let authentication = DeviceAuthenticationService { evaluator }
        let gate = BiometricReauthenticationService(authentication: authentication)

        let authorized = await gate.authorize(.submitProof)
        XCTAssertTrue(authorized)
        XCTAssertTrue(gate.isAuthorized(.submitProof))
        XCTAssertFalse(gate.isAuthorized(.deleteAccount))
        XCTAssertTrue(gate.consumeAuthorization(for: .submitProof))
        XCTAssertFalse(gate.consumeAuthorization(for: .submitProof))
    }

    private func policy(allowFallback: Bool = true) -> SensitiveActionReauthenticationPolicy {
        SensitiveActionReauthenticationPolicy(
            action: .highRiskAccountAction,
            validityDuration: 60,
            allowPasscodeFallback: allowFallback
        )
    }

    private func laError(_ code: LAError.Code) -> NSError {
        NSError(domain: LAError.errorDomain, code: code.rawValue)
    }
}

@MainActor
private final class AuthenticationEvaluatorStub: DeviceAuthenticationEvaluating {
    let biometryType: LABiometryType
    let biometricsAvailable: Bool
    let ownerAuthenticationAvailable: Bool
    let biometricResult: Bool
    let biometricError: Error?
    let ownerResult: Bool
    let ownerError: Error?

    init(
        biometryType: LABiometryType = .touchID,
        biometricsAvailable: Bool,
        ownerAuthenticationAvailable: Bool = true,
        biometricResult: Bool = false,
        biometricError: Error? = nil,
        ownerResult: Bool = false,
        ownerError: Error? = nil
    ) {
        self.biometryType = biometryType
        self.biometricsAvailable = biometricsAvailable
        self.ownerAuthenticationAvailable = ownerAuthenticationAvailable
        self.biometricResult = biometricResult
        self.biometricError = biometricError
        self.ownerResult = ownerResult
        self.ownerError = ownerError
    }

    func canEvaluate(_ policy: LAPolicy) -> Bool {
        policy == .deviceOwnerAuthenticationWithBiometrics
            ? biometricsAvailable
            : ownerAuthenticationAvailable
    }

    func evaluate(_ policy: LAPolicy, reason: String) async throws -> Bool {
        if policy == .deviceOwnerAuthenticationWithBiometrics {
            if let biometricError { throw biometricError }
            return biometricResult
        }
        if let ownerError { throw ownerError }
        return ownerResult
    }
}
