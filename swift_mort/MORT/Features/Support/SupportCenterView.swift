import SwiftUI

struct SupportCenterView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var state: LoadState<[SupportTicket]> = .idle
    @State private var subject = ""
    @State private var messageText = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Support", subtitle: "Send a real support ticket through the rate-limited backend RPC.")
                MortTextField(title: "Subject", text: $subject, prompt: "What do you need help with?")
                MortTextField(title: "Message", text: $messageText, prompt: "Include useful facts and no passwords or verification codes.", axis: .vertical)
                MortPrimaryButton(title: "Create ticket", icon: "paperplane.fill", isLoading: isWorking, isDisabled: subject.trimmed.count < 3 || messageText.trimmed.count < 10) { Task { await create() } }
                MortSectionHeader(title: "Your tickets")
                ticketContent
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Support request failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .task { await load() }
        .mortScreen()
    }

    @ViewBuilder
    private var ticketContent: some View {
        switch state {
        case .idle, .loading: ProgressView().tint(MortColors.neon)
        case let .failed(message): MortAlertBanner(title: "Tickets unavailable", message: message)
        case let .loaded(tickets) where tickets.isEmpty: Text("No support tickets yet.").foregroundStyle(MortColors.textMuted)
        case let .loaded(tickets):
            ForEach(tickets) { ticket in
                MortCard {
                    HStack { VStack(alignment: .leading) { Text(ticket.subject).font(MortTypography.label); Text(DateFormatting.displayDateTime(ticket.createdAt)).font(MortTypography.caption).foregroundStyle(MortColors.textMuted) }; Spacer(); MortBadge(text: ticket.status, tint: statusTint(ticket.status)) }
                }
            }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.support.listMine()) }
        catch { state = .failed(mortMessage(error)) }
    }

    private func create() async {
        isWorking = true
        defer { isWorking = false }
        do { _ = try await container.support.createTicket(subject: subject, message: messageText); subject = ""; messageText = ""; await load() }
        catch { errorMessage = mortMessage(error) }
    }
}
