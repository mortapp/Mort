//
//  MessagesListView.swift
//  MORT
//

import SwiftUI

struct MessagesListView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    @State private var conversations: [Conversation] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MortTopBar(title: "Messages", subtitle: "All chats stay inside MORT")
                content
            }
            .mortScreen()
            .navigationDestination(for: Conversation.self) { ChatView(conversation: $0) }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            MortLoadingView()
        } else if conversations.isEmpty {
            MortEmptyState(systemImage: "bubble.left.and.bubble.right", title: "No messages yet", message: "When you connect about a job, your chats appear here.")
        } else {
            ScrollView {
                LazyVStack(spacing: MortSpacing.sm) {
                    ForEach(conversations) { convo in
                        NavigationLink(value: convo) {
                            ConversationRow(conversation: convo)
                        }
                        .buttonStyle(.plain)
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
        conversations = (try? await services.messages.fetchConversations(for: me.id)) ?? []
        loading = false
    }
}

private struct ConversationRow: View {
    let conversation: Conversation
    var body: some View {
        MortCard {
            HStack(spacing: MortSpacing.sm) {
                MortAvatar(name: conversation.otherUserName)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(conversation.otherUserName).font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                        Spacer()
                        Text(conversation.lastMessageAt, style: .time).font(MortFont.caption()).foregroundStyle(MortColor.darkSilver)
                    }
                    if let job = conversation.jobTitle {
                        Text(job).font(MortFont.caption()).foregroundStyle(MortColor.roseGold)
                    }
                    Text(conversation.lastMessage).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText).lineLimit(1)
                }
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(MortFont.tiny()).foregroundStyle(MortColor.productionBlack)
                        .frame(width: 20, height: 20).background(MortColor.roseGold).clipShape(Circle())
                }
            }
        }
    }
}
