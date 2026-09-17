//
//  SettingsViews.swift
//  MORT iOS V8 — Settings
//
//  Settings, notifications, privacy, account and deletion.
//

import SwiftUI

struct SettingsView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(MortSession.self) private var session
    @Environment(MortSettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        return MortScreen(atmosphereIntensity: 0.45) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                Text("Settings").mortH1()

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "Account")
                    MortCard {
                        VStack(spacing: 0) {
                            MortNavRow(
                                title: user.displayName,
                                detail: user.handle,
                                symbol: "person.crop.circle"
                            ) {
                                nav.push(.editProfile)
                            }
                            MortDivider()
                            MortNavRow(title: "Account & security", symbol: "lock") {
                                nav.push(.accountSettings)
                            }
                            MortDivider()
                            MortNavRow(title: "Privacy", symbol: "hand.raised") {
                                nav.push(.privacySettings)
                            }
                            MortDivider()
                            MortNavRow(title: "Notifications", symbol: "bell") {
                                nav.push(.notificationSettings)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "Appearance & motion")
                    MortCard {
                        VStack(spacing: 0) {
                            MortToggleRow(
                                title: "Animated background",
                                detail: "The living MORT sky. Turn it off to save battery.",
                                symbol: "sparkles",
                                isOn: $settings.animatedBackground
                            )
                            MortDivider()
                            MortToggleRow(
                                title: "Reduce motion",
                                detail: "Keeps every state readable without animation.",
                                symbol: "figure.walk.motion",
                                isOn: $settings.reducedMotion
                            )
                        }
                    }
                    MortNote(
                        text: "MORT also follows your iPhone's Reduce Motion setting automatically.",
                        tone: .neutral
                    )
                }

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "Money")
                    MortCard {
                        VStack(spacing: 0) {
                            if user.role == .teen {
                                MortNavRow(title: "Payouts", symbol: "building.columns") {
                                    nav.push(.payoutStatus)
                                }
                                MortDivider()
                            } else {
                                MortNavRow(title: "Payment methods", symbol: "creditcard") {
                                    nav.push(.paymentMethods)
                                }
                                MortDivider()
                            }
                            MortNavRow(title: "Job & payment history", symbol: "clock.arrow.circlepath") {
                                nav.push(.history)
                            }
                            MortDivider()
                            MortNavRow(title: "Annual summary", symbol: "square.and.arrow.down") {
                                nav.push(.annualExport)
                            }
                            MortDivider()
                            MortNavRow(title: "How Fair Pay works", symbol: "scalemass") {
                                nav.push(.fairPayInfo)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "Safety & help")
                    MortCard {
                        VStack(spacing: 0) {
                            MortNavRow(title: "Safety Center", symbol: "shield.lefthalf.filled") {
                                nav.push(.safetyCenter)
                            }
                            MortDivider()
                            MortNavRow(title: "Safety contacts", symbol: "person.2") {
                                nav.push(.safetyContacts)
                            }
                            MortDivider()
                            MortNavRow(title: "Support", symbol: "headphones") {
                                nav.push(.supportHome)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortCard {
                        VStack(spacing: 0) {
                            MortNavRow(
                                title: "Sign out",
                                symbol: "rectangle.portrait.and.arrow.right"
                            ) {
                                Task { await session.signOut() }
                            }
                            MortDivider()
                            MortNavRow(
                                title: "Delete my account",
                                symbol: "trash",
                                tone: .danger
                            ) {
                                nav.push(.deleteAccount)
                            }
                        }
                    }

                    if mort.mode.isPreview {
                        MortNote(
                            text: "This build isn't connected to MORT's backend. Everything you see is preview data.",
                            tone: .warning,
                            symbol: "eye.trianglebadge.exclamationmark"
                        )
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSettingsView: View {
    @Environment(MortSettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        return MortScreen(
            title: "Notifications",
            subtitle: "Choose what MORT tells you about.",
            atmosphereIntensity: 0.45
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortCard {
                    VStack(spacing: 0) {
                        MortToggleRow(
                            title: "Jobs",
                            detail: "New jobs nearby, and updates on yours.",
                            symbol: "briefcase",
                            isOn: $settings.notifyJobs
                        )
                        MortDivider()
                        MortToggleRow(
                            title: "Messages",
                            detail: "When someone messages you.",
                            symbol: "bubble.left",
                            isOn: $settings.notifyMessages
                        )
                        MortDivider()
                        MortToggleRow(
                            title: "Payments",
                            detail: "Funding, settlement, tips and payouts.",
                            symbol: "creditcard",
                            isOn: $settings.notifyPayments
                        )
                        MortDivider()
                        MortToggleRow(
                            title: "Safety reminders",
                            detail: "Check-ins and safety alerts.",
                            symbol: "shield.lefthalf.filled",
                            isOn: $settings.safetyReminders
                        )
                    }
                }

                MortNote(
                    text: "Safety alerts about your own account are always delivered, even with reminders off.",
                    tone: .warning,
                    symbol: "exclamationmark.shield"
                )

                MortNote(
                    text: "You can also control MORT notifications in your iPhone's Settings app.",
                    tone: .neutral,
                    symbol: "gearshape"
                )
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        MortScreen(
            title: "Privacy",
            subtitle: "What MORT shows, and what it never shows.",
            atmosphereIntensity: 0.45
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "Always visible to others")
                        MortNote(text: "Your @handle and display name.", tone: .neutral, symbol: "person")
                        MortNote(text: "Your approximate area — never an exact address.", tone: .neutral, symbol: "mappin")
                        MortNote(text: "Your rating and number of completed jobs.", tone: .neutral, symbol: "star")
                    }
                }

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "Never shown to anyone")
                        MortNote(text: "Your full legal name.", tone: .success, symbol: "eye.slash")
                        MortNote(text: "Your phone number or email.", tone: .success, symbol: "eye.slash")
                        MortNote(text: "Your exact address.", tone: .success, symbol: "eye.slash")
                        MortNote(text: "Your full card or bank details.", tone: .success, symbol: "eye.slash")
                    }
                }

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "On receipts")
                        MortNote(
                            text: "Receipts use handles and masked references only, so they're safe to share or keep.",
                            tone: .neutral,
                            symbol: "doc.text"
                        )
                    }
                }

                MortRestrictedState(
                    title: "Guardian visibility",
                    message: "If you're a teen with a linked guardian, they see your active jobs, check-ins, safety alerts and a monthly earnings total — never your messages, exact locations or individual payment details.",
                    symbol: "person.2"
                )
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountSettingsView: View {
    let user: MortUser

    @Environment(MortNavigator.self) private var nav

    var body: some View {
        MortScreen(
            title: "Account & security",
            atmosphereIntensity: 0.45
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s4) {
                MortCard {
                    VStack(spacing: MortSpace.s2) {
                        MortKeyValueRow(label: "HANDLE", value: user.handle)
                        MortDivider()
                        MortKeyValueRow(label: "ROLE", value: user.role.displayName)
                        MortDivider()
                        MortKeyValueRow(label: "MEMBER SINCE", value: user.memberSince)
                        if user.guardianLinked {
                            MortDivider()
                            HStack {
                                Text("GUARDIAN").mortLabel()
                                Spacer(minLength: MortSpace.s2)
                                MortStatusPill(
                                    tone: .success,
                                    symbol: "checkmark.seal",
                                    label: "Linked",
                                    compact: true
                                )
                            }
                        }
                    }
                }

                MortCard {
                    VStack(spacing: 0) {
                        MortNavRow(title: "Change password", symbol: "key") {}
                        MortDivider()
                        MortNavRow(title: "Sign-in methods", symbol: "person.badge.key") {}
                    }
                }

                MortNote(
                    text: "MORT stores your session securely in the iPhone Keychain, never in plain storage.",
                    tone: .info,
                    symbol: "lock.shield"
                )

                MortQuietButton(title: "Delete my account", tone: .danger) {
                    nav.push(.deleteAccount)
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DeleteAccountView: View {
    @Environment(MortSession.self) private var session
    @Environment(MortNavigator.self) private var nav
    @State private var confirmText = ""
    @State private var isWorking = false

    var body: some View {
        MortScreen(
            title: "Delete your account",
            subtitle: "This can't be undone.",
            atmosphereIntensity: 0.4
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                MortStatusPanel(
                    tone: .danger,
                    symbol: "exclamationmark.triangle",
                    label: "WHAT HAPPENS",
                    detail: "Your profile, applications and messages are removed. Financial records like receipts are kept as long as the law requires, then deleted."
                )

                if let error = session.authError {
                    MortNote(text: error.userMessage, tone: .danger)
                }

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "Before you go")
                        MortNote(text: "Finish or cancel any active jobs first.", tone: .neutral, symbol: "briefcase")
                        MortNote(text: "Make sure pending payouts have landed.", tone: .neutral, symbol: "building.columns")
                        MortNote(text: "Export your annual summary if you want your records.", tone: .neutral, symbol: "square.and.arrow.down")
                    }
                }

                MortTextField(
                    label: "Type DELETE to confirm",
                    placeholder: "DELETE",
                    text: $confirmText,
                    symbol: "trash",
                    capitalization: .characters
                )
            }
        } bottom: {
            MortBottomBar {
                MortDangerButton(
                    title: "Permanently delete my account",
                    symbol: "trash",
                    isEnabled: confirmText == "DELETE" && !isWorking
                ) {
                    Task {
                        isWorking = true
                        _ = await session.deleteAccount()
                        isWorking = false
                    }
                }
                MortQuietButton(title: "Keep my account") { nav.pop() }
            }
        }
        .navigationTitle("Delete")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationsView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var notifications: LoadState<[MortNotification]> = .idle

    var body: some View {
        MortScreen(title: "Notifications", atmosphereIntensity: 0.5) {
            switch notifications {
            case .idle, .loading:
                MortSkeletonList(rows: 5)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let items), .offlineCache(let items):
                if items.isEmpty {
                    MortEmptyState(
                        symbol: "bell",
                        title: "Nothing new",
                        message: "Updates about jobs, payments and safety land here."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { note in
                            Button {
                                Task { try? await mort.notifications.markRead(id: note.id) }
                                if let route = note.route {
                                    nav.handleDeepLink(route)
                                }
                            } label: {
                                HStack(alignment: .top, spacing: MortSpace.s3) {
                                    ZStack {
                                        Circle()
                                            .fill(note.category.tone.dim)
                                            .frame(width: 34, height: 34)
                                        Image(systemName: note.category.symbol)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(note.category.tone.color)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(note.title)
                                            .mortBodyStrong()
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(note.body)
                                            .mortBody()
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(note.timeText).mortMicro()
                                    }
                                    Spacer(minLength: MortSpace.s2)
                                    if !note.isRead {
                                        Circle()
                                            .fill(MortColor.silver2)
                                            .frame(width: 8, height: 8)
                                            .padding(.top, 6)
                                    }
                                }
                                .padding(.vertical, MortSpace.s3)
                                .frame(minHeight: MortMetric.minTouchTarget)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(note.title). \(note.body). \(note.isRead ? "" : "Unread.")")
                            MortDivider()
                        }

                        MortQuietButton(title: "Mark all as read") {
                            Task {
                                try? await mort.notifications.markAllRead()
                                await load()
                            }
                        }
                        .padding(.top, MortSpace.s3)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        notifications = .loading
        do {
            notifications = .loaded(try await mort.notifications.notifications())
        } catch let error as MortError {
            notifications = .failed(error)
        } catch {
            notifications = .failed(.unknown)
        }
    }
}

#Preview {
    NavigationStack { SettingsView(user: MortFixtures.teen) }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortDependencies.preview().session)
        .environment(MortSettingsStore())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
