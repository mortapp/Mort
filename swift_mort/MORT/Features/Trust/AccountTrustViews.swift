import SwiftUI

struct AccountTrustView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var state: LoadState<AccountTrustProfile> = .idle
    @State private var selectedIndicator: TrustIndicator?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(
                    title: "Verification and account trust",
                    subtitle: "MORT shows exactly what was checked. No single vague verified badge is used."
                )
                content
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Account trust")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selectedIndicator) { TrustExplanationSheet(indicator: $0) }
        .mortScreen()
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            MortLoadingState(label: "Loading account trust")
        case let .failed(error):
            MortErrorState(message: error) { Task { await load() } }
        case let .loaded(profile):
            TrustLevelCard(profile: profile)
            marketplaceCard(profile.marketplaceEligibility)
            indicatorSection(profile)
            trustActions(profile)
            MortAlertBanner(
                title: "Important limits",
                message: "Verification reduces some risks but cannot guarantee that someone is safe. MORT does not use people-search websites to expose residential information.",
                tint: MortColors.safetyBlue,
                icon: "shield.lefthalf.filled"
            )
            MortAlertBanner(
                title: "Guardian Mode is optional",
                message: "Guardian Mode remains separate from every trust level. Linking or skipping it does not change identity or affiliation status.",
                tint: MortColors.safetyBlue,
                icon: "person.2.fill"
            )
        }
    }

    private func marketplaceCard(_ eligibility: MarketplaceTrustEligibility) -> some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack {
                    Text("Marketplace eligibility").font(MortTypography.section)
                    Spacer()
                    MortBadge(
                        text: eligibility.allowed ? "Allowed" : "Closed",
                        tint: eligibility.allowed ? MortColors.neon : MortColors.warning
                    )
                }
                Text("Required level \(eligibility.requiredLevel) | Current level \(eligibility.currentLevel)")
                    .font(MortTypography.caption)
                    .foregroundStyle(MortColors.textMuted)
                if !eligibility.reasonCodes.isEmpty {
                    Text(eligibility.reasonCodes.map(humanize).joined(separator: " | "))
                        .font(MortTypography.caption)
                        .foregroundStyle(MortColors.warning)
                }
                if eligibility.productionMarketplaceEnabled == false {
                    Text("The public marketplace is closed while approved production verification is unavailable.")
                        .font(MortTypography.caption)
                }
            }
        }
    }

    private func indicatorSection(_ profile: AccountTrustProfile) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(
                title: "Precise trust indicators",
                subtitle: "Tap an indicator to see what was and was not checked."
            )
            if profile.indicators.isEmpty {
                MortAlertBanner(
                    title: "No completed indicators yet",
                    message: "Complete only the checks available to your account. Unavailable checks fail closed."
                )
            } else {
                ForEach(profile.indicators) { indicator in
                    Button { selectedIndicator = indicator } label: {
                        MortCard {
                            HStack(alignment: .top) {
                                Image(systemName: indicatorIcon(indicator.category))
                                    .foregroundStyle(indicator.status == "verified" ? MortColors.neon : MortColors.warning)
                                VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                                    Text(indicator.label).font(MortTypography.label)
                                    Text(humanize(indicator.status)).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                }
                                Spacer()
                                Image(systemName: "info.circle").foregroundStyle(MortColors.textMuted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func trustActions(_ profile: AccountTrustProfile) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            MortSectionHeader(title: "Available checks", subtitle: "Unavailable methods stay visibly disabled.")
            MortSecondaryButton(title: "Device security", icon: "faceid") { router.push(.deviceSecurity) }
            MortSecondaryButton(title: "Passkeys", icon: "person.badge.key.fill") { router.push(.passkeys) }
            if session.profile?.role == .teen {
                MortSecondaryButton(title: "School email affiliation", icon: "graduationcap.fill") { router.push(.schoolAffiliation) }
                MortSecondaryButton(title: "Partner or program code", icon: "number.square.fill") { router.push(.partnerCode) }
            }
            if session.profile?.role == .adult {
                MortSecondaryButton(title: "Business registry match", icon: "building.2.fill") { router.push(.businessRegistry) }
            }
            MortSecondaryButton(title: "Government digital ID availability", icon: "wallet.pass.fill") { router.push(.digitalID) }
            MortSecondaryButton(title: "Verification status", icon: "person.badge.shield.checkmark") { router.push(.verification) }
            MortSecondaryButton(title: "Appeal or request support", icon: "arrow.triangle.2.circlepath") { router.push(.trustAppeal) }
            if !profile.availability.identityDocumentCollectionEnabled {
                VerificationUnavailableView(
                    title: "Identity-document collection disabled",
                    reason: "Do not upload a school ID, government ID, passport, selfie, or address document. MORT has no approved production intake workflow."
                )
            }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.accountTrust.profile()) }
        catch { state = .failed(mortMessage(error)) }
    }

    private func humanize(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func indicatorIcon(_ category: String) -> String {
        switch category {
        case "account_security": "lock.shield.fill"
        case "contact": "envelope.badge.shield.half.filled"
        case "affiliation": "building.columns.fill"
        case "business_registry": "building.2.crop.circle.fill"
        case "digital_identity": "wallet.pass.fill"
        case "provider_identity": "person.text.rectangle.fill"
        case "adult_screening": "checkmark.shield.fill"
        default: "exclamationmark.shield.fill"
        }
    }
}

struct TrustLevelCard: View {
    let profile: AccountTrustProfile

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                        Text(profile.levelKey).font(MortTypography.caption).foregroundStyle(MortColors.neon)
                        Text(profile.levelTitle).font(MortTypography.title)
                    }
                    Spacer()
                    Text(String(profile.currentLevel))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(MortColors.neon)
                }
                Text("This is a transparent category level, not a numerical safety score.")
                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                Text("Environment: \(profile.signalEnvironment == "sandbox" ? "TEST MODE" : "production") | Policy v\(profile.policyVersion)")
                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            }
        }
    }
}

struct TrustExplanationSheet: View {
    let indicator: TrustIndicator

    var body: some View {
        MortBottomSheet(title: indicator.label) {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortBadge(text: indicator.status, tint: indicator.status == "verified" ? MortColors.neon : MortColors.warning)
                MortSectionHeader(title: "What was checked", subtitle: indicator.whatWasChecked)
                MortSectionHeader(title: "What was not checked", subtitle: indicator.whatWasNotChecked)
                if let checkedAt = indicator.checkedAt {
                    Text("Checked: \(DateFormatting.displayDateTime(checkedAt))")
                        .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
                if let expiresAt = indicator.expiresAt {
                    Text("Expires: \(DateFormatting.displayDateTime(expiresAt))")
                        .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
                Text(indicator.grantsMarketplaceAccess ? "This indicator contributes to current marketplace access." : "This indicator does not grant marketplace access by itself.")
                    .font(MortTypography.caption)
                MortSafetyBanner(message: "This check does not guarantee safety, behavior, intent, or work quality.")
            }
        }
    }
}

struct DeviceSecuritySettingsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var enabled = false
    @State private var lockMinutes = 15
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(
                    title: "Device security",
                    subtitle: "\(container.biometricReauthentication.capability().title) can protect sensitive actions on this device."
                )
                MortAlertBanner(
                    title: "Account security only",
                    message: "Device biometrics protect your account on this device. They do not verify your legal identity.",
                    tint: MortColors.safetyBlue,
                    icon: "faceid"
                )
                Toggle("Require device authentication", isOn: $enabled)
                Stepper("Lock after \(lockMinutes) minutes", value: $lockMinutes, in: 1 ... 240)
                MortPrimaryButton(title: "Save device security", icon: "lock.shield.fill", isLoading: isWorking) {
                    Task { await save() }
                }
                SensitiveActionGate(action: .highRiskAccountAction, title: "Test device authentication") {
                    message = "Device authentication succeeded for this one test action. No identity status changed."
                }
                MortAlertBanner(
                    title: "Nothing biometric is uploaded",
                    message: "MORT receives only a local success, failure, cancellation, lockout, or unavailable result. Face or fingerprint templates stay with iOS.",
                    tint: MortColors.neon,
                    icon: "iphone.gen3.radiowaves.left.and.right"
                )
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Device security")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Device security", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        guard let profile = try? await container.accountTrust.profile() else { return }
        enabled = profile.indicators.contains { $0.key == "device_reauthentication" && $0.status == "configured" }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.accountTrust.updateDeviceSecurity(enabled: enabled, lockAfterMinutes: lockMinutes)
            message = enabled
                ? "Device authentication protection is configured. This did not verify identity."
                : "Device authentication protection is off."
        } catch { message = mortMessage(error) }
    }
}

struct SensitiveActionGate: View {
    @Environment(DependencyContainer.self) private var container
    let action: SensitiveAction
    let title: String
    let onAuthorized: () -> Void
    @State private var isWorking = false
    @State private var failureMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.xs) {
            MortSecondaryButton(title: isWorking ? "Authenticating..." : title, icon: "faceid", isDisabled: isWorking) {
                Task { await authenticate() }
            }
            if let failureMessage {
                Text(failureMessage).font(MortTypography.caption).foregroundStyle(MortColors.warning)
            }
        }
    }

    private func authenticate() async {
        isWorking = true
        defer { isWorking = false }
        guard await container.biometricReauthentication.authorize(action),
              container.biometricReauthentication.consumeAuthorization(for: action) else {
            failureMessage = "Authentication did not succeed. The sensitive action remains blocked."
            return
        }
        failureMessage = nil
        onAuthorized()
    }
}

struct PasskeySettingsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var profile: AccountTrustProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Passkeys", subtitle: "Phishing-resistant account authentication, separate from legal identity.")
                if let profile {
                    MortCard {
                        Text("Registered passkeys: \(profile.accountSecurity.passkeyCount)").font(MortTypography.section)
                        Text("Hosted server flag: \(profile.accountSecurity.passkeysEnabledByServer ? "enabled" : "disabled")")
                            .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    }
                }
                VerificationUnavailableView(
                    title: "Passkey registration is disabled",
                    reason: "Supabase Auth passkeys are experimental and the hosted project has no enabled relying-party configuration. MORT will not start or fake a WebAuthn ceremony."
                )
                Text("A passkey proves control of an account credential. It does not prove legal name, age, address, school, or safety.")
                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Passkeys")
        .navigationBarTitleDisplayMode(.inline)
        .task { profile = try? await container.accountTrust.profile() }
        .mortScreen()
    }
}

struct SchoolEmailVerificationView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "School email affiliation", subtitle: "Uses the already-confirmed email on this MORT account.")
            MortTextField(title: "Confirmed account email", text: $email, prompt: "student@school.edu")
            MortAlertBanner(
                title: "Affiliation, not identity",
                message: "School affiliation verification confirms access to an approved school or program account. It does not equal government ID verification.",
                tint: MortColors.safetyBlue,
                icon: "graduationcap.fill"
            )
            MortPrimaryButton(title: "Check approved domain", icon: "envelope.badge.fill", isLoading: isWorking, isDisabled: email.nilIfBlank == nil) {
                Task { await submit() }
            }
            Text("School name stays private by default. MORT does not provide school-based public search or school-targeted advertising.")
                .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            Spacer()
        }
        .padding(MortSpacing.lg)
        .navigationTitle("School affiliation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { email = session.email ?? "" }
        .alert("School affiliation", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await container.accountTrust.requestSchoolAffiliation(email: email)
            message = result.message ?? (result.affiliationVerified == true ? "School affiliation verified." : "The domain is pending review.")
        } catch { message = mortMessage(error) }
    }
}

struct PartnerCodeVerificationView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var code = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "Partner or program code", subtitle: "Codes come only from MORT-approved schools, counselors, or youth programs.")
            MortTextField(title: "Invitation code", text: $code, prompt: "MORT-...")
            MortPrimaryButton(title: "Redeem code", icon: "number.square.fill", isLoading: isWorking, isDisabled: code.trimmed.count < 12) {
                Task { await redeem() }
            }
            MortAlertBanner(
                title: "Private affiliation",
                message: "Codes are limited-use, expire, and are stored only as hashes. A partner cannot browse unrelated teens or unrestricted activity.",
                tint: MortColors.safetyBlue,
                icon: "lock.shield.fill"
            )
            Text("Partner affiliation does not verify legal identity or guarantee safety.")
                .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            Spacer()
        }
        .padding(MortSpacing.lg)
        .navigationTitle("Partner code")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Partner code", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func redeem() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await container.accountTrust.redeemPartnerCode(code)
            code = ""
            message = result.message ?? "Program affiliation recorded. No identity verification was granted."
        } catch { message = mortMessage(error) }
    }
}

struct BusinessRegistryMatchView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var legalName = ""
    @State private var registrationNumber = ""
    @State private var entityType = ""
    @State private var sourceURL = "https://bsd.sos.in.gov/PublicBusinessSearch/Index"
    @State private var checkID: UUID?
    @State private var relationship = "owner"
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Business registry match", subtitle: "Manual review against an allowlisted official government source.")
                MortTextField(title: "Legal business name", text: $legalName, prompt: "Name on official record")
                MortTextField(title: "Indiana registration number", text: $registrationNumber, prompt: "Business ID or filing number")
                MortTextField(title: "Entity type", text: $entityType, prompt: "Optional")
                MortTextField(title: "Official source URL", text: $sourceURL, prompt: "https://bsd.sos.in.gov/...")
                MortPrimaryButton(title: "Request manual registry review", icon: "building.2.fill", isLoading: isWorking, isDisabled: legalName.trimmed.count < 2 || registrationNumber.trimmed.count < 2) {
                    Task { await submit() }
                }
                if let checkID {
                    Picker("Relationship", selection: $relationship) {
                        Text("Owner").tag("owner")
                        Text("Officer").tag("officer")
                        Text("Employee").tag("employee")
                        Text("Authorized agent").tag("authorized_agent")
                    }
                    MortSecondaryButton(title: "Record representative claim", icon: "person.crop.circle.badge.questionmark") {
                        Task { await claim(checkID) }
                    }
                }
                MortAlertBanner(
                    title: "Registry match has a hard limit",
                    message: "Business registration matching confirms that a public business record exists. It does not prove the account holder owns the business.",
                    tint: MortColors.warning,
                    icon: "building.2.crop.circle"
                )
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Business registry")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Business registry", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await container.accountTrust.requestBusinessRegistryMatch(
                jurisdiction: "US-IN",
                legalName: legalName,
                registrationNumber: registrationNumber,
                entityType: entityType,
                sourceURL: sourceURL
            )
            checkID = result.checkID
            message = result.message ?? "Registry request queued for manual review."
        } catch { message = mortMessage(error) }
    }

    private func claim(_ id: UUID) async {
        do {
            let result = try await container.accountTrust.requestBusinessRepresentativeClaim(checkID: id, relationship: relationship)
            message = result.message ?? "Representative claim recorded but not verified."
        } catch { message = mortMessage(error) }
    }
}

struct DigitalIDAvailabilityView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var profile: AccountTrustProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Government digital ID", subtitle: "Future cryptographically validated credential providers.")
                availabilityCard(
                    title: "Apple Verify with Wallet",
                    enabled: profile?.availability.appleWalletEnabled == true && container.walletIdentity.isAvailable,
                    message: "Requires Apple Developer membership, the in-app identity presentment entitlement, a supported jurisdiction, minimal attribute consent, and backend cryptographic validation."
                )
                availabilityCard(
                    title: "Android Digital Credentials",
                    enabled: profile?.availability.androidDigitalCredentialsEnabled == true,
                    message: "Not available in this iOS app. The Android Credential Manager verifier path also requires issuer, nonce, replay, validity, and account-binding checks on the server."
                )
                MortAlertBanner(
                    title: "No screenshot or local-only approval",
                    message: "MORT will not treat a screenshot, barcode read, MRZ read, or locally parsed document as an authentic government credential.",
                    tint: MortColors.warning,
                    icon: "doc.viewfinder"
                )
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Digital ID")
        .navigationBarTitleDisplayMode(.inline)
        .task { profile = try? await container.accountTrust.profile() }
        .mortScreen()
    }

    private func availabilityCard(title: String, enabled: Bool, message: String) -> some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack { Text(title).font(MortTypography.section); Spacer(); MortBadge(text: enabled ? "Available" : "Disabled", tint: enabled ? MortColors.neon : MortColors.warning) }
                Text(message).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            }
        }
    }
}

struct VerificationUnavailableView: View {
    let title: String
    let reason: String

    var body: some View {
        MortAlertBanner(title: title, message: reason, tint: MortColors.warning, icon: "lock.shield.fill")
    }
}

struct VerificationAppealView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var reason = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "Account trust appeal", subtitle: "Appeals are reviewed by a restricted role and never auto-approve trust.")
            MortTextField(title: "What should be reconsidered?", text: $reason, prompt: "Include at least 20 characters", axis: .vertical)
            MortPrimaryButton(title: "Submit appeal", icon: "arrow.triangle.2.circlepath", isLoading: isWorking, isDisabled: reason.trimmed.count < 20) {
                Task { await submit() }
            }
            MortSecondaryButton(title: "Open support", icon: "lifepreserver.fill") { router.push(.support) }
            MortSafetyBanner(message: "Submitting an appeal does not restore marketplace access or change a trust indicator automatically.")
            Spacer()
        }
        .padding(MortSpacing.lg)
        .navigationTitle("Trust appeal")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Trust appeal", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.accountTrust.submitAppeal(reason: reason, signalID: nil)
            reason = ""
            message = "Appeal submitted. No trust level or marketplace permission changed automatically."
        } catch { message = mortMessage(error) }
    }
}

struct SessionManagementView: View {
    var body: some View { AccountSessionsView() }
}

struct TrustAdminReviewView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var queue = "school_domains"
    @State private var accessReason = ""
    @State private var caseID = ""
    @State private var state: LoadState<[[String: JSONValue]]> = .idle

    private let queues = [
        "school_domains", "partner_organizations", "partner_codes",
        "business_registry", "business_representatives", "verification_appeals",
        "risk_signals", "account_security", "provider_events",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Restricted trust review", subtitle: "Least-privilege role, access reason, case ID, timestamp, and actor are enforced by the backend.")
                Picker("Queue", selection: $queue) {
                    ForEach(queues, id: \.self) { Text(humanize($0)).tag($0) }
                }
                .pickerStyle(.menu)
                MortTextField(title: "Access reason", text: $accessReason, prompt: "Why this queue access is necessary")
                MortTextField(title: "Case ID", text: $caseID, prompt: "Required audit reference")
                MortPrimaryButton(title: "Open audited queue", icon: "checklist.checked", isDisabled: accessReason.trimmed.count < 12 || caseID.trimmed.count < 4) {
                    Task { await load() }
                }
                queueContent
                MortAlertBanner(
                    title: "Raw identity evidence excluded",
                    message: "Support agents cannot access raw identity evidence. This view contains only the minimum queue metadata returned for the assigned role.",
                    tint: MortColors.safetyBlue,
                    icon: "eye.slash.fill"
                )
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Trust review")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }

    @ViewBuilder
    private var queueContent: some View {
        switch state {
        case .idle: EmptyView()
        case .loading: MortLoadingState(label: "Opening audited queue")
        case let .failed(error): MortErrorState(message: error) { Task { await load() } }
        case let .loaded(items) where items.isEmpty:
            MortEmptyState(title: "Queue is clear", message: "No records are visible for this role and queue.", systemImage: "checkmark.circle")
        case let .loaded(items):
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        ForEach(item.keys.sorted(), id: \.self) { key in
                            HStack(alignment: .top) {
                                Text(humanize(key)).font(MortTypography.caption).foregroundStyle(MortColors.textMuted).frame(width: 110, alignment: .leading)
                                Text(item[key]?.displayValue ?? "-").font(MortTypography.caption).textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            let response = try await container.accountTrust.adminQueue(queue, accessReason: accessReason, caseID: caseID)
            guard response.rawIdentityEvidenceIncluded != true else { throw MortError.invalidResponse }
            state = .loaded(response.items ?? [])
        } catch { state = .failed(mortMessage(error)) }
    }

    private func humanize(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
