import SwiftUI

struct SafetyCenterView: View {
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var showingPing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                    Image(systemName: "shield.lefthalf.filled").font(.system(size: 42)).foregroundStyle(MortColors.safetyBlue)
                    Text("Safety Center").font(MortTypography.title)
                    Text("Free tools for check-ins, reports, blocking, and clear safety guidance.")
                        .foregroundStyle(MortColors.textMuted)
                }
                if session.profile?.role == .teen {
                    MortPrimaryButton(title: "Send Safety Ping", icon: "location.fill") { showingPing = true }
                }
                if session.profile?.role == .guardian {
                    safetyLink("View linked safety pings", "Authorized check-ins from linked teens", "location.fill", .guardianSafetyPings)
                }
                safetyLink("Blocked accounts", "Review and undo your own blocks", "hand.raised.fill", .blockedUsers)
                safetyLink("Safety Circle", "Optional contacts with permissions you control", "person.2.badge.gearshape", .safetyCircle)
                safetyLink("Safety case history", "Restricted status and appeal access", "case.fill", .incidentHistory)
                safetyLink("Account sessions", "Review and report unfamiliar sessions", "iphone.and.arrow.forward", .activeSessions)
                safetyLink("Teen safety guide", "Private information, work boundaries, and trusted help", "checkmark.shield.fill", .legal(.teenSafety))
                safetyLink("AI transparency", "How rules and machine-assisted safety signals are used", "sparkles.rectangle.stack", .legal(.aiTransparency))
                emergencyGuidance
                MortAlertBanner(title: "Safety stays free", message: "Report, block, Safety Ping, and emergency guidance never require a purchase or ad view.", tint: MortColors.neon, icon: "lock.open.fill")
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Safety")
        .sheet(isPresented: $showingPing) { SafetyPingSheet() }
        .mortScreen()
    }

    private func safetyLink(_ title: String, _ subtitle: String, _ icon: String, _ route: AppRoute) -> some View {
        Button { router.push(route) } label: {
            MortCard {
                HStack(spacing: MortSpacing.md) {
                    Image(systemName: icon).font(.title2).foregroundStyle(MortColors.safetyBlue).frame(width: 32)
                    VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                        Text(title).font(MortTypography.label).foregroundStyle(MortColors.text)
                        Text(subtitle).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(MortColors.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var emergencyGuidance: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                Label("Need immediate help?", systemImage: "sos.circle.fill")
                    .font(MortTypography.section).foregroundStyle(MortColors.danger)
                Text("Leave the situation if you can. Contact local emergency services and a trusted adult. MORT is not an emergency service and Safety Ping does not guarantee an immediate response.")
                    .foregroundStyle(MortColors.textSoft)
                if let url = URL(string: "tel://911") {
                    Link(destination: url) { Label("Call 911 in the United States", systemImage: "phone.fill") }
                        .font(MortTypography.label).foregroundStyle(MortColors.danger)
                }
            }
        }
    }
}

private struct SafetyPingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DependencyContainer.self) private var container
    @State private var status = "ok"
    @State private var note = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.lg) {
                    MortSectionHeader(title: "Safety Ping", subtitle: "Share a simple check-in with authorized Guardian Mode recipients.")
                    Picker("Status", selection: $status) {
                        Text("I'm okay").tag("ok")
                        Text("I need help").tag("needs_help")
                    }
                    .pickerStyle(.segmented)
                    MortTextField(title: "Short note (optional)", text: $note, prompt: "Keep it brief and avoid exact private details", axis: .vertical)
                    MortSafetyBanner(message: "Safety Ping does not contact emergency services or guarantee a response. Use emergency services for immediate danger.")
                    MortPrimaryButton(title: status == "needs_help" ? "Send help ping" : "Send check-in", icon: "location.fill", isLoading: isWorking) {
                        Task { await send() }
                    }
                }
                .padding(MortSpacing.lg)
            }
            .navigationTitle("Safety Ping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .alert("Ping not sent", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .mortScreen()
        }
    }

    private func send() async {
        isWorking = true
        defer { isWorking = false }
        do { try await container.safety.createSafetyPing(status: status, note: note.nilIfBlank); dismiss() }
        catch { errorMessage = mortMessage(error) }
    }
}

struct ReportView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(Router.self) private var router
    @State private var reason = "unsafe_content"
    @State private var details = ""
    @State private var blockUserToo = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    let target: ReportTarget

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Report \(targetLabel)", subtitle: "Reports go to the backend moderation queue. Add facts, not guesses.")
                Picker("Reason", selection: $reason) {
                    Text("Unsafe or prohibited content").tag("unsafe_content")
                    Text("Harassment or threats").tag("harassment")
                    Text("Scam or payment pressure").tag("scam")
                    Text("Sexual or exploitative behavior").tag("exploitation")
                    Text("Private information shared").tag("privacy")
                    Text("Discrimination").tag("discrimination")
                    Text("Other safety concern").tag("other")
                }
                .pickerStyle(.menu)
                MortTextField(title: "What happened?", text: $details, prompt: "Describe the behavior, timing, and relevant context.", axis: .vertical)
                if case .user = target {
                    Toggle("Also block this account", isOn: $blockUserToo).tint(MortColors.neon)
                }
                MortSafetyBanner(message: "For immediate danger, leave the situation and contact local emergency services. A MORT report is not an emergency call.")
                MortDangerButton(title: isWorking ? "Submitting..." : "Submit report") { Task { await submit() } }
                    .disabled(isWorking || details.trimmed.count < 10)
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Report not submitted", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .mortScreen()
    }

    private var targetLabel: String {
        switch target {
        case .user: "account"
        case .job: "job"
        case .message: "message"
        case .review: "review"
        }
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await container.safety.report(target: target, reason: reason, details: details)
            if blockUserToo, case let .user(id) = target { try await container.safety.block(userID: id) }
            router.pop()
        } catch { errorMessage = mortMessage(error) }
    }
}

struct BlockedUsersView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var state: LoadState<[BlockRecord]> = .idle
    @State private var people: [UUID: Profile] = [:]
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading blocked accounts")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(blocks) where blocks.isEmpty:
                MortEmptyState(title: "No blocked accounts", message: "Accounts you block will appear here.", systemImage: "hand.raised")
            case let .loaded(blocks):
                List(blocks) { block in
                    HStack(spacing: MortSpacing.md) {
                        MortAvatar(displayName: people[block.blockedID]?.name ?? "Blocked account")
                        VStack(alignment: .leading) {
                            Text(people[block.blockedID]?.name ?? "Blocked account").font(MortTypography.label)
                            Text("Blocked \(DateFormatting.displayDateTime(block.createdAt))").font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                        }
                        Spacer()
                        Button("Unblock") { Task { await unblock(block.blockedID) } }.buttonStyle(.bordered)
                    }
                    .listRowBackground(MortColors.background)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Blocked accounts")
        .alert("Could not update block", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func load() async {
        state = .loading
        do {
            let blocks = try await container.safety.blockedUsers()
            state = .loaded(blocks)
            var loaded: [UUID: Profile] = [:]
            for id in Set(blocks.map(\.blockedID)) {
                if let profile = try await container.profiles.profile(id: id) { loaded[id] = profile }
            }
            people = loaded
        } catch { state = .failed(mortMessage(error)) }
    }

    private func unblock(_ id: UUID) async {
        do { try await container.safety.unblock(userID: id); await load() }
        catch { errorMessage = mortMessage(error) }
    }
}
