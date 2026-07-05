//
//  ChatView.swift
//  MORT
//
//  Chat screen with an unsafe-message scanner that blocks before sending.
//

import SwiftUI

struct ChatView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    let conversation: Conversation

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var scan: SafetyScanResult = .safe
    @State private var sending = false
    @State private var showReport = false
    @State private var showBlock = false
    @State private var blocked = false

    private var myId: String { session.profile?.id ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: MortSpacing.sm) {
                        ForEach(messages) { message in
                            MortMessageBubble(message: message, isMine: message.senderId == myId)
                                .id(message.id)
                        }
                    }
                    .padding(MortSpacing.md)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            if !scan.isSafe {
                MortSafetyBanner(result: scan)
                    .padding(.horizontal, MortSpacing.md)
                    .padding(.bottom, MortSpacing.xs)
            }

            composer
        }
        .mortScreen()
        .navigationTitle(conversation.otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) { showReport = true } label: { Label("Report", systemImage: "flag") }
                    Button(role: .destructive) { showBlock = true } label: { Label("Block user", systemImage: "hand.raised") }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(MortColor.roseGold)
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showReport) {
            if let me = session.profile {
                ReportSheet(targetType: .user, targetId: conversation.otherUserId, targetLabel: conversation.otherUserName, reporter: me)
            }
        }
        .alert("Block \(conversation.otherUserName)?", isPresented: $showBlock) {
            Button("Cancel", role: .cancel) {}
            Button("Block", role: .destructive) {
                Task {
                    try? await services.reports.block(userId: conversation.otherUserId, named: conversation.otherUserName)
                    blocked = true
                }
            }
        } message: {
            Text("They won't be able to message you. You can manage blocked users in your profile.")
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(MortColor.stroke).frame(height: 1)
            HStack(spacing: MortSpacing.sm) {
                TextField("Message…", text: $draft, axis: .vertical)
                    .font(MortFont.body())
                    .foregroundStyle(MortColor.primaryText)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...4)
                    .padding(.horizontal, MortSpacing.md)
                    .padding(.vertical, 10)
                    .background(MortColor.surface)
                    .clipShape(.rect(cornerRadius: MortRadius.pill))
                    .overlay(RoundedRectangle(cornerRadius: MortRadius.pill).stroke(MortColor.stroke, lineWidth: 1))
                    .onChange(of: draft) { _, newValue in scan = SafetyScanner.scan(newValue) }

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MortColor.productionBlack)
                        .frame(width: 44, height: 44)
                        .background(canSend ? AnyShapeStyle(MortColor.roseGold) : AnyShapeStyle(MortColor.darkSilver))
                        .clipShape(Circle())
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, MortSpacing.md)
            .padding(.vertical, MortSpacing.sm)
            .background(MortColor.softBlack)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty && !scan.isBlocked && !sending && !blocked
    }

    private func load() async {
        messages = (try? await services.messages.fetchMessages(conversationId: conversation.id)) ?? []
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces)
        let result = SafetyScanner.scan(text)
        if result.isBlocked {
            scan = result
            return
        }
        sending = true
        do {
            let message = try await services.messages.sendMessage(conversationId: conversation.id, senderId: myId, text: text)
            messages.append(message)
            draft = ""
            scan = .safe
        } catch {
            scan = SafetyScanner.scan(text)
        }
        sending = false
    }
}

