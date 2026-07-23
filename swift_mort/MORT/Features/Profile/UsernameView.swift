import SwiftUI

struct UsernameView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var status: LoadState<UsernameChangeStatus> = .idle
    @State private var username = ""
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Username", subtitle: "The backend decides whether a free allowance, Plus allowance, admin credit, or token credit is consumed.")
                statusCard
                MortTextField(title: "New username", text: $username, prompt: "letters_numbers")
                Text("Choose a name that does not reveal your school, birth year, phone number, or exact location.")
                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                MortPrimaryButton(title: "Request username change", icon: "at", isLoading: isWorking, isDisabled: username.trimmed.count < 3) { Task { await change() } }
                MortSecondaryButton(title: "Get optional change token", icon: "sparkles") { router.push(.monetization("username_change")) }
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Username")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Username", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .task { await load() }
        .mortScreen()
    }

    @ViewBuilder
    private var statusCard: some View {
        switch status {
        case .idle, .loading: ProgressView().tint(MortColors.neon)
        case let .failed(error): MortAlertBanner(title: "Credits unavailable", message: error)
        case let .loaded(value):
            MortCard {
                VStack(alignment: .leading, spacing: MortSpacing.sm) {
                    Text(value.currentUsername.map { "@\($0)" } ?? "No username set").font(MortTypography.section)
                    Text("Free changes remaining: \(value.freeChangesRemaining)")
                    Text("Token credits: \(value.tokenCredits)")
                    Text("Admin credits: \(value.adminCredits)")
                    Text(value.plusAllowanceAvailable ? "Plus allowance available" : "No Plus allowance currently available")
                }
                .font(MortTypography.caption)
            }
        }
    }

    private func load() async {
        status = .loading
        do { status = .loaded(try await container.profiles.usernameChangeStatus()) }
        catch { status = .failed(mortMessage(error)) }
    }

    private func change() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await container.profiles.requestUsernameChange(username)
            message = result.message ?? "Username updated to @\(result.username ?? username.trimmed)."
            username = ""
            await session.refreshProfile()
            await load()
        } catch { message = mortMessage(error) }
    }
}
