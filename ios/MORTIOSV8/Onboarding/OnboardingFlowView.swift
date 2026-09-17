//
//  OnboardingFlowView.swift
//  MORT iOS V8 — Onboarding
//
//  Role-aware onboarding with progress, validation, back behavior and resume.
//  MORT does not collect information it doesn't need.
//

import SwiftUI

struct OnboardingFlowView: View {
    let user: MortUser

    @Environment(MortSession.self) private var session
    @Environment(\.mortReducedMotion) private var reducedMotion

    @State private var step = 0
    @State private var draft = MortProfileDraft()

    private var steps: [OnboardingStep] {
        switch user.role {
        case .teen: [.name, .area, .ageGroup, .categories, .guardian, .safetyPrimer, .review]
        case .adult: [.name, .area, .postingPrimer, .review]
        case .guardian: [.name, .area, .guardianPrimer, .review]
        }
    }

    private var current: OnboardingStep { steps[min(step, steps.count - 1)] }

    private var canAdvance: Bool {
        switch current {
        case .name: !draft.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        case .area: !draft.area.trimmingCharacters(in: .whitespaces).isEmpty
        case .ageGroup: !draft.ageGroup.isEmpty
        case .categories: !draft.categories.isEmpty
        case .guardian, .safetyPrimer, .postingPrimer, .guardianPrimer, .review: true
        }
    }

    var body: some View {
        MortScreen(atmosphereIntensity: 0.8, showsForegroundMeteors: current == .review) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                OnboardingProgress(step: step, total: steps.count)

                VStack(alignment: .leading, spacing: MortSpace.s2) {
                    Text(current.title(role: user.role))
                        .mortH1()
                        .fixedSize(horizontal: false, vertical: true)
                    Text(current.subtitle(role: user.role))
                        .mortBody()
                        .fixedSize(horizontal: false, vertical: true)
                }

                stepContent
                    .transition(reducedMotion ? .identity : .opacity)

                if let error = session.authError {
                    MortNote(text: error.userMessage, tone: .danger)
                }
            }
            .animation(reducedMotion ? nil : MortMotion.ease, value: step)
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: current == .review ? "Finish setup" : "Continue",
                    symbol: current == .review ? "checkmark" : nil,
                    isBusy: session.isWorking,
                    isEnabled: canAdvance
                ) {
                    advance()
                }
                if step > 0 {
                    MortQuietButton(title: "Back") {
                        withAnimation(MortMotion.respecting(reducedMotion, MortMotion.ease)) {
                            step -= 1
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch current {
        case .name:
            MortTextField(
                label: "Your name",
                placeholder: "First name and last initial",
                text: $draft.displayName,
                symbol: "person",
                helpText: "Others see this plus your @handle. We never show your full legal name."
            )
        case .area:
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortTextField(
                    label: "Your area",
                    placeholder: "Neighborhood or district",
                    text: $draft.area,
                    symbol: "mappin.and.ellipse",
                    helpText: "An approximate area only — MORT never shows your exact address."
                )
                MortNote(
                    text: "Exact addresses are shared privately, only after a job is accepted.",
                    tone: .info
                )
            }
        case .ageGroup:
            OnboardingChoiceGrid(
                options: ["13–14", "15–16", "17", "18+"],
                selection: Binding(
                    get: { draft.ageGroup.isEmpty ? [] : [draft.ageGroup] },
                    set: { draft.ageGroup = $0.first ?? "" }
                ),
                allowsMultiple: false
            )
        case .categories:
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                OnboardingChoiceGrid(
                    options: MortFixtures.categories,
                    selection: Binding(
                        get: { Set(draft.categories) },
                        set: { draft.categories = Array($0).sorted() }
                    ),
                    allowsMultiple: true
                )
                MortNote(text: "Pick as many as you like. You can change these any time.", tone: .neutral)
            }
        case .guardian:
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortTextField(
                    label: "Guardian email",
                    placeholder: "guardian@example.com",
                    text: $draft.guardianEmailInvite,
                    symbol: "person.2",
                    keyboard: .emailAddress,
                    capitalization: .never,
                    helpText: "We'll invite them to link to your account."
                )
                MortRestrictedState(
                    title: "What your guardian can see",
                    message: "They see your active jobs, check-ins, and a monthly earnings total. They can't read your messages, see exact locations, or see full payment details.",
                    symbol: "eye.trianglebadge.exclamationmark"
                )
            }
        case .safetyPrimer:
            VStack(spacing: MortSpace.s3) {
                OnboardingPoint(symbol: "shield.lefthalf.filled", title: "Check-ins", detail: "On longer jobs we'll nudge you to check in so someone always knows you're okay.")
                OnboardingPoint(symbol: "lock.shield", title: "Money is held first", detail: "A job can't start until the poster has funded it. You never work unpaid.")
                OnboardingPoint(symbol: "bubble.left.and.exclamationmark.bubble.right", title: "Report anything", detail: "One tap from any job or conversation. Safety reports jump the queue.")
            }
        case .postingPrimer:
            VStack(spacing: MortSpace.s3) {
                OnboardingPoint(symbol: "lock.shield", title: "You fund before work starts", detail: "MORT holds the money so your worker knows it's real. It's released after you confirm the job.")
                OnboardingPoint(symbol: "scalemass", title: "Fair Pay guardrails", detail: "We show what jobs like yours usually pay, and block offers that are too low.")
                OnboardingPoint(symbol: "hand.thumbsup", title: "Tips go 100% to the teen", detail: "MORT never takes a cut of a tip.")
            }
        case .guardianPrimer:
            VStack(spacing: MortSpace.s3) {
                OnboardingPoint(symbol: "person.2", title: "Link to your teen", detail: "Once linked, you'll see their active jobs and check-ins.")
                OnboardingPoint(symbol: "eye.trianglebadge.exclamationmark", title: "Privacy by design", detail: "You won't see message contents or exact locations. That's deliberate.")
                OnboardingPoint(symbol: "bell.badge", title: "Safety alerts first", detail: "If a check-in is missed or a report is filed, you hear about it.")
            }
        case .review:
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortCard {
                    VStack(spacing: MortSpace.s2) {
                        MortKeyValueRow(label: "NAME", value: draft.displayName)
                        MortDivider()
                        MortKeyValueRow(label: "AREA", value: draft.area)
                        if !draft.ageGroup.isEmpty {
                            MortDivider()
                            MortKeyValueRow(label: "AGE", value: draft.ageGroup)
                        }
                        if !draft.categories.isEmpty {
                            MortDivider()
                            MortKeyValueRow(label: "WORK", value: draft.categories.joined(separator: ", "))
                        }
                        if !draft.guardianEmailInvite.isEmpty {
                            MortDivider()
                            MortKeyValueRow(label: "GUARDIAN", value: draft.guardianEmailInvite)
                        }
                    }
                }
                MortNote(text: "You can change any of this later in Settings.", tone: .neutral)
            }
        }
    }

    private func advance() {
        if current == .review {
            Task { await session.completeOnboarding(with: draft) }
        } else {
            MortHaptic.tap()
            withAnimation(MortMotion.respecting(reducedMotion, MortMotion.ease)) {
                step += 1
            }
        }
    }
}

nonisolated enum OnboardingStep: Hashable, Sendable {
    case name, area, ageGroup, categories, guardian
    case safetyPrimer, postingPrimer, guardianPrimer, review

    func title(role: MortRole) -> String {
        switch self {
        case .name: "What should we call you?"
        case .area: "Where are you based?"
        case .ageGroup: "How old are you?"
        case .categories: "What kind of work?"
        case .guardian: "Invite your guardian"
        case .safetyPrimer: "How MORT keeps you safe"
        case .postingPrimer: "How paying works"
        case .guardianPrimer: "Your role as a guardian"
        case .review: "Looks right?"
        }
    }

    func subtitle(role: MortRole) -> String {
        switch self {
        case .name: "First name and last initial is plenty."
        case .area: "Just the neighborhood — never your exact address."
        case .ageGroup: "This helps us apply the right safety rules."
        case .categories: "We'll show you these jobs first."
        case .guardian: "Teen accounts need a linked guardian to be fully active."
        case .safetyPrimer: "Three things worth knowing before your first job."
        case .postingPrimer: "Three things worth knowing before your first post."
        case .guardianPrimer: "What you'll see, and what stays private."
        case .review: "You can change all of this later."
        }
    }
}

private struct OnboardingProgress: View {
    let step: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            HStack(spacing: MortSpace.s1) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? MortColor.silver2 : MortColor.graphite4)
                        .frame(height: 3)
                }
            }
            Text("STEP \(step + 1) OF \(total)")
                .mortEyebrow()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(total)")
    }
}

private struct OnboardingChoiceGrid: View {
    let options: [String]
    @Binding var selection: Set<String>
    let allowsMultiple: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: MortSpace.s2)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: MortSpace.s2) {
            ForEach(options, id: \.self) { option in
                MortChip(
                    label: option,
                    isSelected: selection.contains(option)
                ) {
                    if allowsMultiple {
                        if selection.contains(option) {
                            selection.remove(option)
                        } else {
                            selection.insert(option)
                        }
                    } else {
                        selection = [option]
                    }
                }
            }
        }
    }
}

private struct OnboardingPoint: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        MortCard {
            HStack(alignment: .top, spacing: MortSpace.s3) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MortColor.silver1)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: MortSpace.s1) {
                    Text(title).mortBodyStrong()
                    Text(detail)
                        .mortBody()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingFlowView(user: MortFixtures.teen)
        .environment(MortDependencies.preview().session)
        .environment(\.mort, MortDependencies.preview())
}
