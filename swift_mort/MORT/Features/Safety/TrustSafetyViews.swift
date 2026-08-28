import SwiftUI

struct IncidentHistoryView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var state: LoadState<[IncidentCaseSummary]> = .idle
    @State private var appealCase: IncidentCaseSummary?
    @State private var appealReason = ""
    @State private var message: String?

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                MortLoadingState(label: "Loading restricted case history")
            case let .failed(error):
                MortErrorState(message: error) { Task { await load() } }
            case let .loaded(cases) where cases.isEmpty:
                MortEmptyState(title: "No safety cases", message: "Reports and preserved safety incidents you are allowed to see will appear here.", systemImage: "checkmark.shield")
            case let .loaded(cases):
                List(cases) { incident in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            HStack {
                                Text(incident.caseNumber).font(.system(.caption, design: .monospaced))
                                Spacer()
                                MortBadge(text: incident.status.replacingOccurrences(of: "_", with: " "), tint: statusTint(incident.status))
                            }
                            Text(incident.category.replacingOccurrences(of: "_", with: " ").capitalized).font(MortTypography.section)
                            Label(incident.severity.capitalized, systemImage: "exclamationmark.shield.fill")
                                .font(MortTypography.caption).foregroundStyle(incident.severity == "critical" ? MortColors.danger : MortColors.warning)
                            Text(incident.publicStatusNote ?? "Your case is in the restricted safety workflow.")
                                .font(MortTypography.caption).foregroundStyle(MortColors.textSoft)
                            Button("Request appeal review") { appealCase = incident }
                                .buttonStyle(.bordered).tint(MortColors.safetyBlue)
                                .disabled(["pending", "reviewing"].contains(incident.appealStatus))
                        }
                    }
                    .listRowBackground(MortColors.background)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Safety cases")
        .sheet(item: $appealCase) { incident in
            NavigationStack {
                VStack(alignment: .leading, spacing: MortSpacing.lg) {
                    MortSectionHeader(title: "Appeal \(incident.caseNumber)", subtitle: "An appeal creates a separate review and does not automatically restore access or reverse safety action.")
                    MortTextField(title: "Reason", text: $appealReason, prompt: "Explain the specific decision or information to reconsider", axis: .vertical)
                    MortPrimaryButton(title: "Submit appeal", icon: "arrow.triangle.2.circlepath", isDisabled: appealReason.trimmed.count < 20) {
                        Task { await submitAppeal(incident.id) }
                    }
                    Spacer()
                }
                .padding(MortSpacing.lg)
                .navigationTitle("Case appeal")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { appealCase = nil } } }
                .mortScreen()
            }
        }
        .alert("Safety case", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.safety.incidentCases()) }
        catch { state = .failed(mortMessage(error)) }
    }

    private func submitAppeal(_ id: UUID) async {
        do {
            try await container.safety.submitIncidentAppeal(incidentID: id, reason: appealReason)
            appealReason = ""
            appealCase = nil
            message = "Appeal submitted for independent review."
            await load()
        } catch { message = mortMessage(error) }
    }
}

struct SafetyCircleView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var state: LoadState<[SafetyCircleMember]> = .idle
    @State private var label = "Trusted contact"
    @State private var inviteCode = ""
    @State private var receiveSafetyPing = true
    @State private var receiveMissedCheckin = true
    @State private var receiveJobSummary = false
    @State private var receiveJobStatus = false
    @State private var viewLimitedSafetyPlan = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Safety Circle", subtitle: "Optional trusted contacts with only the permissions a teen grants. This is separate from Guardian Mode and does not grant account control.")
                if session.profile?.role == .teen { teenInviteForm }
                else { acceptForm }
                circleList
                MortSafetyBanner(message: "A Safety Circle contact cannot browse identity evidence, private messages, full job history, or unrestricted location. Either person can unlink. Immediate danger still requires local emergency services.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Safety Circle")
        .alert("Safety Circle", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private var teenInviteForm: some View {
        VStack(alignment: .leading, spacing: MortSpacing.md) {
            MortTextField(title: "Relationship label", text: $label, prompt: "Aunt, coach, mentor, trusted adult")
            permissionToggles
            MortPrimaryButton(title: "Create one-time invite", icon: "person.badge.plus") { Task { await createInvite() } }
            if !inviteCode.isEmpty {
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        Text("One-time code").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        Text(inviteCode).font(.system(.title2, design: .monospaced)).textSelection(.enabled)
                        ShareLink(item: inviteCode, subject: Text("MORT Safety Circle invitation"), message: Text("Enter this one-time code in MORT. It expires in seven days.")) {
                            Label("Share code", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private var acceptForm: some View {
        VStack(alignment: .leading, spacing: MortSpacing.md) {
            MortTextField(title: "Invitation code", text: $inviteCode, prompt: "Enter the teen's one-time code")
            MortPrimaryButton(title: "Accept invitation", icon: "person.2.badge.gearshape", isDisabled: inviteCode.trimmed.count < 6) { Task { await acceptInvite() } }
            Text("Trusted contacts complete identity verification before linking. They receive only the teen-selected safety signals.")
                .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
        }
    }

    private var permissionToggles: some View {
        VStack(alignment: .leading, spacing: MortSpacing.sm) {
            Toggle("Safety Pings", isOn: $receiveSafetyPing)
            Toggle("Missed check-ins", isOn: $receiveMissedCheckin)
            Toggle("Limited job summary", isOn: $receiveJobSummary)
            Toggle("Job status changes", isOn: $receiveJobStatus)
            Toggle("Limited Safety Plan", isOn: $viewLimitedSafetyPlan)
        }
        .tint(MortColors.neon)
    }

    @ViewBuilder
    private var circleList: some View {
        switch state {
        case .idle, .loading:
            ProgressView().tint(MortColors.neon)
        case let .failed(error):
            MortAlertBanner(title: "Circle unavailable", message: error)
        case let .loaded(items) where items.isEmpty:
            MortEmptyState(title: "No contacts linked", message: "Safety Circle is optional and can be set up later.", systemImage: "person.2")
        case let .loaded(items):
            ForEach(items) { item in
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        HStack {
                            Text(item.relationshipLabel).font(MortTypography.section)
                            Spacer()
                            MortBadge(text: item.status, tint: statusTint(item.status))
                        }
                        Text(enabledPermissions(item).joined(separator: " | "))
                            .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        HStack {
                            if session.profile?.role == .teen && item.status != "revoked" {
                                Button("Apply current toggles") { Task { await update(item.id) } }
                                    .buttonStyle(.bordered).tint(MortColors.safetyBlue)
                            }
                            Button("Unlink", role: .destructive) { Task { await unlink(item.id) } }
                                .buttonStyle(.bordered).tint(MortColors.danger)
                        }
                    }
                }
            }
        }
    }

    private var permissions: [String: Bool] {
        [
            "receive_safety_ping": receiveSafetyPing,
            "receive_missed_checkin": receiveMissedCheckin,
            "receive_job_summary": receiveJobSummary,
            "receive_job_status": receiveJobStatus,
            "receive_emergency_request": true,
            "view_limited_safety_plan": viewLimitedSafetyPlan,
            "receive_completion": receiveJobStatus,
        ]
    }

    private func enabledPermissions(_ item: SafetyCircleMember) -> [String] {
        var values: [String] = []
        if item.receiveSafetyPing { values.append("Pings") }
        if item.receiveMissedCheckin { values.append("Check-ins") }
        if item.receiveJobSummary { values.append("Job summary") }
        if item.receiveJobStatus { values.append("Job status") }
        if item.viewLimitedSafetyPlan { values.append("Safety Plan") }
        return values.isEmpty ? ["No optional alerts"] : values
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.safety.safetyCircle()) }
        catch { state = .failed(mortMessage(error)) }
    }

    private func createInvite() async {
        do {
            inviteCode = try await container.safety.createSafetyCircleInvite(label: label, permissions: permissions)
            message = "One-time invitation created."
            await load()
        } catch { message = mortMessage(error) }
    }

    private func acceptInvite() async {
        do {
            try await container.safety.acceptSafetyCircleInvite(code: inviteCode)
            inviteCode = ""
            message = "Safety Circle invitation accepted."
            await load()
        } catch { message = mortMessage(error) }
    }

    private func update(_ id: UUID) async {
        do { try await container.safety.updateSafetyCircle(id: id, permissions: permissions); message = "Permissions updated."; await load() }
        catch { message = mortMessage(error) }
    }

    private func unlink(_ id: UUID) async {
        do { try await container.safety.unlinkSafetyCircle(id: id); message = "Safety Circle link removed."; await load() }
        catch { message = mortMessage(error) }
    }
}

struct JobSafetyWorkspaceView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var agreement: JobSafetyAgreement?
    @State private var expectedPeople = ""
    @State private var transportationPlan = ""
    @State private var publicMeeting = true
    @State private var daylight = true
    @State private var checkinMinutes = 30
    @State private var exactAddress = ""
    @State private var arrivalInstructions = ""
    @State private var releasedAddress: String?
    @State private var arrivalCode = ""
    @State private var personMatches = true
    @State private var coarseLocation = ""
    @State private var shares: [AuthorizedLocationShare] = []
    @State private var cancellationReason = "unsafe_condition"
    @State private var cancellationDetails = ""
    @State private var isWorking = false
    @State private var message: String?
    let applicationID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Mutual Safety Agreement", subtitle: "Both participants independently confirm the current scope, people, place, schedule, payment preference, and right to leave. Material changes require confirmation again.")
                agreementCard
                safetyPlanForm
                exactLocationSection
                temporaryLocationSection
                arrivalSection
                cancellationSection
                MortSafetyBanner(message: "Neither verification nor an arrival code guarantees safety. Meet visibly when possible, confirm the person matches the profile, leave when anything differs, and contact emergency services for immediate danger.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Job safety")
        .alert("Job safety", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    @ViewBuilder
    private var agreementCard: some View {
        if let agreement {
            MortCard {
                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                    HStack {
                        Text("Version \(agreement.agreementVersion)").font(MortTypography.section)
                        Spacer()
                        MortBadge(text: agreement.status.replacingOccurrences(of: "_", with: " "), tint: agreement.status == "confirmed" ? MortColors.neon : MortColors.warning)
                    }
                    ForEach(["job_title", "scope", "who_will_be_present", "physical_requirements"], id: \.self) { key in
                        if let value = agreement.termsSnapshot[key], value != .null {
                            VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                                Text(key.replacingOccurrences(of: "_", with: " ").capitalized).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                                Text(value.displayValue).font(MortTypography.caption)
                            }
                        }
                    }
                    MortPrimaryButton(title: "Confirm this exact version", icon: "checkmark.seal.fill", isLoading: isWorking) { Task { await confirmAgreement() } }
                }
            }
        } else {
            MortAlertBanner(title: "Agreement not created yet", message: "The agreement appears after the poster accepts an application.", tint: MortColors.warning, icon: "hourglass")
        }
    }

    private var safetyPlanForm: some View {
        VStack(alignment: .leading, spacing: MortSpacing.md) {
            MortSectionHeader(title: "Safe First Meeting", subtitle: "Plan who will be present, visibility, daylight, transportation, and check-ins before work starts.")
            MortTextField(title: "Who will be present", text: $expectedPeople, prompt: "Poster, staff member, family member")
            MortTextField(title: "Transportation and exit plan", text: $transportationPlan, prompt: "How each person arrives and can leave", axis: .vertical)
            Toggle("Public or clearly visible meeting", isOn: $publicMeeting).tint(MortColors.neon)
            Toggle("Daylight preferred", isOn: $daylight).tint(MortColors.neon)
            Stepper("Check in every \(checkinMinutes) minutes", value: $checkinMinutes, in: 15...240, step: 15)
            MortPrimaryButton(title: "Save plan and require reconfirmation", icon: "list.clipboard.fill", isLoading: isWorking, isDisabled: agreement == nil) { Task { await savePlan() } }
        }
    }

    @ViewBuilder
    private var exactLocationSection: some View {
        MortSectionHeader(title: "Staged exact location", subtitle: "The public job contains only a general area. Restricted location is released to the accepted teen only after both confirmations.")
        if session.profile?.role == .adult, agreement != nil {
            MortTextField(title: "Exact job address", text: $exactAddress, prompt: "Stored privately, never in the public feed")
            MortTextField(title: "Arrival instructions", text: $arrivalInstructions, prompt: "Safe entrance and check-in point", axis: .vertical)
            MortPrimaryButton(title: "Save restricted location", icon: "lock.location.fill", isLoading: isWorking, isDisabled: exactAddress.trimmed.count < 5) { Task { await saveLocation() } }
        }
        MortPrimaryButton(title: "Request location for current stage", icon: "mappin.and.ellipse", isLoading: isWorking, isDisabled: agreement == nil) { Task { await getLocation() } }
        if let releasedAddress {
            MortAlertBanner(title: "Restricted location released", message: releasedAddress, tint: MortColors.safetyBlue, icon: "lock.open.fill")
        }
    }

    @ViewBuilder
    private var temporaryLocationSection: some View {
        MortSectionHeader(title: "Temporary location sharing", subtitle: "Optional, explicit, visible, job-bound, and automatically expires after two hours. This screen shares a coarse area only.")
        MortTextField(title: "Coarse area", text: $coarseLocation, prompt: "Near the public library")
        MortPrimaryButton(title: "Share coarse area with job participant", icon: "location.fill", isLoading: isWorking, isDisabled: agreement == nil || coarseLocation.trimmed.count < 3) { Task { await startShare() } }
        ForEach(shares) { share in
            MortCard {
                HStack {
                    VStack(alignment: .leading) {
                        Text(share.mode.replacingOccurrences(of: "_", with: " ").capitalized).font(MortTypography.label)
                        Text(share.coarseLocation ?? "Location active").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    }
                    Spacer()
                    if share.ownerID == session.profile?.id {
                        Button("Stop") { Task { await stopShare(share.id) } }.buttonStyle(.bordered).tint(MortColors.danger)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var arrivalSection: some View {
        MortSectionHeader(title: "Arrival handshake", subtitle: "The poster generates a short-lived code. The assigned teen independently confirms both the code and person match. Codes are single-use.")
        if session.profile?.role == .adult {
            MortPrimaryButton(title: "Generate 10-minute code", icon: "qrcode", isLoading: isWorking, isDisabled: agreement?.status != "confirmed") { Task { await generateCode() } }
            if !arrivalCode.isEmpty { Text(arrivalCode).font(.system(.title, design: .monospaced)).textSelection(.enabled) }
        } else if session.profile?.role == .teen {
            MortTextField(title: "Arrival code", text: $arrivalCode, prompt: "Six-character code")
            Toggle("The person present matches the verified profile", isOn: $personMatches).tint(MortColors.neon)
            MortPrimaryButton(title: personMatches ? "Confirm arrival" : "Report person mismatch", icon: personMatches ? "person.badge.shield.checkmark" : "person.crop.circle.badge.exclamationmark", isLoading: isWorking, isDisabled: arrivalCode.trimmed.count < 6) { Task { await confirmArrival() } }
        }
    }

    private var cancellationSection: some View {
        VStack(alignment: .leading, spacing: MortSpacing.md) {
            MortSectionHeader(title: "Leave without retaliation", subtitle: "Safety-related cancellations do not automatically reduce reputation. A serious reason opens the restricted incident workflow.")
            Picker("Reason", selection: $cancellationReason) {
                Text("Unsafe condition").tag("unsafe_condition")
                Text("Person mismatch").tag("person_mismatch")
                Text("Harassment").tag("harassment")
                Text("Location changed").tag("location_changed")
                Text("Scope changed").tag("scope_changed")
                Text("Emergency").tag("emergency")
            }
            .pickerStyle(.menu)
            MortTextField(title: "What changed?", text: $cancellationDetails, prompt: "Add factual context for safety review", axis: .vertical)
            MortDangerButton(title: "Cancel for this reason") { Task { await cancelForSafety() } }
                .disabled(agreement == nil)
        }
    }

    private func load() async {
        do {
            agreement = try await container.safety.safetyAgreement(applicationID: applicationID)
            shares = (try await container.safety.authorizedLocationShares()).filter { $0.applicationID == applicationID }
        } catch { message = mortMessage(error) }
    }

    private func run(_ operation: () async throws -> Void, success: String) async {
        isWorking = true
        defer { isWorking = false }
        do { try await operation(); message = success; await load() }
        catch { message = mortMessage(error) }
    }

    private func savePlan() async {
        await run({ try await container.safety.saveSafetyPlan(applicationID: applicationID, expectedPeople: expectedPeople, publicMeeting: publicMeeting, daylight: daylight, transportation: transportationPlan, checkinMinutes: checkinMinutes) }, success: "Safety Plan saved. Both participants must reconfirm the new version.")
    }

    private func confirmAgreement() async {
        guard let agreement else { return }
        await run({ try await container.safety.confirmSafetyAgreement(applicationID: applicationID, version: agreement.agreementVersion) }, success: "Your independent confirmation was recorded.")
    }

    private func saveLocation() async {
        guard let agreement else { return }
        await run({ try await container.safety.savePrivateJobLocation(jobID: agreement.jobID, address: exactAddress, arrivalInstructions: arrivalInstructions, accessNotes: nil) }, success: "Restricted job location saved. Prior confirmations were cleared.")
    }

    private func getLocation() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let payload = try await container.safety.releasedJobLocation(applicationID: applicationID)
            releasedAddress = payload["exact_address"]?.stringValue
        } catch { message = mortMessage(error) }
    }

    private func startShare() async {
        guard let agreement, let userID = session.profile?.id else { return }
        let recipient = userID == agreement.teenID ? agreement.adultID : agreement.teenID
        await run({ _ = try await container.safety.startTemporaryLocationShare(applicationID: applicationID, recipientID: recipient, mode: "coarse_area", coarseLocation: coarseLocation) }, success: "Temporary coarse-area sharing started with a visible active indicator.")
    }

    private func stopShare(_ id: UUID) async {
        await run({ try await container.safety.stopTemporaryLocationShare(id: id) }, success: "Temporary location sharing stopped.")
    }

    private func generateCode() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await container.safety.generateArrivalCode(applicationID: applicationID)
            arrivalCode = result.arrivalCode ?? ""
            message = "A single-use arrival code was generated."
        } catch { message = mortMessage(error) }
    }

    private func confirmArrival() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await container.safety.confirmArrival(applicationID: applicationID, code: arrivalCode, personMatches: personMatches)
            message = personMatches ? "Arrival confirmed without exchanging identity documents." : "Person mismatch recorded as a restricted safety case: \(result.caseNumber ?? "case created")."
        } catch { message = mortMessage(error) }
    }

    private func cancelForSafety() async {
        await run({ try await container.safety.submitSafetyCancellation(applicationID: applicationID, reason: cancellationReason, details: cancellationDetails) }, success: "Cancellation recorded. No automatic reputation penalty was applied.")
    }
}

struct AccountSessionsView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var state: LoadState<[ActiveAccountSession]> = .idle
    @State private var message: String?

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading active sessions")
            case let .failed(error): MortErrorState(message: error) { Task { await load() } }
            case let .loaded(items):
                List(items) { item in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            HStack {
                                Text(item.userAgent ?? "Unknown device").font(MortTypography.label).lineLimit(2)
                                Spacer()
                                if item.isCurrent { MortBadge(text: "Current", tint: MortColors.neon) }
                            }
                            Text("Session \(item.sessionReference)").font(.system(.caption, design: .monospaced)).foregroundStyle(MortColors.textMuted)
                            Text("Assurance: \(item.assuranceLevel ?? "unknown")").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                            Button("Report unfamiliar session") { Task { await report(item) } }.buttonStyle(.bordered).tint(MortColors.warning)
                        }
                    }
                    .listRowBackground(MortColors.background)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Active sessions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign out all") { Task { await session.signOut() } }
            }
        }
        .alert("Account security", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.safety.activeSessions()) }
        catch { state = .failed(mortMessage(error)) }
    }

    private func report(_ item: ActiveAccountSession) async {
        do {
            try await container.safety.reportAccountSecurityConcern(type: "unrecognized_session", sessionReference: item.sessionReference, details: "User reported this session as unfamiliar from the iOS account security screen.")
            message = "Security concern recorded. Sign out and reset your password if the session is not yours."
        } catch { message = mortMessage(error) }
    }
}
