import SwiftUI

struct NotificationCenterView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var state: LoadState<[MortNotification]> = .idle
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading notifications")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(items) where items.isEmpty:
                MortEmptyState(title: "No notifications", message: "Application, message, guardian, safety, job, proof, review, support, and verification updates appear here.", systemImage: "bell")
            case let .loaded(items):
                List(items) { item in
                    Button { Task { await open(item) } } label: { notificationRow(item) }
                        .buttonStyle(.plain)
                        .listRowBackground(MortColors.background)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Updates")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await markAllRead() } } label: { Image(systemName: "checkmark.circle") }
                    .disabled(isWorking)
                    .accessibilityLabel("Mark all notifications read")
            }
        }
        .alert("Notification error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .task { await load() }
        .mortScreen()
    }

    private func notificationRow(_ item: MortNotification) -> some View {
        MortCard {
            HStack(alignment: .top, spacing: MortSpacing.md) {
                Image(systemName: item.isUnread ? "bell.badge.fill" : "bell")
                    .foregroundStyle(item.isUnread ? MortColors.safetyBlue : MortColors.textMuted)
                VStack(alignment: .leading, spacing: MortSpacing.xs) {
                    HStack { Text(item.title).font(MortTypography.label).foregroundStyle(MortColors.text); if item.isUnread { MortBadge(text: "New", tint: MortColors.neon) } }
                    Text(item.body).foregroundStyle(MortColors.textMuted)
                    Text(DateFormatting.displayDateTime(item.createdAt)).font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
            }
        }
    }

    private func load() async {
        state = .loading
        do { state = .loaded(try await container.notifications.listMine()) }
        catch { state = .failed(mortMessage(error)) }
    }

    private func markAllRead() async {
        isWorking = true
        defer { isWorking = false }
        do { try await container.notifications.markAllRead(); await load() }
        catch { errorMessage = mortMessage(error) }
    }

    private func open(_ item: MortNotification) async {
        do {
            if item.isUnread { try await container.notifications.markRead(id: item.id) }
            router.push(NotificationDestinationResolver.destination(for: item.data, role: session.profile?.role))
        } catch { errorMessage = mortMessage(error) }
    }
}
