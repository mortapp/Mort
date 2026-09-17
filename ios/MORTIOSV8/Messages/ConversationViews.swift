//
//  ConversationViews.swift
//  MORT iOS V8 — Messaging
//
//  Conversations exist because of a job, so job context is always visible.
//  Blocked, archived and restricted threads are honest read-only states.
//

import SwiftUI

struct ConversationListView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var conversations: LoadState<[MortConversation]> = .idle

    var body: some View {
        MortScreen(atmosphereIntensity: 0.55) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                Text("Messages").mortH1()

                switch conversations {
                case .idle, .loading:
                    MortSkeletonList(rows: 4)
                case .failed(let error):
                    MortErrorState(message: error.userMessage) { Task { await load() } }
                case .loaded(let items), .offlineCache(let items):
                    if items.isEmpty {
                        MortEmptyState(
                            symbol: "bubble.left.and.bubble.right",
                            title: "No conversations yet",
                            message: "When you apply for a job or someone applies to yours, you can message here."
                        )
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { conversation in
                                ConversationRow(conversation: conversation) {
                                    nav.push(.conversation(conversation.id))
                                }
                                MortDivider()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        .task { if case .idle = conversations { await load() } }
        .refreshable { await load() }
    }

    private func load() async {
        conversations = .loading
        do {
            conversations = .loaded(try await mort.messages.conversations())
        } catch let error as MortError {
            conversations = .failed(error)
        } catch {
            conversations = .failed(.unknown)
        }
    }
}

private struct ConversationRow: View {
    let conversation: MortConversation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: MortSpace.s3) {
                MortAvatar(
                    initials: conversation.counterpartyInitials,
                    size: 42,
                    tone: conversation.unreadCount > 0 ? .info : nil
                )
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: MortSpace.s2) {
                        Text(conversation.counterpartyDisplayName)
                            .mortBodyStrong()
                            .lineLimit(1)
                        Spacer(minLength: MortSpace.s1)
                        Text(conversation.timeText).mortMicro().lineLimit(1)
                    }
                    Text(conversation.jobTitle)
                        .mortMicro()
                        .lineLimit(1)
                    Text(conversation.preview)
                        .font(MortFont.body())
                        .foregroundStyle(
                            conversation.unreadCount > 0 ? MortColor.textPrimary : MortColor.textSecondary
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if conversation.restriction != .none,
                       let notice = conversation.restriction.notice {
                        MortNote(text: notice, tone: .warning, symbol: "lock")
                    }
                }
                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MortColor.ink1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background { Capsule().fill(MortColor.silver2) }
                }
            }
            .padding(.vertical, MortSpace.s3)
            .frame(minHeight: MortMetric.minTouchTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(conversation.counterpartyDisplayName), \(conversation.jobTitle). \(conversation.unreadCount) unread."
        )
    }
}

struct ConversationView: View {
    let conversationId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var messages: LoadState<[MortMessage]> = .idle
    @State private var conversation: MortConversation?
    @State private var draft = ""
    @State private var isSending = false
    @State private var sendError: MortError?

    private var restriction: ConversationRestriction {
        conversation?.restriction ?? .none
    }

    private var canSend: Bool {
        restriction == .none && !draft.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    var body: some View {
        MortScreen(atmosphereIntensity: 0.4, scrolls: false) {
            VStack(spacing: 0) {
                if let conversation {
                    JobContextStrip(
                        title: conversation.jobTitle,
                        counterpartyHandle: conversation.counterpartyHandle
                    )
                    .padding(.bottom, MortSpace.s3)
                }

                switch messages {
                case .idle, .loading:
                    MortSkeletonList(rows: 4)
                    Spacer()
                case .failed(let error):
                    MortErrorState(message: error.userMessage) { Task { await load() } }
                    Spacer()
                case .loaded(let items), .offlineCache(let items):
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: MortSpace.s3) {
                                ForEach(items) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.vertical, MortSpace.s3)
                        }
                        .scrollIndicators(.hidden)
                        .onAppear {
                            if let last = items.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                if let notice = restriction.notice {
                    MortNote(text: notice, tone: .warning, symbol: "lock")
                        .padding(.vertical, MortSpace.s2)
                }
                if let sendError {
                    MortNote(text: sendError.userMessage, tone: .danger)
                }
            }
        } bottom: {
            MortBottomBar {
                if restriction == .none {
                    HStack(spacing: MortSpace.s2) {
                        TextField("Message", text: $draft, axis: .vertical)
                            .font(MortFont.body())
                            .foregroundStyle(MortColor.textPrimary)
                            .tint(MortColor.silver3)
                            .lineLimit(1...4)
                            .padding(.horizontal, MortSpace.s3)
                            .frame(minHeight: MortMetric.minTouchTarget)
                            .background {
                                RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                                    .fill(MortColor.graphite2.opacity(0.9))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                                    .strokeBorder(MortColor.borderGraphite2, lineWidth: 1)
                            }
                            .accessibilityLabel("Message")

                        Button {
                            Task { await send() }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MortColor.ink1)
                                .frame(width: MortMetric.minTouchTarget, height: MortMetric.minTouchTarget)
                                .background { Circle().fill(MortColor.silver2) }
                                .opacity(canSend ? 1 : 0.38)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                        .accessibilityLabel("Send message")
                    }
                    MortNote(
                        text: "Keep addresses and phone numbers out of chat until a job is confirmed.",
                        tone: .neutral,
                        symbol: "lock.shield"
                    )
                }
            }
        }
        .navigationTitle(conversation?.counterpartyDisplayName ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        nav.push(.publicProfile(conversation?.counterpartyHandle ?? ""))
                    } label: {
                        Label("View profile", systemImage: "person.crop.circle")
                    }
                    Button {
                        nav.present(.safetyReport(jobId: conversation?.jobId))
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        Task {
                            try? await mort.messages.block(handle: conversation?.counterpartyHandle ?? "")
                            await load()
                        }
                    } label: {
                        Label("Block", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(MortColor.textPrimary)
                }
                .accessibilityLabel("Conversation options")
            }
        }
        .task { await load() }
    }

    private func load() async {
        messages = .loading
        conversation = (try? await mort.messages.conversations())?
            .first { $0.id == conversationId }
        do {
            let page = try await mort.messages.messages(conversationId: conversationId, cursor: nil)
            messages = .loaded(page.messages)
            try? await mort.messages.markRead(conversationId: conversationId)
        } catch let error as MortError {
            messages = .failed(error)
        } catch {
            messages = .failed(.unknown)
        }
    }

    private func send() async {
        isSending = true
        sendError = nil
        let body = draft
        draft = ""
        do {
            let sent = try await mort.messages.send(conversationId: conversationId, body: body)
            messages = .loaded((messages.value ?? []) + [sent])
            MortHaptic.select()
        } catch let error as MortError {
            sendError = error
            draft = body
            MortHaptic.failure()
        } catch {
            sendError = .unknown
            draft = body
        }
        isSending = false
    }
}

private struct MessageBubble: View {
    let message: MortMessage

    var body: some View {
        HStack {
            if message.fromMe { Spacer(minLength: 48) }
            VStack(alignment: message.fromMe ? .trailing : .leading, spacing: 3) {
                Text(message.body)
                    .font(MortFont.body())
                    .foregroundStyle(message.fromMe ? MortColor.ink1 : MortColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MortSpace.s3)
                    .padding(.vertical, MortSpace.s2 + 2)
                    .background {
                        RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                            .fill(message.fromMe ? MortColor.silver2 : MortColor.graphite3)
                    }
                HStack(spacing: MortSpace.s1) {
                    Text(message.timeText).mortMicro()
                    if message.fromMe, let symbol = message.delivery.symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 9))
                            .foregroundStyle(
                                message.delivery == .failed ? MortColor.danger : MortColor.textMuted
                            )
                    }
                    if message.delivery == .failed {
                        Text("Not sent")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(MortColor.danger)
                    }
                }
            }
            if !message.fromMe { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(message.fromMe ? "You" : message.authorDisplayName): \(message.body). \(message.delivery.label)."
        )
    }
}

#Preview {
    NavigationStack { ConversationListView() }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
