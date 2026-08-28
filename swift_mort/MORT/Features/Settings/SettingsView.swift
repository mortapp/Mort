import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var confirmSignOut = false

    var body: some View {
        List {
            Section {
                Button { router.push(.profile) } label: { settingsRow("Profile", "person.crop.circle.fill", MortColors.neon) }
                Button { router.push(.avatar) } label: { settingsRow("Profile photo", "camera.fill", MortColors.safetyBlue) }
                Button { router.push(.username) } label: { settingsRow("Username", "at", MortColors.premium) }
                Button { router.push(.activity) } label: { settingsRow("Activity history", "clock.arrow.circlepath", MortColors.textSoft) }
                Button { router.push(.reviews) } label: { settingsRow("Reviews", "star.fill", MortColors.warning) }
            } header: { Text("Account") }

            Section {
                Button { router.push(.pilotEligibility) } label: { settingsRow("Closed-pilot access", "person.badge.shield.checkmark.fill", MortColors.neon) }
                Button { router.push(.partnerAffiliation) } label: { settingsRow("Partner affiliation", "building.2.crop.circle.fill", MortColors.safetyBlue) }
                if session.profile?.role == .teen || session.profile?.role == .guardian {
                    Button { router.push(.guardianMode) } label: { settingsRow("Guardian Mode", "person.2.badge.gearshape", MortColors.safetyBlue) }
                }
                Button { router.push(.safetyCenter) } label: { settingsRow("Safety Center", "shield.fill", MortColors.safetyBlue) }
                Button { router.push(.accountTrust) } label: { settingsRow("Verification and account trust", "checkmark.shield.fill", MortColors.neon) }
                Button { router.push(.deviceSecurity) } label: { settingsRow("Device security", "faceid", MortColors.safetyBlue) }
                Button { router.push(.biometricSettings) } label: { settingsRow("Face ID and app lock", "lock.iphone", MortColors.safetyBlue) }
                Button { router.push(.passkeys) } label: { settingsRow("Passkeys", "person.badge.key.fill", MortColors.textSoft) }
                if session.profile?.role == .admin {
                    Button { router.push(.trustAdmin) } label: { settingsRow("Trust review queues", "checklist.checked", MortColors.warning) }
                }
                Button { router.push(.safetyCircle) } label: { settingsRow("Safety Circle", "person.2.badge.gearshape", MortColors.safetyBlue) }
                Button { router.push(.incidentHistory) } label: { settingsRow("Safety cases", "case.fill", MortColors.warning) }
                Button { router.push(.activeSessions) } label: { settingsRow("Active sessions", "iphone.and.arrow.forward", MortColors.textSoft) }
                Button { router.push(.blockedUsers) } label: { settingsRow("Blocked accounts", "hand.raised.fill", MortColors.danger) }
                Button { router.push(.notifications) } label: { settingsRow("Notification center", "bell.fill", MortColors.warning) }
                Button { router.push(.pushSettings) } label: { settingsRow("Push permissions", "app.badge.fill", MortColors.warning) }
                Button { router.push(.discreetMode) } label: { settingsRow("Discreet Mode", "eye.slash.fill", MortColors.safetyBlue) }
                if session.profile?.role == .teen {
                    Button { router.push(.supportCircle) } label: { settingsRow("Optional Support Circle", "person.3.sequence.fill", MortColors.safetyBlue) }
                    Button { router.push(.pilotJobSafety) } label: { settingsRow("Pilot job safety", "briefcase.fill", MortColors.warning) }
                }
            } header: { Text("Safety and alerts") }

            Section {
                if session.profile?.role == .teen {
                    Button { router.push(.earningsGoals) } label: { settingsRow("Earnings and goals", "chart.line.uptrend.xyaxis", MortColors.neon) }
                    Button { router.push(.futureIndependence) } label: { settingsRow("Future Independence Plan", "road.lanes", MortColors.safetyBlue) }
                    Button { router.push(.resourceDirectory) } label: { settingsRow("Private resource directory", "book.closed.fill", MortColors.safetyBlue) }
                }
                Button { router.push(.paymentPreferences) } label: { settingsRow("Payment preference", "dollarsign.circle.fill", MortColors.neon) }
                Button { router.push(.jobContracts) } label: { settingsRow("Job agreements and payment", "doc.text.magnifyingglass", MortColors.neon) }
                Button { router.push(.monetization(nil)) } label: { settingsRow("Optional MORT perks", "sparkles", MortColors.premium) }
                Button { router.push(.customerCenter) } label: { settingsRow("Manage subscription", "person.crop.circle.badge.checkmark", MortColors.premium) }
                Button { router.push(.adPreferences) } label: { settingsRow("Ad preferences", "rectangle.badge.person.crop", MortColors.textSoft) }
                if session.profile?.role == .teen { Button { router.push(.savedJobs) } label: { settingsRow("Saved jobs", "bookmark.fill", MortColors.neon) } }
                if session.profile?.role == .adult { Button { router.push(.businessProfile) } label: { settingsRow("Adult / business profile", "building.2.fill", MortColors.safetyBlue) } }
                if session.profile?.role == .guardian { Button { router.push(.emergencyContact) } label: { settingsRow("Emergency contact", "phone.fill", MortColors.safetyBlue) } }
                if session.profile?.role == .teen { Button { router.push(.unavailable("Portfolio", "The shared Supabase backend does not yet contain portfolio tables or RPCs. MORT will not pretend a local-only portfolio is synced.")) } label: { settingsRow("Portfolio", "rectangle.stack.person.crop.fill", MortColors.textMuted) } }
                if session.profile?.role == .adult { Button { router.push(.unavailable("Adult analytics", "The shared backend does not yet expose a privacy-reviewed adult analytics contract.")) } label: { settingsRow("Adult analytics", "chart.bar.xaxis", MortColors.textMuted) } }
            } header: { Text("Preferences") }

            Section {
                Button { router.push(.verificationExplanation) } label: { settingsRow("What verification means", "text.badge.checkmark", MortColors.neon) }
                Button { router.push(.documentReviewStatus) } label: { settingsRow("Document review status", "doc.text.magnifyingglass", MortColors.warning) }
                Button { router.push(.support) } label: { settingsRow("Support", "lifepreserver.fill", MortColors.safetyBlue) }
                Button { router.push(.legalCenter) } label: { settingsRow("Legal center", "checkmark.seal.text.page", MortColors.warning) }
                Button { router.push(.legal(.privacy)) } label: { settingsRow("Privacy", "lock.shield.fill", MortColors.textSoft) }
                Button { router.push(.legal(.terms)) } label: { settingsRow("Terms", "doc.text.fill", MortColors.textSoft) }
                Button { router.push(.legal(.communityRules)) } label: { settingsRow("Community rules", "person.3.fill", MortColors.textSoft) }
                Button { router.push(.legal(.aiTransparency)) } label: { settingsRow("AI transparency", "sparkles.rectangle.stack", MortColors.textSoft) }
                Button { router.push(.documentCaptureQuality) } label: { settingsRow("Document capture readiness", "camera.metering.center.weighted", MortColors.warning) }
                Button { router.push(.livePresence) } label: { settingsRow("Live-presence limits", "person.crop.square.badge.video", MortColors.warning) }
                if session.profile?.role == .admin {
                    Button { router.push(.teamAccessReview) } label: { settingsRow("Team access review", "person.badge.key.fill", MortColors.danger) }
                }
                Button { router.push(.accountDeletion) } label: { settingsRow("Request account deletion", "trash.fill", MortColors.danger) }
            } header: { Text("Help and legal") }

            Section {
                Button(role: .destructive) { confirmSignOut = true } label: { settingsRow("Sign out", "rectangle.portrait.and.arrow.right", MortColors.danger) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MortColors.background)
        .navigationTitle("Settings")
        .confirmationDialog("Sign out of MORT?", isPresented: $confirmSignOut) {
            Button("Sign out", role: .destructive) { Task { await session.signOut() } }
            Button("Cancel", role: .cancel) {}
        }
        .mortScreen()
    }

    private func settingsRow(_ title: String, _ icon: String, _ tint: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 26)
            Text(title).foregroundStyle(MortColors.text)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(MortColors.textMuted)
        }
    }
}

struct PaymentPreferenceView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var preference = "none"
    @State private var cashAppTag = ""
    @State private var squareURL = ""
    @State private var note = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Payment preference", subtitle: "This is informational only and can be changed later.")
                Picker("Preference", selection: $preference) {
                    Text("Discuss in MORT").tag("none")
                    Text("Cash").tag("cash")
                    Text("Cash App").tag("cash_app")
                    Text("Square link").tag("square")
                    Text("Other").tag("other")
                }
                .pickerStyle(.menu)
                if preference == "cash_app" { MortTextField(title: "Cash App tag", text: $cashAppTag, prompt: "$cashtag") }
                if preference == "square" { MortTextField(title: "Square URL", text: $squareURL, prompt: "https://...") }
                MortTextField(title: "Note", text: $note, prompt: "Optional payment context", axis: .vertical)
                MortAlertBanner(title: "MORT does not process money", message: "No card vault, checkout, escrow, deposit, payout, or payment guarantee exists in this app.", tint: MortColors.warning, icon: "exclamationmark.triangle.fill")
                MortPrimaryButton(title: "Save preference", icon: "checkmark", isLoading: isWorking) { Task { await save() } }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .alert("MORT", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .onAppear { preference = session.profile?.paymentPreference ?? "none" }
        .mortScreen()
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        guard await container.biometricReauthentication.authorize(.changePaymentPreferences) else {
            message = "Device authentication did not succeed. Payment preferences were not changed."
            return
        }
        do {
            try await container.profiles.savePaymentPreference(preference: preference, cashAppTag: cashAppTag.nilIfBlank, squareURL: squareURL.nilIfBlank, note: note.nilIfBlank)
            await session.refreshProfile()
            message = "Payment preference saved."
        } catch { message = mortMessage(error) }
    }
}

struct PushSettingsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "iOS notification permission", subtitle: "MORT can request Apple notification permission and register this device with APNs.")
            MortCard {
                HStack {
                    Image(systemName: pushIcon).font(.title2).foregroundStyle(pushTint)
                    VStack(alignment: .leading) {
                        Text(pushTitle).font(MortTypography.label)
                        if let registrationError = container.push.registrationError {
                            Text(registrationError).font(MortTypography.caption).foregroundStyle(MortColors.warning)
                        }
                    }
                }
            }
            MortPrimaryButton(title: "Request notification permission", icon: "bell.badge.fill", isLoading: isWorking) { Task { await request() } }
            MortAlertBanner(
                title: "APNs backend work remains",
                message: "The current shared push_tokens table stores Expo tokens. This native app deliberately does not write an APNs token into that incompatible column. An additive APNs device-token contract and provider deployment are still required.",
                tint: MortColors.warning,
                icon: "server.rack"
            )
            Text("Native push delivery has not been tested on a physical iPhone.")
                .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            Spacer()
        }
        .padding(MortSpacing.lg)
        .navigationTitle("Push notifications")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await container.push.refreshAuthorizationState() }
        .mortScreen()
    }

    private var pushTitle: String {
        switch container.push.authorizationState {
        case .unknown: "Not requested"
        case .denied: "Permission denied"
        case .authorized: "Permission authorized"
        case .provisional: "Provisional permission"
        }
    }
    private var pushIcon: String { container.push.authorizationState == .authorized ? "checkmark.circle.fill" : "bell.slash.fill" }
    private var pushTint: Color { container.push.authorizationState == .authorized ? MortColors.neon : MortColors.warning }

    private func request() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let granted = try await container.push.requestPermission()
            message = granted ? "Notification permission granted. APNs registration was requested." : "Notification permission was not granted."
        } catch { message = mortMessage(error) }
    }
}

struct AccountDeletionRequestView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var confirmation = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "Request account deletion", subtitle: "The current backend does not expose a self-delete RPC. This creates a real, auditable support request for manual identity and retention review.")
            MortAlertBanner(title: "Manual review required", message: "Deleting an account can affect jobs, applications, safety records, reports, legal retention duties, and linked Guardian Mode data.", tint: MortColors.danger, icon: "exclamationmark.triangle.fill")
            MortTextField(title: "Type DELETE", text: $confirmation, prompt: "DELETE")
            MortDangerButton(title: isWorking ? "Submitting request..." : "Submit deletion request") { Task { await requestDeletion() } }
                .disabled(isWorking || confirmation != "DELETE")
            Spacer()
        }
        .padding(MortSpacing.lg)
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Account deletion", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func requestDeletion() async {
        isWorking = true
        defer { isWorking = false }
        guard await container.biometricReauthentication.authorize(.deleteAccount) else {
            message = "Device authentication did not succeed. The deletion request was not submitted."
            return
        }
        do {
            _ = try await container.support.createTicket(
                subject: "Account deletion request",
                message: "I am requesting deletion of my MORT account. Please verify the request and apply required retention, safety, and legal procedures."
            )
            confirmation = ""
            message = "Deletion request submitted to support. This did not instantly delete the account."
        } catch { message = mortMessage(error) }
    }
}
