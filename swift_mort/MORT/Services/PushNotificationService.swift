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
    private var didRequestAuthorization = false
    private var lastResolvedAuthorizationState: PushAuthorizationState?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func refreshAuthorizationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = Self.map(settings.authorizationStatus)
        authorizationState = status
        lastResolvedAuthorizationState = status
    }

    func ensureAuthorizedIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status = Self.map(settings.authorizationStatus)

        switch status {
        case .authorized, .provisional:
            authorizationState = status
            lastResolvedAuthorizationState = status
            UIApplication.shared.registerForRemoteNotifications()
            return
        case .denied:
            authorizationState = .denied
            lastResolvedAuthorizationState = .denied
            return
        case .unknown:
            guard !didRequestAuthorization else { return }
            didRequestAuthorization = true

            do {
                let granted = try await requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    authorizationState = .authorized
                } else {
                    authorizationState = .denied
                }
                lastResolvedAuthorizationState = authorizationState
            } catch {
                registrationError = error.localizedDescription
                authorizationState = .denied
                lastResolvedAuthorizationState = .denied
            }
        }
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        await refreshAuthorizationState()
        return granted
    }

    func requestPermission() async throws -> Bool {
        let granted = try await requestAuthorization(options: [.alert, .badge, .sound])
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    func didRegister(deviceToken: Data) {
        apnsDeviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        registrationError = nil
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
