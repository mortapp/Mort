import Foundation
import Observation

enum BiometricFailureReason: String, CaseIterable, Sendable {
    case unavailable
    case notEnrolled
    case userCancelled
    case failedMatch
    case lockout
    case systemCancelled
    case permissionDenied
    case unknown

    init(result: BiometricAuthenticationResult?) {
        switch result {
        case .some(.unavailable): self = .unavailable
        case .some(.notEnrolled): self = .notEnrolled
        case .some(.cancelled): self = .userCancelled
        case .some(.failedMatch): self = .failedMatch
        case .some(.lockedOut): self = .lockout
        case .some(.systemCancelled): self = .systemCancelled
        case .some(.permissionDenied): self = .permissionDenied
        default: self = .unknown
        }
    }

    var message: String {
        switch self {
        case .unavailable: "Device authentication is unavailable on this device."
        case .notEnrolled: "Set up Face ID or Touch ID in iOS Settings, or use the device passcode when offered."
        case .userCancelled: "Authentication was cancelled. Private MORT content remains locked."
        case .failedMatch: "The biometric match failed. Try again or use the device passcode when offered."
        case .lockout: "Biometrics are locked after failed attempts. Unlock the device with its passcode first."
        case .systemCancelled: "iOS cancelled the prompt because the app or system state changed. Try again."
        case .permissionDenied: "A device passcode or biometric permission is required for app lock."
        case .unknown: "Authentication did not succeed. Private MORT content remains locked."
        }
    }
}

@MainActor
@Observable
final class AppLockService {
    private enum Key {
        static let enabled = "mort.appLock.enabled"
        static let inactivityMinutes = "mort.appLock.inactivityMinutes"
    }

    private let authentication: BiometricReauthenticationService
    private let defaults: UserDefaults
    private var backgroundedAt: Date?
    private var lastCapability: BiometricCapability

    private(set) var isLocked = false
    private(set) var failureReason: BiometricFailureReason?
    var enabled: Bool
    var inactivityMinutes: Int

    init(
        authentication: BiometricReauthenticationService,
        defaults: UserDefaults = .standard
    ) {
        self.authentication = authentication
        self.defaults = defaults
        enabled = defaults.bool(forKey: Key.enabled)
        let storedMinutes = defaults.integer(forKey: Key.inactivityMinutes)
        inactivityMinutes = storedMinutes == 0 ? 15 : min(max(storedMinutes, 1), 240)
        lastCapability = authentication.capability()
    }

    func update(enabled: Bool, inactivityMinutes: Int) {
        self.enabled = enabled
        self.inactivityMinutes = min(max(inactivityMinutes, 1), 240)
        defaults.set(enabled, forKey: Key.enabled)
        defaults.set(self.inactivityMinutes, forKey: Key.inactivityMinutes)
        if !enabled {
            isLocked = false
            failureReason = nil
        }
    }

    func didEnterBackground(at date: Date = Date()) {
        backgroundedAt = date
    }

    func didBecomeActive(at date: Date = Date()) {
        guard enabled else { return }
        let capability = authentication.capability()
        if capability != lastCapability {
            isLocked = true
        }
        lastCapability = capability
        guard let backgroundedAt else { return }
        if date.timeIntervalSince(backgroundedAt) >= Double(inactivityMinutes * 60) {
            isLocked = true
        }
        self.backgroundedAt = nil
    }

    func lockNow() {
        guard enabled else { return }
        isLocked = true
        failureReason = nil
    }

    func unlock() async {
        guard isLocked else { return }
        if await authentication.authorize(.openAfterTimeout),
           authentication.consumeAuthorization(for: .openAfterTimeout) {
            isLocked = false
            failureReason = nil
        } else {
            failureReason = BiometricFailureReason(result: authentication.lastResult)
        }
    }
}
