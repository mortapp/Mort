import SwiftUI

struct GuardianModeView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var state: LoadState<[GuardianConnection]> = .idle
    @State private var policy: GuardianPolicy?
    @State private var inviteEmail = ""
    @State private var inviteCode = ""
    @State private var isWorking = false
    @State private var message: String?
    @State private var confirmUnlink: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Guardian Mode", subtitle: "Optional, privacy-limited, and always free at the basic level.")
                policyCard
                connectionControls
                connectionsContent
                MortSafetyBanner(message: "Guardian Mode shares selected safety alerts and check-ins. It does not expose unrestricted messages and does not replace direct communication or emergency services.")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Guardian Mode")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .confirmationDialog("Unlink Guardian Mode?", isPresented: Binding(get: { confirmUnlink != nil }, set: { if !$0 { confirmUnlink = nil } })) {
            if let confirmUnlink {
                Button("Unlink", role: .destructive) { Task { await unlink(confirmUnlink) } }
            }
            Button("Cancel", role: .cancel) { confirmUnlink = nil }
        } message: { Text("This removes the connection and its authorized Guardian Mode access.") }
        .alert("MORT", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    @ViewBuilder
    private var policyCard: some View {
        if let policy {
            MortCard {
                VStack(alignment: .leading, spacing: MortSpacing.xs) {
                    Label(policy.linked == true ? "Guardian connection active" : "No active guardian link", systemImage: policy.linked == true ? "checkmark.shield.fill" : "shield")
                        .foregroundStyle(policy.linked == true ? MortColors.neon : MortColors.textMuted)
                    if policy.paused == true {
                        Label("Teen account actions are paused by authorized Guardian Mode policy", systemImage: "pause.circle.fill")
                            .foregroundStyle(MortColors.warning)
                    }
                    if let message = policy.message { Text(message).font(MortTypography.caption).foregroundStyle(MortColors.textMuted) }
                }
            }
        }
    }

    @ViewBuilder
    private var connectionControls: some View {
        if session.profile?.role == .teen {
            MortSectionHeader(title: "Invite a guardian", subtitle: "Create a secure invite now or enter a code from a guardian.")
            MortTextField(title: "Guardian email (optional)", text: $inviteEmail, prompt: "guardian@example.com", keyboardType: .emailAddress, textContentType: .emailAddress)
            MortPrimaryButton(title: "Create guardian invite", icon: "person.badge.plus", isLoading: isWorking) { Task { await createInvite() } }
            MortTextField(title: "Invite code", text: $inviteCode, prompt: "Enter code")
            MortSecondaryButton(title: "Accept invite code", icon: "link") { Task { await acceptInvite() } }
        } else if session.profile?.role == .guardian {
            MortSectionHeader(title: "Link a teen", subtitle: "Enter the invite code the teen chose to share with you.")
            MortTextField(title: "Invite code", text: $inviteCode, prompt: "Enter code")
            MortPrimaryButton(title: "Accept invite", icon: "link", isLoading: isWorking) { Task { await acceptInvite() } }
        }
    }

    @ViewBuilder
    private var connectionsContent: some View {
        switch state {
        case .idle, .loading: ProgressView().tint(MortColors.neon)
        case let .failed(error): MortErrorState(message: error) { Task { await load() } }
        case let .loaded(connections) where connections.isEmpty:
            MortEmptyState(title: "No Guardian Mode connection", message: "You can keep using normal MORT features without one.", systemImage: "person.2")
        case let .loaded(connections):
            ForEach(connections) { connection in
                ConnectionCard(
                    connection: connection,
                    currentRole: session.profile?.role,
                    isWorking: isWorking,
                    updatePreferences: { preferences in Task { await update(preferences) } },
                    resend: { Task { await resend(connection.id) } },
                    cancel: { Task { await cancel(connection.id) } },
                    unlink: { confirmUnlink = connection.id },
                    setPaused: { paused in Task { await setPaused(connection.teenID, paused: paused) } }
                )
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            async let connections = container.guardians.connections()
            async let policyValue = container.guardians.policy()
            let (loadedConnections, loadedPolicy) = try await (connections, policyValue)
            state = .loaded(loadedConnections)
            policy = loadedPolicy
        } catch { state = .failed(mortMessage(error)) }
    }

    private func createInvite() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await container.guardians.createInvite(email: inviteEmail.nilIfBlank)
            message = result.inviteCode.map { "Guardian invite created. Share this code safely: \($0)" } ?? "Guardian invite created."
            await load()
        } catch { message = mortMessage(error) }
    }

    private func acceptInvite() async {
        guard !inviteCode.trimmed.isEmpty else { message = "Enter an invite code first."; return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.guardians.acceptInvite(code: inviteCode)
            inviteCode = ""
            message = "Guardian Mode linked."
            await load()
        } catch { message = mortMessage(error) }
    }

    private func resend(_ id: UUID) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await container.guardians.resendInvite(linkID: id)
            message = result.inviteCode.map { "New invite code: \($0)" } ?? "Guardian invite refreshed."
            await load()
        } catch { message = mortMessage(error) }
    }

    private func cancel(_ id: UUID) async {
        isWorking = true
        defer { isWorking = false }
        do { try await container.guardians.cancelInvite(linkID: id); await load() }
        catch { message = mortMessage(error) }
    }

    private func unlink(_ id: UUID) async {
        isWorking = true
        defer { isWorking = false; confirmUnlink = nil }
        do { try await container.guardians.unlink(linkID: id); await load() }
        catch { message = mortMessage(error) }
    }

    private func update(_ preferences: GuardianPreferences) async {
        isWorking = true
        defer { isWorking = false }
        do { try await container.guardians.updatePreferences(preferences); message = "Guardian preferences saved."; await load() }
        catch { message = mortMessage(error) }
    }

    private func setPaused(_ teenID: UUID, paused: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await container.guardians.setTeenPause(teenID: teenID, paused: paused, reason: paused ? "Guardian safety pause" : nil)
            message = paused ? "Teen account paused by Guardian Mode." : "Teen account pause removed."
            await load()
        } catch { message = mortMessage(error) }
    }
}

private struct ConnectionCard: View {
    let connection: GuardianConnection
    let currentRole: UserRole?
    let isWorking: Bool
    let updatePreferences: (GuardianPreferences) -> Void
    let resend: () -> Void
    let cancel: () -> Void
    let unlink: () -> Void
    let setPaused: (Bool) -> Void
    @State private var preferences: GuardianPreferences?

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.md) {
                HStack {
                    MortAvatar(displayName: personName)
                    VStack(alignment: .leading) {
                        Text(personName).font(MortTypography.label)
                        MortBadge(text: connection.status, tint: statusTint(connection.status))
                    }
                    Spacer()
                }
                if let code = connection.inviteCode, connection.status != "active" {
                    HStack {
                        Text("Invite: \(code)").font(.system(.body, design: .monospaced))
                        Spacer()
                        ShareLink(item: code) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("Share guardian invite code")
                    }
                }
                if preferences != nil, connection.status == "active" {
                    Toggle("Safety Ping alerts", isOn: preferenceBinding(\.safetyPingAlerts))
                    Toggle("Job check-in alerts", isOn: preferenceBinding(\.jobCheckinAlerts))
                    Toggle("Accepted job summary", isOn: preferenceBinding(\.acceptedJobSummary))
                    Toggle("Safety warning alerts", isOn: preferenceBinding(\.safetyWarningAlerts))
                    Toggle("Optional job approval", isOn: preferenceBinding(\.optionalJobApprovalEnabled))
                    Toggle("Weekly digest (Plus perk)", isOn: preferenceBinding(\.weeklyDigest))
                    MortSecondaryButton(title: "Save preferences", icon: "checkmark") {
                        if let preferences { updatePreferences(preferences) }
                    }
                }
                if connection.status == "pending" {
                    HStack {
                        Button("Resend", action: resend).buttonStyle(.bordered)
                        Button("Cancel", role: .destructive, action: cancel).buttonStyle(.bordered)
                    }
                } else if connection.status == "active" {
                    if currentRole == .guardian {
                        HStack {
                            Button("Pause teen", systemImage: "pause.circle", action: { setPaused(true) }).buttonStyle(.bordered)
                            Button("Resume teen", systemImage: "play.circle", action: { setPaused(false) }).buttonStyle(.bordered)
                        }
                    }
                    Button("Unlink Guardian Mode", role: .destructive, action: unlink)
                }
            }
            .disabled(isWorking)
        }
        .onAppear { preferences = connection.preferences }
    }

    private var personName: String {
        currentRole == .guardian ? connection.teen?.name ?? "Linked teen" : connection.guardian?.name ?? connection.inviteEmail ?? "Guardian invite"
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<GuardianPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { preferences?[keyPath: keyPath] ?? false },
            set: { value in
                guard var current = preferences else { return }
                current[keyPath: keyPath] = value
                preferences = current
            }
        )
    }
}

struct GuardianSafetyPingsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var state: LoadState<[SafetyPing]> = .idle

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading safety pings")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(pings) where pings.isEmpty:
                MortEmptyState(title: "No safety pings", message: "Authorized check-ins from linked teens will appear here.", systemImage: "location")
            case let .loaded(pings):
                List(pings) { ping in
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpacing.sm) {
                            HStack { MortAvatar(displayName: ping.teen?.name ?? "Linked teen"); Text(ping.teen?.name ?? "Linked teen").font(MortTypography.label); Spacer(); MortBadge(text: ping.status, tint: ping.status == "safe" ? MortColors.neon : MortColors.warning) }
                            if let note = ping.note { Text(note).foregroundStyle(MortColors.textMuted) }
                            Text(DateFormatting.displayDateTime(ping.createdAt)).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        }
                    }
                    .listRowBackground(MortColors.background)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Safety pings")
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.safety.visibleSafetyPings()) }
        catch { state = .failed(mortMessage(error)) }
    }
}
