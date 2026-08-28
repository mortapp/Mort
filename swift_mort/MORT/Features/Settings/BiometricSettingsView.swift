import SwiftUI

struct BiometricSettingsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var enabled = false
    @State private var minutes = 15
    @State private var message: String?

    var body: some View {
        Form {
            Section("On-device protection") {
                Toggle("Require app lock", isOn: $enabled)
                Stepper("Lock after \(minutes) minutes", value: $minutes, in: 1 ... 240)
                Button("Save app-lock settings") {
                    container.appLock.update(enabled: enabled, inactivityMinutes: minutes)
                    message = enabled ? "App lock is enabled on this device." : "App lock is disabled on this device."
                }
                if enabled {
                    Button("Lock MORT now") { container.appLock.lockNow() }
                }
            }
            Section("What this means") {
                Text("MORT uses Face ID or Touch ID to protect private information on this device. It does not verify your legal identity.")
                Label("No face or fingerprint data is available to MORT", systemImage: "checkmark.shield.fill")
                Label("No biometric template is stored or sent to Supabase", systemImage: "checkmark.shield.fill")
                Label("Device passcode fallback is used when iOS permits it", systemImage: "key.fill")
            }
            Section("Capability") {
                LabeledContent("Available method", value: container.biometricReauthentication.capability().title)
                SensitiveActionGate(action: .highRiskAccountAction, title: "Test device authentication") {
                    message = "Local device authentication succeeded. No identity level changed."
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MortColors.background)
        .navigationTitle("Face ID and app lock")
        .onAppear {
            enabled = container.appLock.enabled
            minutes = container.appLock.inactivityMinutes
        }
        .alert("Device security", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }
}

struct AppLockView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var working = false

    var body: some View {
        ZStack {
            MortColors.background.ignoresSafeArea()
            VStack(spacing: MortSpacing.lg) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(MortColors.neon)
                Text("MORT is locked").font(MortTypography.title)
                Text("Unlock to view private account and marketplace information.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MortColors.textMuted)
                MortPrimaryButton(title: working ? "Authenticating..." : "Unlock MORT", icon: "faceid", isLoading: working) {
                    Task {
                        working = true
                        await container.appLock.unlock()
                        working = false
                    }
                }
                if let failure = container.appLock.failureReason {
                    Text(failure.message)
                        .font(MortTypography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(MortColors.warning)
                }
                Text("Face ID and Touch ID protect this device only. They do not verify legal identity, age, or safety.")
                    .font(MortTypography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MortColors.textMuted)
            }
            .padding(MortSpacing.xl)
        }
        .accessibilityAddTraits(.isModal)
    }
}
