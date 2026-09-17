//
//  GuardianViews.swift
//  MORT iOS V8 — Guardian
//
//  Guardians see approved, policy-limited information only. Message contents,
//  exact locations and full payment identifiers are deliberately NOT exposed,
//  and the UI says so out loud rather than hiding the boundary.
//

import SwiftUI

struct GuardianHomeView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var teens: LoadState<[MortUser]> = .idle

    var body: some View {
        MortScreen(atmosphereIntensity: 0.6) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                VStack(alignment: .leading, spacing: MortSpace.s2) {
                    Text("Your teens").mortH1()
                    Text("What they're working on, and whether they're okay.")
                        .mortBody()
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch teens {
                case .idle, .loading:
                    MortSkeletonList(rows: 2)
                case .failed(let error):
                    MortErrorState(message: error.userMessage) { Task { await load() } }
                case .loaded(let items), .offlineCache(let items):
                    if items.isEmpty {
                        MortEmptyState(
                            symbol: "person.2",
                            title: "No teen linked yet",
                            message: "Invite your teen, or enter the link code from their account.",
                            actionTitle: "Invite a teen"
                        ) {
                            nav.present(.guardianInvite)
                        }
                    } else {
                        VStack(spacing: MortSpace.s3) {
                            ForEach(items) { teen in
                                Button {
                                    nav.push(.guardianTeen(teen.id))
                                } label: {
                                    MortCard {
                                        HStack(spacing: MortSpace.s3) {
                                            MortAvatar(initials: teen.avatarInitials, size: 46)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(teen.displayName).mortTitle()
                                                Text(teen.handle).mortMicro()
                                                MortRatingView(
                                                    rating: teen.rating,
                                                    completedJobs: teen.completedJobs
                                                )
                                            }
                                            Spacer(minLength: MortSpace.s2)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(MortColor.textMuted)
                                        }
                                    }
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .combine)
                            }
                            MortGhostButton(title: "Link another teen", symbol: "plus") {
                                nav.present(.guardianInvite)
                            }
                        }
                    }
                }

                MortRestrictedState(
                    title: "What you can and can't see",
                    message: "You see active jobs, check-ins, safety alerts and a monthly earnings total. You don't see message contents, exact locations, or full payment details — that's deliberate, and your teen knows the same rules.",
                    symbol: "eye.trianglebadge.exclamationmark"
                )
            }
        }
        .navigationTitle("")
        .toolbar { dashboardToolbar(unread: 0, nav: nav) }
        .task { if case .idle = teens { await load() } }
        .refreshable { await load() }
    }

    private func load() async {
        teens = .loading
        do {
            teens = .loaded(try await mort.guardians.linkedTeens())
        } catch let error as MortError {
            teens = .failed(error)
        } catch {
            teens = .failed(.unknown)
        }
    }
}

struct GuardianTeenDetailView: View {
    let teenId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var summary: LoadState<GuardianSummary> = .idle

    var body: some View {
        MortScreen(atmosphereIntensity: 0.6) {
            switch summary {
            case .idle, .loading:
                MortSkeletonList(rows: 4)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let value), .offlineCache(let value):
                VStack(alignment: .leading, spacing: MortSpace.s5) {
                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text(value.teenDisplayName).mortH1()
                        Text(value.teenHandle).mortLabel()
                    }

                    if value.safetyAlertsCount > 0 {
                        MortStatusPanel(
                            tone: .danger,
                            symbol: "exclamationmark.triangle",
                            label: "\(value.safetyAlertsCount) SAFETY ALERT\(value.safetyAlertsCount == 1 ? "" : "S")",
                            detail: "Open the Safety Center for detail on what happened."
                        )
                    }

                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            MortSectionHeader(title: "Right now")
                            MortKeyValueRow(
                                label: "ACTIVE JOBS",
                                value: "\(value.activeJobCount)"
                            )
                            MortDivider()
                            MortKeyValueRow(
                                label: "NEXT JOB",
                                value: value.upcomingJobTitle ?? "Nothing scheduled"
                            )
                            MortDivider()
                            HStack {
                                Text("LAST CHECK-IN").mortLabel()
                                Spacer(minLength: MortSpace.s2)
                                MortStatusPill(
                                    tone: value.lastCheckInState.tone,
                                    symbol: value.lastCheckInState.symbol,
                                    label: value.lastCheckInState.label,
                                    compact: true
                                )
                            }
                            if !value.lastCheckInText.isEmpty {
                                Text(value.lastCheckInText).mortMicro()
                            }
                        }
                    }

                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            MortSectionHeader(
                                title: "Earnings this month",
                                subtitle: "Approved summary only"
                            )
                            Text(value.earningsThisMonth.formatted)
                                .font(MortFont.money(32, weight: .light))
                                .foregroundStyle(MortColor.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            HStack {
                                Text("PAYOUTS").mortLabel()
                                Spacer(minLength: MortSpace.s2)
                                MortStatusPill(
                                    tone: value.payoutStage.tone,
                                    symbol: value.payoutStage.symbol,
                                    label: value.payoutStage.label,
                                    compact: true
                                )
                            }
                            MortNote(
                                text: "You see the total, not individual payment details.",
                                tone: .neutral,
                                symbol: "eye.slash"
                            )
                        }
                    }

                    MortRestrictedState(
                        title: "Private to your teen",
                        message: value.restrictedNotice,
                        symbol: "lock.shield"
                    )

                    VStack(spacing: MortSpace.s2) {
                        MortGhostButton(title: "Safety Center", symbol: "shield.lefthalf.filled") {
                            nav.push(.safetyCenter)
                        }
                        MortQuietButton(title: "Unlink this teen", tone: .danger) {
                            Task {
                                try? await mort.guardians.unlink(teenId: teenId)
                                nav.pop()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Teen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        summary = .loading
        do {
            summary = .loaded(try await mort.guardians.teenSummary(teenId: teenId))
        } catch let error as MortError {
            summary = .failed(error)
        } catch {
            summary = .failed(.unknown)
        }
    }
}

struct GuardianInviteView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var mode: Mode = .invite
    @State private var isWorking = false
    @State private var error: MortError?
    @State private var done = false

    enum Mode: String, CaseIterable, Identifiable {
        case invite, code
        var id: String { rawValue }
        var label: String {
            switch self {
            case .invite: "Send an invite"
            case .code: "Enter a code"
            }
        }
    }

    var body: some View {
        MortScreen(
            title: done ? "Invite sent" : "Link a teen",
            subtitle: done
                ? "Once they accept, you'll see their jobs and check-ins."
                : "Either send them an invite, or enter the code from their account.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if done {
                    MortStatusPanel(
                        tone: .success,
                        symbol: "paperplane",
                        label: "SENT",
                        detail: "We've let them know. Nothing is shared with you until they accept."
                    )
                } else {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    HStack(spacing: MortSpace.s2) {
                        ForEach(Mode.allCases) { option in
                            MortChip(label: option.label, isSelected: mode == option) {
                                mode = option
                            }
                        }
                    }

                    if mode == .invite {
                        MortTextField(
                            label: "Teen's email",
                            placeholder: "them@example.com",
                            text: $email,
                            symbol: "envelope",
                            keyboard: .emailAddress,
                            capitalization: .never
                        )
                    } else {
                        MortTextField(
                            label: "Link code",
                            placeholder: "6 characters",
                            text: $code,
                            symbol: "number",
                            capitalization: .characters,
                            helpText: "They'll find this in Settings on their account."
                        )
                    }

                    MortRestrictedState(
                        title: "Linking is not surveillance",
                        message: "Your teen can see exactly what you can see. Messages, exact locations and full payment details stay private to them.",
                        symbol: "eye.trianglebadge.exclamationmark"
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                if done {
                    MortPrimaryButton(title: "Done") {
                        dismiss()
                        nav.dismissSheet()
                    }
                } else {
                    MortPrimaryButton(
                        title: mode == .invite ? "Send invite" : "Link account",
                        isBusy: isWorking,
                        isEnabled: mode == .invite ? email.contains("@") : code.count >= 4
                    ) {
                        Task { await submit() }
                    }
                }
            }
        }
        .navigationTitle("Link")
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

    private func submit() async {
        isWorking = true
        error = nil
        do {
            if mode == .invite {
                try await mort.guardians.inviteTeen(email: email)
            } else {
                try await mort.guardians.acceptLink(code: code)
            }
            done = true
            MortHaptic.success()
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

#Preview {
    NavigationStack { GuardianHomeView(user: MortFixtures.guardian) }
        .environment(\.mort, MortDependencies.preview(user: MortFixtures.guardian))
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
