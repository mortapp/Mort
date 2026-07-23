import SwiftUI

struct PilotEligibilityView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var dashboard: MissionPilotDashboard?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(
                    title: "Closed-pilot access",
                    subtitle: "MORT is limited to approved organization-supported participants. The server decides eligibility for every protected marketplace action."
                )
                if let dashboard {
                    MortAlertBanner(
                        title: dashboard.pilotEligibility.allowed ? "Pilot access active" : "Pilot requirements remain",
                        message: dashboard.pilotEligibility.allowed
                            ? "Your current account meets the hosted closed-pilot access rules. Job-specific safety review still applies."
                            : eligibilitySummary(dashboard.pilotEligibility),
                        tint: dashboard.pilotEligibility.allowed ? MortColors.neon : MortColors.warning,
                        icon: dashboard.pilotEligibility.allowed ? "checkmark.shield.fill" : "lock.shield.fill"
                    )
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            Text(dashboard.mission).font(MortTypography.section)
                            truthRow("Guardian Mode", "Optional")
                            truthRow("Permanent address", "Not required for teens")
                            truthRow("Public marketplace", "Closed")
                            truthRow("Real document collection", "Disabled")
                            truthRow("MORT payment custody", "None")
                        }
                    }
                    if let missing = dashboard.pilotEligibility.missingRequirements, !missing.isEmpty {
                        MortSectionHeader(title: "Server-reported requirements")
                        ForEach(missing, id: \.self) { requirement in
                            Label(readable(requirement), systemImage: "circle.dashed")
                                .font(MortTypography.caption)
                                .foregroundStyle(MortColors.textMuted)
                        }
                    }
                    MortPrimaryButton(title: "Use a partner invitation", icon: "ticket.fill") {
                        router.push(.partnerInvitation)
                    }
                    MortSecondaryButton(title: "Review partner attestations", icon: "building.2.fill") {
                        router.push(.partnerAffiliation)
                    }
                    if session.profile?.role == .teen {
                        MortSecondaryButton(title: "Acknowledge teen pilot rules", icon: "checkmark.circle") {
                            Task { await acknowledgeTeenRules() }
                        }
                    }
                } else if let errorMessage {
                    MortErrorState(message: errorMessage) { Task { await load() } }
                } else {
                    MortLoadingState(label: "Checking hosted pilot access")
                        .frame(minHeight: 260)
                }
                if let statusMessage {
                    MortAlertBanner(title: "Pilot access", message: statusMessage, tint: MortColors.safetyBlue, icon: "info.circle.fill")
                }
                MortSafetyBanner(message: "Organization approval is one trust signal. It does not prove government identity and is never a safety guarantee.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Pilot access")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        errorMessage = nil
        do { dashboard = try await container.missionPilot.dashboard() }
        catch { errorMessage = mortMessage(error) }
    }

    private func acknowledgeTeenRules() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            for item in ["teen_safety_training", "pilot_rules", "explicit_consent"] {
                _ = try await container.missionPilot.acknowledge(item)
            }
            statusMessage = "Current teen safety, pilot rules, and consent acknowledgements were saved. Partner enrollment and all other server requirements still apply."
            await load()
        } catch { statusMessage = mortMessage(error) }
    }

    private func eligibilitySummary(_ eligibility: ClosedPilotEligibility) -> String {
        let count = eligibility.missingRequirements?.count ?? 0
        return count == 0
            ? "The hosted backend has not granted closed-pilot access for this account."
            : "The hosted backend reports \(count) remaining requirement\(count == 1 ? "" : "s")."
    }

    private func truthRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(MortColors.textMuted) }
            .font(MortTypography.caption)
    }
}

struct PartnerInvitationView: View {
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Partner invitation", subtitle: "The pilot accepts only approved, expiring organization routes. Random public adult enrollment is closed.")
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        pilotSource("Approved partner code", "Codes are hashed on the server, limited-use, expiring, and revocable.")
                        pilotSource("Verified partner email", "The organization relationship must already be approved.")
                        pilotSource("Partner staff attestation", "Staff may attest only to facts they are authorized to establish.")
                        pilotSource("Manual pilot enrollment", "An authorized reviewer records the decision and reason.")
                    }
                }
                MortPrimaryButton(title: "Enter approved partner code", icon: "number.square.fill") {
                    router.push(.partnerCode)
                }
                MortAlertBanner(
                    title: "No government identity claim",
                    message: "A school, program, shelter, or community partner relationship does not establish government identity. MORT keeps those labels separate.",
                    tint: MortColors.warning,
                    icon: "exclamationmark.triangle.fill"
                )
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Partner invitation")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }

    private func pilotSource(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: MortSpacing.xxs) {
            Label(title, systemImage: "checkmark.circle.fill").font(MortTypography.label)
            Text(detail).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
        }
    }
}

struct PartnerAffiliationView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var response: PartnerAttestationsResponse?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Partner affiliation", subtitle: "You can see the exact fact, wording, version, and limit of every partner attestation connected to you.")
                if let response {
                    if response.attestations.isEmpty {
                        MortEmptyState(title: "No partner attestations", message: "No approved partner fact has been recorded for this account.", systemImage: "building.2.crop.circle")
                    } else {
                        ForEach(response.attestations) { attestation in
                            MortCard {
                                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                                    MortBadge(text: readable(attestation.factType), tint: attestation.status == "active" ? MortColors.neon : MortColors.warning)
                                    Text(attestation.statement).font(MortTypography.label)
                                    Text("Does not establish: \(attestation.whatWasNotEstablished)")
                                        .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                    Text("Version \(attestation.version) | \(readable(attestation.status))")
                                        .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                }
                            }
                        }
                    }
                    MortAlertBanner(
                        title: "Identity wording",
                        message: response.governmentIDVerified
                            ? "An authoritative government identity signal is recorded separately."
                            : "Partner affiliation does not grant a government identity badge.",
                        tint: response.governmentIDVerified ? MortColors.neon : MortColors.safetyBlue,
                        icon: "text.badge.checkmark"
                    )
                } else if let errorMessage {
                    MortErrorState(message: errorMessage) { Task { await load() } }
                } else {
                    MortLoadingState(label: "Loading private attestations").frame(minHeight: 260)
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Partner affiliation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        errorMessage = nil
        do { response = try await container.missionPilot.partnerAttestations() }
        catch { errorMessage = mortMessage(error) }
    }
}

struct DiscreetModeSettingsView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var enabled = false
    @State private var appLock = false
    @State private var lockMinutes = 5
    @State private var quickExit = "home"
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("Private notifications") {
                Toggle("Enable Discreet Mode", isOn: $enabled)
                LabeledContent("Notification title", value: "MORT notification")
                LabeledContent("Notification body", value: "Hidden until opened")
                Text("Job addresses and vulnerability labels are never placed in Discreet Mode notification content.")
                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            }
            Section("App access") {
                Toggle("Require device authentication", isOn: $appLock)
                Stepper("Automatic lock: \(lockMinutes) minutes", value: $lockMinutes, in: 1...60)
                Picker("Quick-exit destination", selection: $quickExit) {
                    Text("Home").tag("home")
                    Text("Job feed").tag("job_feed")
                    Text("Sign in").tag("sign_in")
                }
                Button("Review Face ID / passcode settings") { router.push(.deviceSecurity) }
            }
            Section {
                MortPrimaryButton(title: "Save Discreet Mode", icon: "eye.slash.fill", isLoading: isWorking) {
                    Task { await save() }
                }
                MortSecondaryButton(title: "Quick exit now", icon: "rectangle.portrait.and.arrow.forward") {
                    router.reset()
                }
            } footer: {
                Text("Discreet Mode protects privacy in unstable or unsafe living situations. It does not disguise illegal activity. Device authentication availability is checked by iOS.")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Discreet Mode")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Discreet Mode", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func load() async {
        do {
            let state = (try await container.missionPilot.dashboard()).discreetMode
            enabled = state.enabled
            appLock = state.appLockEnabled ?? false
            lockMinutes = state.automaticLockMinutes ?? 5
            quickExit = state.quickExitDestination ?? "home"
        } catch { message = mortMessage(error) }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.missionPilot.updateDiscreetMode(enabled: enabled, appLock: appLock, lockMinutes: lockMinutes, quickExit: quickExit)
            message = "Discreet Mode preferences were saved to the hosted backend."
        } catch { message = mortMessage(error) }
    }
}

struct SupportCircleView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var state: SupportCircleState?
    @State private var enabled = false
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Optional Support Circle", subtitle: "The teen chooses routine sharing. Support Circle participation never affects profile completion or independent pilot eligibility.")
                MortAlertBanner(title: "Guardian Mode stays optional", message: "A parent-linked account and approval for every job are not required by MORT's ordinary teen marketplace rules.", tint: MortColors.safetyBlue, icon: "person.3.fill")
                if let state {
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            Toggle("Enable Support Circle", isOn: $enabled)
                            LabeledContent("Active members", value: "\(state.memberCount)")
                            LabeledContent("Affects eligibility", value: state.affectsEligibility ? "Yes" : "No")
                        }
                    }
                    MortPrimaryButton(title: "Save Support Circle", icon: "checkmark", isLoading: isWorking) { Task { await save() } }
                    MortSecondaryButton(title: "Manage granted safety contacts", icon: "person.crop.circle.badge.gearshape") { router.push(.safetyCircle) }
                } else {
                    MortLoadingState(label: "Loading Support Circle").frame(minHeight: 220)
                }
                MortSafetyBanner(message: "Members receive only alerts the teen grants. They cannot read unrestricted messages, control earnings, impersonate the teen, or access identity documents.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Support Circle")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Support Circle", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func load() async {
        do {
            let loaded = (try await container.missionPilot.dashboard()).supportCircle
            state = loaded
            enabled = loaded.enabled
        } catch { message = mortMessage(error) }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.missionPilot.configureSupportCircle(enabled: enabled)
            message = enabled ? "Support Circle enabled. Member permissions remain individually scoped." : "Support Circle disabled. This does not affect marketplace eligibility."
            await load()
        } catch { message = mortMessage(error) }
    }
}

struct EarningsGoalsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var goals: [IndependenceGoal] = []
    @State private var summary: PrivateWorkSummary?
    @State private var goalType = "emergency_savings"
    @State private var title = ""
    @State private var targetDollars = ""
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Earnings and private goals", subtitle: "Build work history and plan what your income can support. Goals are private by default.")
                if let summary {
                    MortCard {
                        HStack {
                            metric(summary.totalSelfRecordedEarningsCents.formattedCurrency, "Self-recorded")
                            metric("\(summary.completedJobCount)", "Completed jobs")
                            metric("\(summary.referenceCount)", "References")
                        }
                    }
                }
                MortAlertBanner(title: "Payment preference only", message: "MORT does not hold, escrow, guarantee, process, or take custody of job payments.", tint: MortColors.warning, icon: "dollarsign.triangle")
                MortSectionHeader(title: "Add a goal")
                Picker("Goal type", selection: $goalType) {
                    ForEach(goalTypes, id: \.self) { type in Text(readable(type)).tag(type) }
                }.pickerStyle(.menu)
                MortTextField(title: "Goal name", text: $title, prompt: "Emergency savings")
                MortTextField(title: "Target dollars", text: $targetDollars, prompt: "100", keyboardType: .decimalPad)
                MortPrimaryButton(title: "Create private goal", icon: "plus.circle.fill", isLoading: isWorking, isDisabled: title.trimmed.count < 2) { Task { await create() } }
                MortSectionHeader(title: "Your goals")
                if isLoading {
                    ProgressView().tint(MortColors.neon)
                } else if goals.isEmpty {
                    MortEmptyState(title: "No goals yet", message: "Create a private earnings or savings target when it is useful to you.", systemImage: "target")
                } else {
                    ForEach(goals) { goal in
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpacing.xs) {
                                HStack { Text(goal.title).font(MortTypography.label); Spacer(); MortBadge(text: readable(goal.status)) }
                                Text(readable(goal.goalType)).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                if let target = goal.targetAmountCents {
                                    ProgressView(value: Double(goal.currentAmountCents), total: Double(max(target, 1))).tint(MortColors.neon)
                                    Text("\(goal.currentAmountCents.formattedCurrency) of \(target.formattedCurrency)").font(MortTypography.caption)
                                }
                            }
                        }
                    }
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Earnings and goals")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Goals", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private let goalTypes = ["weekly_earnings", "emergency_savings", "future_housing", "transportation", "school_supplies", "family_support", "work_equipment", "custom"]

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedGoals = container.missionPilot.goals()
            async let loadedSummary = container.missionPilot.privateWorkSummary()
            (goals, summary) = try await (loadedGoals, loadedSummary)
        } catch { message = mortMessage(error) }
    }

    private func create() async {
        isWorking = true
        defer { isWorking = false }
        let cents = Double(targetDollars).map { Int(($0 * 100).rounded()) }
        do {
            try await container.missionPilot.createGoal(type: goalType, title: title, targetCents: cents)
            title = ""
            targetDollars = ""
            await load()
        } catch { message = mortMessage(error) }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading) { Text(value).font(MortTypography.section); Text(label).font(MortTypography.caption).foregroundStyle(MortColors.textMuted) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FutureIndependencePlanView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var hasTargetDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var education = ""
    @State private var employment = ""
    @State private var transportation = ""
    @State private var savingsDollars = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Future Independence Plan", subtitle: "Prepare lawfully for adulthood with savings, education, work, transportation, references, and trusted support.")
                MortAlertBanner(title: "Preparation, not runaway guidance", message: "MORT does not provide instructions for minors to evade lawful protections or secretly run away. For immediate danger, contact emergency services or a qualified crisis resource.", tint: MortColors.warning, icon: "hand.raised.fill")
                Toggle("Set a target date", isOn: $hasTargetDate).tint(MortColors.neon)
                if hasTargetDate { DatePicker("Target date", selection: $targetDate, displayedComponents: .date) }
                MortTextField(title: "Education plan", text: $education, prompt: "School, training, certification", axis: .vertical)
                MortTextField(title: "Employment plan", text: $employment, prompt: "Experience, resume, references", axis: .vertical)
                MortTextField(title: "Transportation plan", text: $transportation, prompt: "Safe, lawful transportation options", axis: .vertical)
                MortTextField(title: "Savings target", text: $savingsDollars, prompt: "500", keyboardType: .decimalPad)
                MortPrimaryButton(title: "Save private plan", icon: "lock.fill", isLoading: isWorking) { Task { await save() } }
                MortSecondaryButton(title: "Open resource directory", icon: "book.closed.fill") { router.push(.resourceDirectory) }
                MortSafetyBanner(message: "MORT does not replace emergency services, legal counsel, social workers, housing professionals, or qualified child-safety support.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Future Independence")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Future Independence", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        let cents = Double(savingsDollars).map { Int(($0 * 100).rounded()) }
        do {
            try await container.missionPilot.saveFuturePlan(
                targetDate: hasTargetDate ? targetDate : nil,
                education: education,
                employment: employment,
                transportation: transportation,
                savingsTargetCents: cents
            )
            message = "Your private adulthood-preparation plan was saved."
        } catch { message = mortMessage(error) }
    }
}

struct ResourceDirectoryView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var resources: [ResourceDirectoryEntry] = []
    @State private var isLoading = true
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Private resource directory", subtitle: "Official or reviewed sources only. Saving a resource is private and never appears on your public profile or marketplace ranking.")
                MortSafetyBanner(message: "Listings do not promise current availability. Confirm services directly. For immediate danger, use local emergency services.")
                if isLoading {
                    MortLoadingState(label: "Loading reviewed resources").frame(minHeight: 240)
                } else if resources.isEmpty {
                    MortEmptyState(title: "No reviewed resources yet", message: "MORT will not invent organizations or availability claims.", systemImage: "book.closed")
                } else {
                    ForEach(resources) { resource in
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                                HStack { MortBadge(text: readable(resource.category)); Spacer(); MortBadge(text: readable(resource.sourceStatus), tint: MortColors.neon) }
                                Text(resource.organizationName).font(MortTypography.section)
                                Text(resource.summary).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                Text(resource.emergencyLimitations).font(MortTypography.caption).foregroundStyle(MortColors.warning)
                                HStack {
                                    if let url = URL(string: resource.sourceURL) {
                                        Link("Open official source", destination: url)
                                    }
                                    Spacer()
                                    Button("Save privately") { Task { await bookmark(resource.id) } }
                                }.font(MortTypography.caption)
                            }
                        }
                    }
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Resources", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .mortScreen()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { resources = try await container.missionPilot.resources() }
        catch { message = mortMessage(error) }
    }

    private func bookmark(_ id: UUID) async {
        do {
            try await container.missionPilot.bookmarkResource(id)
            message = "Saved privately. Resource use is not public."
        } catch { message = mortMessage(error) }
    }
}

struct PilotJobSafetyView: View {
    private let allowed = ["Verified businesses", "Schools and nonprofits", "Staffed community projects", "Public events", "Visible outdoor community spaces"]
    private let blocked = ["Unknown residences or isolated properties", "Hotels, bedrooms, or overnight work", "Poster-provided transportation", "Weapons, alcohol, drugs, dangerous heights, roofing, chemicals, or high-risk machinery", "Secrecy, adult services, or unreviewable risk"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Pilot job safety", subtitle: "The hosted backend owns the final pilot-job decision. A hidden button is never the safety boundary.")
                safetyList("Initially allowed settings", allowed, "checkmark.shield.fill", MortColors.neon)
                safetyList("Blocked during the pilot", blocked, "xmark.shield.fill", MortColors.danger)
                MortSafetyBanner(message: "A safety cancellation does not automatically damage a teen's reputation. Report, block, and Safety Ping remain free.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Pilot job safety")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }

    private func safetyList(_ title: String, _ values: [String], _ icon: String, _ tint: Color) -> some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                Text(title).font(MortTypography.section)
                ForEach(values, id: \.self) { value in Label(value, systemImage: icon).font(MortTypography.caption).foregroundStyle(tint) }
            }
        }
    }
}

struct VerificationExplanationView: View {
    private let labels = [
        ("Email ownership confirmed", "The user controlled a confirmation link sent to that email."),
        ("Phone ownership confirmed", "The user controlled a confirmation challenge sent to that phone."),
        ("School affiliation confirmed", "An approved school signal supports affiliation, not government identity."),
        ("Partner organization confirmed", "An authorized organization relationship was recorded."),
        ("MORT document reviewed", "A trained reviewer inspected submitted evidence. Authenticity and legal identity are not automatically established."),
        ("Age evidence reviewed", "Evidence supported an age decision under the documented standard."),
        ("Business registration matched", "Official registry data matched the reviewed business claim."),
        ("Provider-backed identity verified", "An approved external provider returned its documented identity assurance result.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "What verification means", subtitle: "MORT shows separate, precise trust signals instead of one vague Verified badge.")
                ForEach(labels, id: \.0) { item in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.xs) {
                            Text(item.0).font(MortTypography.label)
                            Text(item.1).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        }
                    }
                }
                MortAlertBanner(title: "No safety guarantee", message: "Verification reduces some uncertainty. It does not guarantee honesty, lawful behavior, job quality, payment, or physical safety.", tint: MortColors.warning, icon: "exclamationmark.shield.fill")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Verification wording")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }
}

struct DocumentReviewStatusView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var readiness: DocumentCollectionReadiness?
    @State private var cases: [DocumentReviewCaseSummary] = []
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Document review status", subtitle: "Real identity-document collection is disabled until every server-owned operational gate passes.")
                if let readiness {
                    MortAlertBanner(
                        title: readiness.realDocumentCollectionEnabled ? "Collection enabled" : "Real document collection disabled",
                        message: "\(readiness.passedGateCount) of \(readiness.requiredGateCount) readiness gates are recorded as passed. Clients cannot change this state.",
                        tint: readiness.realDocumentCollectionEnabled ? MortColors.neon : MortColors.warning,
                        icon: readiness.realDocumentCollectionEnabled ? "checkmark.lock.fill" : "lock.fill"
                    )
                    Text(readiness.truthStatement).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    MortPrimaryButton(title: "Upload identity document", icon: "doc.badge.plus", isDisabled: true) {}
                    Text("Uploads remain unavailable. Do not send MORT identity documents by email, message, or support ticket.")
                        .font(MortTypography.caption).foregroundStyle(MortColors.warning)
                    MortSectionHeader(title: "Your review cases")
                    if cases.isEmpty {
                        MortEmptyState(title: "No document review cases", message: "MORT is not collecting real identity documents during this foundation phase.", systemImage: "doc.text.magnifyingglass")
                    } else {
                        ForEach(cases) { item in
                            MortCard {
                                VStack(alignment: .leading, spacing: MortSpacing.xs) {
                                    Text(item.publicLabel).font(MortTypography.label)
                                    MortBadge(text: readable(item.status))
                                    Text("Established: \(item.whatWasEstablished)").font(MortTypography.caption)
                                    Text("Not established: \(item.whatWasNotEstablished)").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                }
                            }
                        }
                    }
                } else if let errorMessage {
                    MortErrorState(message: errorMessage) { Task { await load() } }
                } else {
                    MortLoadingState(label: "Checking server readiness").frame(minHeight: 260)
                }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Document review")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        errorMessage = nil
        do {
            async let loadedReadiness = container.missionPilot.documentReadiness()
            async let loadedCases = container.missionPilot.documentCases()
            (readiness, cases) = try await (loadedReadiness, loadedCases)
        } catch { errorMessage = mortMessage(error) }
    }
}

struct NoAddressOnboardingSupport: View {
    @Binding var locationSetupMode: String
    @State private var showsPrivacy = false

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            Picker("General location setup", selection: $locationSetupMode) {
                Text("Use city and state").tag("city_state")
                Text("Use approved partner support").tag("partner_supported")
                Text("Safely defer location").tag("location_deferred")
            }
            .pickerStyle(.menu)
            if locationSetupMode != "city_state" {
                MortAlertBanner(
                    title: "No permanent address required",
                    message: "MORT stores only this setup choice. It does not ask why, collect housing status, or disclose the choice to job posters.",
                    tint: MortColors.safetyBlue,
                    icon: "lock.shield.fill"
                )
            }
            Button("How MORT protects this choice") { showsPrivacy = true }
                .font(MortTypography.caption)
        }
        .sheet(isPresented: $showsPrivacy) {
            PrivacyExplanationSheet(
                title: "Location privacy",
                points: [
                    "A teen does not need a permanent residential address to complete eligible pilot onboarding.",
                    "Housing status, shelter use, foster status, abuse, and family status are not collected by this choice.",
                    "Posters and other users cannot see this setup mode.",
                    "A general job area may still be required when needed for safe job matching."
                ]
            )
        }
    }
}

struct PrivacyExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let points: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.lg) {
                    MortSectionHeader(title: title)
                    ForEach(points, id: \.self) { point in
                        Label(point, systemImage: "lock.shield.fill")
                            .font(MortTypography.caption)
                    }
                }
                .padding(MortSpacing.lg)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .mortScreen()
        }
    }
}

private func readable(_ value: String) -> String {
    value.replacingOccurrences(of: "_", with: " ").capitalized
}
