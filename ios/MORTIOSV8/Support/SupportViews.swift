//
//  SupportViews.swift
//  MORT iOS V8 — Support
//
//  Support never exposes internal moderation, security or risk detail to the
//  user. Assisted answers are labeled as such; human escalation is explicit.
//

import SwiftUI

struct SupportHomeView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var cases: LoadState<[SupportCase]> = .idle

    var body: some View {
        MortScreen(
            title: "Support",
            subtitle: "Real people, and quick answers when that's faster.",
            atmosphereIntensity: 0.55
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "What do you need help with?")
                    MortCard {
                        VStack(spacing: 0) {
                            ForEach(Array(SupportTopic.standard.enumerated()), id: \.element.id) { index, topic in
                                MortNavRow(
                                    title: topic.title,
                                    detail: topic.detail,
                                    symbol: topic.symbol,
                                    tone: topic.isSafety ? .danger : nil
                                ) {
                                    nav.push(.supportNewCase(topicId: topic.id, reference: nil))
                                }
                                if index < SupportTopic.standard.count - 1 { MortDivider() }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "Your conversations")
                    switch cases {
                    case .idle, .loading:
                        MortSkeletonList(rows: 3)
                    case .failed(let error):
                        MortErrorState(message: error.userMessage) { Task { await load() } }
                    case .loaded(let items), .offlineCache(let items):
                        if items.isEmpty {
                            MortEmptyState(
                                symbol: "bubble.left.and.bubble.right",
                                title: "Nothing open",
                                message: "When you contact support, the conversation lives here."
                            )
                        } else {
                            MortCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                        Button {
                                            nav.push(.supportCase(item.id))
                                        } label: {
                                            HStack(alignment: .top, spacing: MortSpace.s3) {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(item.subject)
                                                        .mortBodyStrong()
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                    Text(item.lastMessagePreview)
                                                        .mortMicro()
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                    HStack(spacing: MortSpace.s2) {
                                                        MortStatusPill(
                                                            tone: item.state.tone,
                                                            symbol: item.state.symbol,
                                                            label: item.state.label,
                                                            compact: true
                                                        )
                                                        Text(item.updatedText).mortMicro()
                                                    }
                                                }
                                                Spacer(minLength: MortSpace.s2)
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(MortColor.textMuted)
                                            }
                                            .padding(.vertical, MortSpace.s3)
                                            .frame(minHeight: MortMetric.minTouchTarget)
                                            .contentShape(.rect)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityElement(children: .combine)
                                        if index < items.count - 1 { MortDivider() }
                                    }
                                }
                            }
                        }
                    }
                }

                MortNote(
                    text: "MORT support will never ask for your password, full card number, or a verification code.",
                    tone: .warning,
                    symbol: "exclamationmark.shield"
                )
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        cases = .loading
        do {
            cases = .loaded(try await mort.support.cases())
        } catch let error as MortError {
            cases = .failed(error)
        } catch {
            cases = .failed(.unknown)
        }
    }
}

struct SupportTopicPickerView: View {
    @Environment(MortNavigator.self) private var nav
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MortScreen(title: "Contact support", atmosphereIntensity: 0.55) {
            MortCard {
                VStack(spacing: 0) {
                    ForEach(Array(SupportTopic.standard.enumerated()), id: \.element.id) { index, topic in
                        MortNavRow(
                            title: topic.title,
                            detail: topic.detail,
                            symbol: topic.symbol,
                            tone: topic.isSafety ? .danger : nil
                        ) {
                            dismiss()
                            nav.dismissSheet()
                            nav.push(.supportNewCase(topicId: topic.id, reference: nil))
                        }
                        if index < SupportTopic.standard.count - 1 { MortDivider() }
                    }
                }
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                    nav.dismissSheet()
                }
                .foregroundStyle(MortColor.textSecondary)
            }
        }
    }
}

struct SupportNewCaseView: View {
    let topicId: String
    let reference: String?

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var subject = ""
    @State private var detail = ""
    @State private var isWorking = false
    @State private var error: MortError?
    @State private var created: SupportCase?

    private var topic: SupportTopic? {
        SupportTopic.standard.first { $0.id == topicId }
    }

    var body: some View {
        MortScreen(
            title: created == nil ? (topic?.title ?? "Contact support") : "We've got it",
            subtitle: created == nil
                ? (topic?.isSafety == true
                    ? "Safety issues are handled first. Tell us what happened."
                    : "Give us the details and we'll take it from there.")
                : "You'll get a reply in this conversation.",
            atmosphereIntensity: 0.55
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let created {
                    MortStatusPanel(
                        tone: created.state.tone,
                        symbol: created.state.symbol,
                        label: created.state.label,
                        detail: "We'll reply here. If it's urgent and about safety, use the Safety Center."
                    )
                } else {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    if topic?.isSafety == true {
                        MortStatusPanel(
                            tone: .danger,
                            symbol: "shield.lefthalf.filled",
                            label: "SAFETY PRIORITY",
                            detail: "This goes to the front of the queue. If you're in immediate danger, call emergency services first."
                        )
                    }
                    MortTextField(
                        label: "Subject",
                        placeholder: "A short summary",
                        text: $subject,
                        symbol: "text.alignleft"
                    )
                    MortTextArea(
                        label: "What's happening",
                        placeholder: "Include dates and receipt or order numbers if you have them.",
                        text: $detail,
                        minHeight: 150
                    )
                    if let reference {
                        MortCard { MortCopyRow(label: "Attached reference", value: reference) }
                    }
                }
            }
        } bottom: {
            MortBottomBar {
                if let created {
                    MortPrimaryButton(title: "Open the conversation", symbol: "bubble.left") {
                        nav.push(.supportCase(created.id))
                    }
                    MortQuietButton(title: "Done") { nav.popToRoot() }
                } else {
                    MortPrimaryButton(
                        title: "Send to support",
                        isBusy: isWorking,
                        isEnabled: subject.count >= 3 && detail.count >= 10 && !isWorking
                    ) {
                        Task { await send() }
                    }
                }
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() async {
        isWorking = true
        error = nil
        do {
            created = try await mort.support.openCase(
                topicId: topicId, subject: subject, detail: detail, reference: reference
            )
            MortHaptic.success()
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

struct SupportCaseView: View {
    let caseId: String

    @Environment(\.mort) private var mort
    @State private var messages: LoadState<[MortMessage]> = .idle
    @State private var supportCase: SupportCase?
    @State private var draft = ""
    @State private var isSending = false
    @State private var requestedHuman = false

    var body: some View {
        MortScreen(atmosphereIntensity: 0.45, scrolls: false) {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                if let supportCase {
                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text(supportCase.subject)
                            .mortH2()
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: MortSpace.s2) {
                            MortStatusPill(
                                tone: supportCase.state.tone,
                                symbol: supportCase.state.symbol,
                                label: supportCase.state.label,
                                compact: true
                            )
                            if !supportCase.withHumanAgent {
                                MortStatusPill(
                                    tone: .neutral,
                                    symbol: "sparkles",
                                    label: "Assisted answer",
                                    compact: true
                                )
                            }
                        }
                        if let reference = supportCase.reference {
                            MortCopyRow(label: "Reference", value: reference)
                        }
                    }
                }

                switch messages {
                case .idle, .loading:
                    MortSkeletonList(rows: 3)
                    Spacer()
                case .failed(let error):
                    MortErrorState(message: error.userMessage) { Task { await load() } }
                    Spacer()
                case .loaded(let items), .offlineCache(let items):
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: MortSpace.s3) {
                            ForEach(items) { message in
                                HStack(alignment: .top, spacing: MortSpace.s3) {
                                    if !message.fromMe {
                                        Image(systemName: "shield.lefthalf.filled")
                                            .font(.system(size: 13))
                                            .foregroundStyle(MortColor.silver1)
                                            .frame(width: 22)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(message.fromMe ? "You" : message.authorDisplayName)
                                            .mortEyebrow()
                                        Text(message.body)
                                            .mortBody()
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(message.timeText).mortMicro()
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(MortSpace.s3)
                                .background {
                                    RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                                        .fill(message.fromMe ? MortColor.graphite3.opacity(0.7) : MortColor.cardBg2)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(.vertical, MortSpace.s2)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        } bottom: {
            MortBottomBar {
                HStack(spacing: MortSpace.s2) {
                    TextField("Reply", text: $draft, axis: .vertical)
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
                        .accessibilityLabel("Reply to support")

                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MortColor.ink1)
                            .frame(width: MortMetric.minTouchTarget, height: MortMetric.minTouchTarget)
                            .background { Circle().fill(MortColor.silver2) }
                            .opacity(draft.isEmpty || isSending ? 0.38 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft.isEmpty || isSending)
                    .accessibilityLabel("Send reply")
                }

                if !requestedHuman, supportCase?.withHumanAgent == false {
                    MortQuietButton(title: "Talk to a person instead", symbol: "person.wave.2") {
                        Task {
                            try? await mort.support.requestHuman(caseId: caseId)
                            requestedHuman = true
                        }
                    }
                } else if requestedHuman {
                    MortNote(text: "A MORT team member will pick this up.", tone: .info)
                }
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        messages = .loading
        supportCase = (try? await mort.support.cases())?.first { $0.id == caseId }
        do {
            messages = .loaded(try await mort.support.messages(caseId: caseId))
        } catch let error as MortError {
            messages = .failed(error)
        } catch {
            messages = .failed(.unknown)
        }
    }

    private func send() async {
        isSending = true
        let body = draft
        draft = ""
        do {
            let sent = try await mort.support.reply(caseId: caseId, body: body)
            messages = .loaded((messages.value ?? []) + [sent])
        } catch {
            draft = body
        }
        isSending = false
    }
}

#Preview {
    NavigationStack { SupportHomeView() }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
