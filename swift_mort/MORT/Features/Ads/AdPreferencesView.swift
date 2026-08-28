import SwiftUI

struct AdPreferencesView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var personalized = false
    @State private var consentReady = false
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Ad preferences", subtitle: "Ads are disabled by default until native review, consent, and device testing are complete.")
                Toggle("Allow personalized ads", isOn: $personalized)
                    .tint(MortColors.neon)
                    .disabled(session.profile?.role == .teen)
                Toggle("Consent choice is complete", isOn: $consentReady).tint(MortColors.neon)
                if session.profile?.role == .teen {
                    MortSafetyBanner(message: "Teen accounts use conservative age-restricted, non-personalized ad handling. This cannot be relaxed here.")
                }
                MortAlertBanner(title: "Sensitive screens stay ad-free", message: "Auth, onboarding, age gate, messages, reports, Safety Ping, guardian approval, proof, verification, payments, admin, and paywalls block ads.", tint: MortColors.safetyBlue, icon: "rectangle.slash.fill")
                MortPrimaryButton(title: "Save ad preferences", icon: "checkmark", isLoading: isWorking) { Task { await save() } }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Ads")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ad preferences", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        do {
            if let preferences = try await container.monetization.adPreferences() {
                personalized = session.profile?.role == .teen ? false : preferences.personalizedAdsAllowed
                consentReady = preferences.adsConsentReady
            }
        } catch { message = mortMessage(error) }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let teen = session.profile?.role == .teen
            try await container.monetization.saveAdPreferences(personalized: teen ? false : personalized, consentReady: consentReady, ageRestricted: teen)
            message = "Ad preferences saved."
        } catch { message = mortMessage(error) }
    }
}
