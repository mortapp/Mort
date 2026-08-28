import Foundation
import Observation
import UIKit
import UserNotifications

enum PushAuthorizationState: Equatable, Sendable {
    case unknown
    case denied
    case authorized
    case provisional
}

@MainActor
@Observable
final class PushNotificationService: NSObject, UNUserNotificationCenterDelegate {
    private(set) var authorizationState: PushAuthorizationState = .unknown
    private(set) var apnsDeviceToken: String?
    private(set) var registrationError: String?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func refreshAuthorizationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationState = Self.map(settings.authorizationStatus)
    }

    func requestPermission() async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        await refreshAuthorizationState()
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }

    func didRegister(deviceToken: Data) {
        apnsDeviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        registrationError = nil
        // The current backend push_tokens table stores Expo tokens only. APNs persistence stays disabled
        // until an additive backend contract and APNs provider are deployed.
    }

    func didFailToRegister(error: Error) {
        registrationError = error.localizedDescription
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    private static func map(_ status: UNAuthorizationStatus) -> PushAuthorizationState {
        switch status {
        case .authorized: .authorized
        case .provisional, .ephemeral: .provisional
        case .denied: .denied
        case .notDetermined: .unknown
        @unknown default: .unknown
        }
    }
}
