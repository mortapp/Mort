import SwiftUI
import UIKit

@main
@MainActor
struct MORTApp: App {
    @UIApplicationDelegateAdaptor(MORTAppDelegate.self) private var appDelegate
    @State private var bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = bootstrap.container {
                    RootView()
                        .environment(container)
                        .environment(container.router)
                        .environment(container.session)
                        .environment(container.revenueCat)
                        .task {
                            appDelegate.pushService = container.push
                            await container.session.start()
                            await container.push.refreshAuthorizationState()
                            await container.ads.startIfEnabled()
                        }
                        .onOpenURL { url in Task { await container.session.handleIncomingURL(url) } }
                } else {
                    ConfigurationFailureView(message: bootstrap.errorMessage ?? "MORT could not load its build configuration.")
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class MORTAppDelegate: NSObject, UIApplicationDelegate {
    weak var pushService: PushNotificationService?

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        pushService?.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        pushService?.didFailToRegister(error: error)
    }
}

private struct ConfigurationFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: MortSpacing.lg) {
            Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 42)).foregroundStyle(MortColors.warning)
            Text("Build setup required").font(MortTypography.title)
            Text(message).multilineTextAlignment(.center).foregroundStyle(MortColors.textMuted)
            Text("Add the client-safe values in Config/Secrets.xcconfig on a Mac. Never add a service-role key.")
                .font(MortTypography.caption).multilineTextAlignment(.center).foregroundStyle(MortColors.textMuted)
        }
        .padding(MortSpacing.xl)
        .mortScreen()
    }
}
