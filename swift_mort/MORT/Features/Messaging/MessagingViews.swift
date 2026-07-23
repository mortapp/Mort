import SwiftUI

struct MessageListView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var state: LoadState<[MessageThread]> = .idle
    @State private var people: [UUID: Profile] = [:]

    var body: some View {
        Group {
            switch state {
            case .idle, .loading: MortLoadingState(label: "Loading conversations")
            case let .failed(message): MortErrorState(message: message) { Task { await load() } }
            case let .loaded(threads) where threads.isEmpty:
                MortEmptyState(title: "No conversations yet", message: "A protected thread appears when a job and application create one.", systemImage: "bubble.left.and.bubble.right")
            case let .loaded(threads):
                List(threads) { thread in
                    Button { router.push(.messageThread(thread.id)) } label: {
                        threadRow(thread)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(MortColors.background)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .safeAreaInset(edge: .top) {
            MortSafetyBanner(message: "No ads appear in chat. Messages are sent through the backend safety scanner.")
                .padding(.horizontal, MortSpacing.md)
                .padding(.vertical, MortSpacing.xs)
                .background(MortColors.elevated)
        }
        .navigationTitle("Messages")
        .onAppear { Task { await load() } }
        .mortScreen()
    }

    private func threadRow(_ thread: MessageThread) -> some View {
        let person = counterpart(thread).flatMap { people[$0] }
        return MortCard {
            HStack(spacing: MortSpacing.md) {
                MortAvatar(displayName: person?.name ?? "MORT conversation")
                VStack(alignment: .leading, spacing: MortSpacing.xxs) {
                    Text(person?.name ?? "Protected conversation").font(MortTypography.label).foregroundStyle(MortColors.text)
                    Text(thread.jobID == nil ? "Application conversation" : "Job conversation")
                        .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                    Text(DateFormatting.displayDateTime(thread.updatedAt))
                        .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
                }
                Spacer()
                if thread.unread > 0 {
                    MortBadge(text: thread.unread == 1 ? "1 unread" : "\(thread.unread) unread", tint: MortColors.warning)
                        .accessibilityLabel("\(thread.unread) unread messages")
                }
                Image(systemName: "chevron.right").foregroundStyle(MortColors.textMuted)
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            let threads = try await container.messages.listThreads()
            state = .loaded(threads)
            var profiles: [UUID: Profile] = [:]
            for id in Set(threads.compactMap(counterpart)) {
                if let profile = try await container.profiles.profile(id: id) { profiles[id] = profile }
            }
            people = profiles
        } catch { state = .failed(mortMessage(error)) }
    }

    private func counterpart(_ thread: MessageThread) -> UUID? {
        let candidates = [thread.teenID, thread.adultID, thread.guardianID].compactMap { $0 }
        return candidates.first { $0 != session.userID }
    }
}

struct MessageThreadView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @Environment(Router.self) private var router
    @State private var messages: [MortMessage] = []
    @State private var thread: MessageThread?
    @State private var bodyText = ""
    @State private var isLoading = true
    @State private var isLoadingOlder = false
    @State private var hasOlder = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var confirmBlock = false
    let threadID: UUID

    var body: some View {
        VStack(spacing: 0) {
            MortSafetyBanner(message: "Keep chat in MORT. Phone numbers, social handles, exact addresses, and secrecy pressure can be blocked.")
                .padding(MortSpacing.sm)
            if isLoading {
                MortLoadingState(label: "Loading messages")
            } else if messages.isEmpty {
                MortEmptyState(title: "No messages yet", message: "Start with a safe, on-platform note.", systemImage: "bubble.left")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: MortSpacing.sm) {
                            if hasOlder {
                                Button(isLoadingOlder ? "Loading..." : "Load older messages") { Task { await loadOlder() } }
                                    .font(MortTypography.caption)
                                    .disabled(isLoadingOlder)
                            }
                            ForEach(messages) { message in
                                MessageBubble(message: message, isMine: message.senderID == session.userID) {
                                    router.push(.report(.message(message.id)))
                                }
                                .id(message.id)
                            }
                        }
                        .padding(MortSpacing.md)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last { withAnimation(MortAnimation.standard) { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onAppear {
                        if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            composer
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { threadToolbar }
        .task { await initialLoad() }
        .task {
            for await _ in container.messages.changes(threadID: threadID) {
                guard !Task.isCancelled else { break }
                await refreshLatest()
            }
        }
        .confirmationDialog("Block this participant?", isPresented: $confirmBlock) {
            Button("Block", role: .destructive) { Task { await blockCounterpart() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Blocking stops protected interactions between these accounts. You can unblock later in Safety settings.") }
        .alert("Conversation error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .mortScreen()
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: MortSpacing.sm) {
            TextField("Message", text: $bodyText, axis: .vertical)
                .lineLimit(1...4)
                .padding(MortSpacing.sm)
                .background(MortColors.cardAlternate)
                .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
            Button { Task { await send() } } label: {
                if isSending { ProgressView().tint(MortColors.background) }
                else { Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)) }
            }
            .frame(width: 44, height: 44)
            .background(MortColors.neon, in: RoundedRectangle(cornerRadius: MortRadius.medium))
            .foregroundStyle(MortColors.background)
            .disabled(isSending || bodyText.trimmed.isEmpty || bodyText.count > 2_000)
            .accessibilityLabel("Send message")
        }
        .padding(MortSpacing.sm)
        .background(MortColors.elevated)
        .overlay(alignment: .top) { Rectangle().fill(MortColors.line).frame(height: 1) }
    }

    @ToolbarContentBuilder
    private var threadToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let counterpartID { Button("Report participant", systemImage: "flag") { router.push(.report(.user(counterpartID))) } }
                Button("Block participant", systemImage: "hand.raised.fill", role: .destructive) { confirmBlock = true }
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("Conversation safety actions")
        }
    }

    private var counterpartID: UUID? {
        guard let thread else { return nil }
        return [thread.teenID, thread.adultID, thread.guardianID].compactMap { $0 }.first { $0 != session.userID }
    }

    private func initialLoad() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let threads = try await container.messages.listThreads()
            thread = threads.first { $0.id == threadID }
            messages = try await container.messages.listMessages(threadID: threadID, before: nil, limit: 50)
            hasOlder = messages.count == 50
            try await container.messages.markRead(threadID: threadID)
        } catch { errorMessage = mortMessage(error) }
    }

    private func refreshLatest() async {
        do {
            let latest = try await container.messages.listMessages(threadID: threadID, before: nil, limit: 50)
            let earlier = messages.filter { old in !latest.contains(where: { $0.id == old.id }) }
            messages = (earlier + latest).sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
            try await container.messages.markRead(threadID: threadID)
        } catch { errorMessage = mortMessage(error) }
    }

    private func loadOlder() async {
        guard !isLoadingOlder, let before = messages.first?.createdAt else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let older = try await container.messages.listMessages(threadID: threadID, before: before, limit: 50)
            messages = older + messages
            hasOlder = older.count == 50
        } catch { errorMessage = mortMessage(error) }
    }

    private func send() async {
        let clean = bodyText.trimmed
        guard !clean.isEmpty else { return }
        guard clean.count <= 2_000 else { errorMessage = "Keep messages under 2,000 characters."; return }
        isSending = true
        defer { isSending = false }
        do {
            let message = try await container.messages.send(threadID: threadID, body: clean)
            bodyText = ""
            if !messages.contains(where: { $0.id == message.id }) { messages.append(message) }
            try await container.messages.markRead(threadID: threadID)
        } catch {
            errorMessage = mortMessage(error)
            await refreshLatest()
        }
    }

    private func blockCounterpart() async {
        guard let counterpartID else { errorMessage = "The other participant could not be identified."; return }
        do { try await container.safety.block(userID: counterpartID); errorMessage = "Participant blocked. Messaging is now unavailable." }
        catch { errorMessage = mortMessage(error) }
    }
}

private struct MessageBubble: View {
    let message: MortMessage
    let isMine: Bool
    let report: () -> Void

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 56) }
            VStack(alignment: .leading, spacing: MortSpacing.xs) {
                HStack {
                    MortBadge(text: message.scannerStatus, tint: scannerTint)
                    Spacer()
                    Button(action: report) { Image(systemName: "flag").font(.caption) }
                        .accessibilityLabel("Report message")
                }
                Text(message.isBlocked ? "Blocked by safety scanner" : message.body)
                    .foregroundStyle(MortColors.text)
                if let reason = message.scannerReason {
                    Text(reason).font(MortTypography.caption).foregroundStyle(MortColors.warning)
                }
                Text(DateFormatting.displayDateTime(message.createdAt))
                    .font(MortTypography.caption).foregroundStyle(MortColors.textMuted)
            }
            .padding(MortSpacing.sm)
            .background(message.isBlocked ? MortColors.danger.opacity(0.12) : isMine ? MortColors.neonDeep : MortColors.card)
            .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
            if !isMine { Spacer(minLength: 56) }
        }
    }

    private var scannerTint: Color {
        if message.isBlocked { return MortColors.danger }
        if message.isFlagged { return MortColors.warning }
        return MortColors.neon
    }
}
