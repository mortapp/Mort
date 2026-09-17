//
//  SafetyViews.swift
//  MORT iOS V8 — Safety
//
//  Safety UI NEVER fakes an emergency action. If alerting isn't wired, the
//  screen says so honestly and offers the real native emergency call instead.
//

import SwiftUI

struct SafetyCenterView: View {
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var checkIn: SafetyCheckIn?
    @State private var contacts: [SafetyContact] = []
    @State private var capability: SafetyCapabilityState = .available
    @State private var loaded = false

    var body: some View {
        MortScreen(atmosphereIntensity: 0.5) {
            VStack(alignment: .leading, spacing: MortSpace.s6) {
                VStack(alignment: .leading, spacing: MortSpace.s2) {
                    Text("Safety Center").mortH1()
                    Text("Everything here works whether or not anything is wrong.")
                        .mortBody()
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !loaded {
                    MortSkeletonList(rows: 3)
                } else {
                    if let notice = capability.notice {
                        MortStatusPanel(
                            tone: .warning,
                            symbol: "exclamationmark.triangle",
                            label: "LIMITED RIGHT NOW",
                            detail: notice
                        )
                    }

                    // Emergency is always the most reachable thing here.
                    Button {
                        nav.present(.emergency(jobId: checkIn?.jobId))
                    } label: {
                        HStack(spacing: MortSpace.s3) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 20, weight: .semibold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("I need help now")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Emergency options and your contacts")
                                    .font(MortFont.micro())
                                    .foregroundStyle(MortColor.ice2.opacity(0.8))
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(MortColor.ice2)
                        .padding(MortSpace.s4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                                .fill(MortColor.dangerDeep.opacity(0.55))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                                .strokeBorder(MortColor.danger.opacity(0.7), lineWidth: 1)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("I need help now. Opens emergency options.")

                    if let checkIn {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            MortSectionHeader(title: "Check-in")
                            CheckInPrompt(checkIn: checkIn) {
                                nav.push(.safetyCheckIn(checkIn.jobId))
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            MortSectionHeader(title: "Check-in")
                            MortCard {
                                MortNote(
                                    text: "No check-in scheduled. We'll set one up automatically on longer jobs.",
                                    tone: .neutral,
                                    symbol: "bell"
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "Your people", subtitle: "Who MORT can alert")
                        MortCard {
                            VStack(spacing: 0) {
                                if contacts.isEmpty {
                                    MortNote(
                                        text: "No safety contacts yet. Adding one means someone always knows where you are.",
                                        tone: .warning
                                    )
                                } else {
                                    ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                                        HStack(spacing: MortSpace.s3) {
                                            MortAvatar(
                                                initials: String(contact.displayName.prefix(2)).uppercased(),
                                                size: 34
                                            )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(contact.displayName).mortBodyStrong()
                                                Text("\(contact.relationship) · \(contact.contactMask)")
                                                    .mortMicro()
                                            }
                                            Spacer(minLength: MortSpace.s2)
                                            if contact.isGuardian {
                                                MortStatusPill(
                                                    tone: .info,
                                                    symbol: "person.2",
                                                    label: "Guardian",
                                                    compact: true
                                                )
                                            }
                                        }
                                        .padding(.vertical, MortSpace.s2)
                                        if index < contacts.count - 1 { MortDivider() }
                                    }
                                }
                            }
                        }
                        MortGhostButton(title: "Manage contacts", symbol: "person.2.badge.gearshape") {
                            nav.push(.safetyContacts)
                        }
                    }

                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "Report something")
                        MortCard {
                            VStack(spacing: 0) {
                                MortNavRow(
                                    title: "Report a person or job",
                                    detail: "Safety reports jump the queue",
                                    symbol: "flag",
                                    tone: .danger
                                ) {
                                    nav.present(.safetyReport(jobId: nil))
                                }
                                MortDivider()
                                MortNavRow(
                                    title: "Talk to MORT support",
                                    symbol: "headphones"
                                ) {
                                    nav.push(.supportHome)
                                }
                            }
                        }
                    }

                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            MortSectionHeader(title: "MORT's safety rules")
                            MortNote(text: "Never start a job that hasn't been funded.", tone: .neutral, symbol: "lock.shield")
                            MortNote(text: "Never share your address or phone number in chat.", tone: .neutral, symbol: "eye.slash")
                            MortNote(text: "Meet outside first if anything feels off.", tone: .neutral, symbol: "figure.walk")
                            MortNote(text: "You can leave any job, any time. Payment is handled fairly.", tone: .neutral, symbol: "arrow.left.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        .task {
            checkIn = try? await mort.safety.activeCheckIn()
            contacts = (try? await mort.safety.contacts()) ?? []
            capability = await mort.safety.capabilityState()
            loaded = true
        }
    }
}

struct SafetyCheckInView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var checkIn: SafetyCheckIn?
    @State private var isWorking = false
    @State private var confirmed = false
    @State private var error: MortError?

    var body: some View {
        MortScreen(
            title: confirmed ? "Thanks — you're checked in" : "Everything okay?",
            subtitle: confirmed
                ? "We've let your safety contacts know you're fine."
                : "A quick check-in tells your people you're safe.",
            atmosphereIntensity: 0.5
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error {
                    MortStatusPanel(
                        tone: .warning,
                        symbol: "exclamationmark.triangle",
                        label: "COULDN'T CHECK IN",
                        detail: error.userMessage
                    )
                }

                if let checkIn {
                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            Text(checkIn.jobTitle).mortTitle()
                            MortStatusPill(
                                tone: confirmed ? .success : checkIn.state.tone,
                                symbol: confirmed ? "checkmark.circle" : checkIn.state.symbol,
                                label: confirmed ? "CHECKED IN" : checkIn.state.label
                            )
                            Text(checkIn.dueText).mortMicro()
                        }
                    }
                }

                if !confirmed {
                    MortNote(
                        text: "If something isn't okay, use the report option instead. Nothing bad happens to you for speaking up.",
                        tone: .info
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                if confirmed {
                    MortPrimaryButton(title: "Done") { nav.pop() }
                } else {
                    MortPrimaryButton(
                        title: "I'm okay",
                        symbol: "checkmark.circle",
                        isBusy: isWorking
                    ) {
                        Task { await confirm() }
                    }
                    MortDangerButton(title: "Something's wrong", symbol: "exclamationmark.triangle") {
                        nav.present(.emergency(jobId: jobId))
                    }
                }
            }
        }
        .navigationTitle("Check in")
        .navigationBarTitleDisplayMode(.inline)
        .task { checkIn = try? await mort.safety.activeCheckIn() }
    }

    private func confirm() async {
        guard let id = checkIn?.id else { return }
        isWorking = true
        error = nil
        do {
            try await mort.safety.confirmCheckIn(id: id)
            confirmed = true
            MortHaptic.success()
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

/// Emergency. The alert is backend/native — never simulated. If MORT's alert
/// path isn't available, the native emergency call remains the real option.
struct EmergencyView: View {
    let jobId: String?

    @Environment(\.mort) private var mort
    @Environment(\.dismiss) private var dismiss
    @State private var alertState: AlertState = .idle
    @State private var contacts: [SafetyContact] = []

    enum AlertState: Equatable {
        case idle
        case sending
        case sent
        case unavailable(String)
    }

    var body: some View {
        ZStack {
            MortColor.black.ignoresSafeArea()
            MortAtmosphere(intensity: 0.25, allowShimmer: false)

            ScrollView {
                VStack(alignment: .leading, spacing: MortSpace.s5) {
                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text("Get help").mortH1()
                        Text("Pick what you need. Nothing here is a false alarm.")
                            .mortBody()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // The real native emergency path is always first and
                    // always works, regardless of MORT's backend state.
                    Button {
                        #if canImport(UIKit)
                        if let url = URL(string: "tel://911"), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        }
                        #endif
                    } label: {
                        HStack(spacing: MortSpace.s3) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 20, weight: .semibold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Call emergency services")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Opens your phone dialer")
                                    .font(MortFont.micro())
                                    .foregroundStyle(MortColor.ice2.opacity(0.85))
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(MortColor.ice2)
                        .padding(MortSpace.s4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                                .fill(MortColor.danger.opacity(0.85))
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Call emergency services")

                    MortCard {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            MortSectionHeader(
                                title: "Alert MORT and your contacts",
                                subtitle: "Sends your job details to our safety team"
                            )

                            switch alertState {
                            case .idle:
                                MortPrimaryButton(title: "Send a safety alert", symbol: "bell.badge") {
                                    Task { await sendAlert() }
                                }
                            case .sending:
                                MortPrimaryButton(title: "Sending…", isBusy: true) {}
                            case .sent:
                                MortStatusPanel(
                                    tone: .success,
                                    symbol: "checkmark.circle",
                                    label: "ALERT SENT",
                                    detail: "MORT's safety team has your job details and your contacts have been notified."
                                )
                            case .unavailable(let message):
                                // Honest failure — never a fake confirmation.
                                MortStatusPanel(
                                    tone: .danger,
                                    symbol: "exclamationmark.triangle",
                                    label: "ALERT NOT SENT",
                                    detail: "\(message) Use the emergency call above, or contact someone directly."
                                )
                            }
                        }
                    }

                    if !contacts.isEmpty {
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpace.s3) {
                                MortSectionHeader(title: "Your safety contacts")
                                ForEach(contacts) { contact in
                                    HStack(spacing: MortSpace.s3) {
                                        Image(systemName: contact.isGuardian ? "person.2.fill" : "person.fill")
                                            .foregroundStyle(MortColor.silver1)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(contact.displayName).mortBodyStrong()
                                            Text(contact.contactMask).mortMicro()
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: MortMetric.minTouchTarget)
                                }
                            }
                        }
                    }

                    MortNote(
                        text: "MORT can't dispatch emergency services. For an immediate emergency, always call directly.",
                        tone: .warning
                    )
                }
                .mortScreenPadding()
                .padding(.vertical, MortSpace.s5)
            }
        }
        .safeAreaInset(edge: .bottom) {
            MortBottomBar {
                MortGhostButton(title: "Close") { dismiss() }
            }
        }
        .task { contacts = (try? await mort.safety.contacts()) ?? [] }
    }

    private func sendAlert() async {
        alertState = .sending
        MortHaptic.warning()
        do {
            try await mort.safety.raiseEmergencyAlert(jobId: jobId)
            alertState = .sent
        } catch let error as MortError {
            alertState = .unavailable(error.userMessage)
        } catch {
            alertState = .unavailable(MortError.unknown.userMessage)
        }
    }
}

struct SafetyContactsView: View {
    @Environment(\.mort) private var mort
    @State private var contacts: LoadState<[SafetyContact]> = .idle

    var body: some View {
        MortScreen(
            title: "Safety contacts",
            subtitle: "People MORT can reach if something goes wrong.",
            atmosphereIntensity: 0.5
        ) {
            switch contacts {
            case .idle, .loading:
                MortSkeletonList(rows: 3)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let items), .offlineCache(let items):
                VStack(alignment: .leading, spacing: MortSpace.s4) {
                    if items.isEmpty {
                        MortEmptyState(
                            symbol: "person.2",
                            title: "No contacts yet",
                            message: "Add someone you trust. They're only contacted if there's a safety issue."
                        )
                    } else {
                        MortCard {
                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, contact in
                                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                                        HStack(spacing: MortSpace.s3) {
                                            MortAvatar(
                                                initials: String(contact.displayName.prefix(2)).uppercased(),
                                                size: 36
                                            )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(contact.displayName).mortBodyStrong()
                                                Text("\(contact.relationship) · \(contact.contactMask)")
                                                    .mortMicro()
                                            }
                                            Spacer(minLength: 0)
                                            if contact.isGuardian {
                                                MortStatusPill(
                                                    tone: .info, symbol: "person.2",
                                                    label: "Guardian", compact: true
                                                )
                                            }
                                        }
                                        if contact.isNotifiedOnJobs {
                                            MortNote(
                                                text: "Gets a heads-up when you start a job.",
                                                tone: .neutral,
                                                symbol: "bell"
                                            )
                                        }
                                    }
                                    .padding(.vertical, MortSpace.s2)
                                    if index < items.count - 1 { MortDivider() }
                                }
                            }
                        }
                    }
                    MortNote(
                        text: "Contact details are masked here for privacy. MORT stores the full details securely.",
                        tone: .info,
                        symbol: "lock.shield"
                    )
                }
            }
        }
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        contacts = .loading
        do {
            contacts = .loaded(try await mort.safety.contacts())
        } catch let error as MortError {
            contacts = .failed(error)
        } catch {
            contacts = .failed(.unknown)
        }
    }
}

struct SafetyReportView: View {
    let jobId: String?

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(\.dismiss) private var dismiss

    @State private var category: SafetyReportCategory = .unsafeBehavior
    @State private var detail = ""
    @State private var isWorking = false
    @State private var sent = false
    @State private var error: MortError?

    var body: some View {
        MortScreen(
            title: sent ? "Report received" : "Report a problem",
            subtitle: sent
                ? "MORT's safety team is looking at this."
                : "Tell us what happened. Safety reports are handled first.",
            atmosphereIntensity: 0.5
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if sent {
                    MortStatusPanel(
                        tone: .success,
                        symbol: "checkmark.shield",
                        label: "REPORT SENT",
                        detail: "We may contact you for more detail. The person you reported isn't told who reported them."
                    )
                } else {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text("WHAT HAPPENED").mortEyebrow()
                        VStack(spacing: MortSpace.s2) {
                            ForEach(SafetyReportCategory.allCases) { option in
                                MortChip(label: option.label, isSelected: category == option) {
                                    category = option
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    MortTextArea(
                        label: "Details",
                        placeholder: "What happened, and when?",
                        text: $detail,
                        minHeight: 140
                    )
                    MortNote(
                        text: "If you're in immediate danger, call emergency services first.",
                        tone: .danger,
                        symbol: "phone.fill"
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                if sent {
                    MortPrimaryButton(title: "Done") {
                        dismiss()
                        nav.dismissSheet()
                    }
                } else {
                    MortPrimaryButton(
                        title: "Send report",
                        isBusy: isWorking,
                        isEnabled: detail.count >= 10 && !isWorking
                    ) {
                        Task { await send() }
                    }
                    MortQuietButton(title: "Cancel") {
                        dismiss()
                        nav.dismissSheet()
                    }
                }
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() async {
        isWorking = true
        error = nil
        do {
            try await mort.safety.report(category: category, detail: detail, jobId: jobId)
            sent = true
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
    NavigationStack { SafetyCenterView(user: MortFixtures.teen) }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
