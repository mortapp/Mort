//
//  NotificationsView.swift
//  MORT
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    @State private var items: [NotificationItem] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "Notifications", subtitle: "Updates, messages, and safety reminders")
                content
            }
            .mortScreen()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView()
        } else if items.isEmpty {
            MortEmptyState(systemImage: "bell.slash", title: "You're all caught up", message: "Job updates, messages, and safety reminders will appear here.")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(items) { item in
                        MortNotificationRow(item: item)
                            .onTapGesture { Task { await markRead(item) } }
                    }
                }
                .padding(.horizontal, MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
        }
    }

    private func load() async {
        guard let me = session.profile else { return }
        loading = true
        items = (try? await services.notifications.fetch(for: me.id)) ?? []
        loading = false
    }

    private func markRead(_ item: NotificationItem) async {
        try? await services.notifications.markRead(item.id)
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].read = true
        }
    }
}
