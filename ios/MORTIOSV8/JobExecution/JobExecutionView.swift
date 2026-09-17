//
//  JobExecutionView.swift
//  MORT iOS V8 — Job Execution
//
//  Start (PIN handshake), do the work, submit proof, mark complete.
//  A job cannot start unless the backend says it is FUNDED.
//

import SwiftUI

struct JobStartPinView: View {
    let jobId: String
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var issuedPin: String?
    @State private var isWorking = false
    @State private var error: MortError?
    @State private var started = false

    private var isPoster: Bool { user.role == .adult }

    var body: some View {
        MortScreen(
            title: started ? "Job started" : (isPoster ? "Your start code" : "Enter the start code"),
            subtitle: started
                ? "The clock is running. Stay safe and check in if we ask."
                : (isPoster
                    ? "Read this to your worker when they arrive. It confirms they're really there."
                    : "Ask the person who posted the job for their 4-digit code."),
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if started {
                    MortStatusPanel(
                        tone: .success,
                        symbol: "play.circle",
                        label: "IN PROGRESS",
                        detail: "MORT is holding the payment. It's released once the work is confirmed."
                    )
                } else if isPoster {
                    MortCard {
                        VStack(spacing: MortSpace.s3) {
                            Text("START CODE").mortEyebrow()
                            Text(issuedPin ?? "––––")
                                .font(MortFont.money(46, weight: .light))
                                .tracking(8)
                                .foregroundStyle(MortColor.textPrimary)
                            Text("Only share this in person.")
                                .mortMicro()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    MortNote(
                        text: "Never send the code by message. Handing it over in person is what makes it meaningful.",
                        tone: .warning
                    )
                } else {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    MortTextField(
                        label: "Start code",
                        placeholder: "4 digits",
                        text: $pin,
                        symbol: "number",
                        keyboard: .numberPad
                    )
                    MortNote(
                        text: "If they can't give you a code, don't start the job. Report it instead.",
                        tone: .info
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                if started {
                    MortPrimaryButton(title: "Done") { dismiss() }
                } else if isPoster {
                    MortPrimaryButton(title: "Close") { dismiss() }
                } else {
                    MortPrimaryButton(
                        title: "Start the job",
                        symbol: "play.fill",
                        isBusy: isWorking,
                        isEnabled: pin.count == 4 && !isWorking
                    ) {
                        Task { await start() }
                    }
                    MortQuietButton(title: "Something's wrong", tone: .danger) {
                        dismiss()
                        nav.present(.safetyReport(jobId: jobId))
                    }
                }
            }
        }
        .navigationTitle("Start job")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundStyle(MortColor.textSecondary)
            }
        }
        .task {
            if isPoster { issuedPin = try? await mort.execution.startPin(jobId: jobId) }
        }
    }

    private func start() async {
        isWorking = true
        error = nil
        do {
            try await mort.execution.startJob(jobId: jobId, pin: pin)
            started = true
            MortHaptic.success()
        } catch let failure as MortError {
            error = failure
            MortHaptic.failure()
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

struct JobExecutionView: View {
    let jobId: String
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var job: LoadState<MortJob> = .idle
    @State private var checkIn: SafetyCheckIn?
    @State private var isWorking = false

    var body: some View {
        MortScreen(
            title: "Finishing up",
            subtitle: "Wrap up the job so you can get paid.",
            atmosphereIntensity: 0.65
        ) {
            switch job {
            case .idle, .loading:
                MortSkeletonList(rows: 3)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let value), .offlineCache(let value):
                VStack(alignment: .leading, spacing: MortSpace.s5) {
                    JobContextStrip(
                        title: value.title,
                        orderNumber: value.orderNumber,
                        counterpartyHandle: value.posterHandle
                    )

                    MortStatusPanel(
                        tone: .success,
                        symbol: "lock.shield",
                        label: "PAYMENT IS HELD",
                        detail: "\(value.basePay.formatted) is held by MORT for this job. You'll be paid after it's confirmed."
                    )

                    if let checkIn, checkIn.state != .confirmed {
                        CheckInPrompt(checkIn: checkIn) {
                            nav.push(.safetyCheckIn(jobId))
                        }
                    }

                    if value.requiresProof {
                        MortCard {
                            VStack(alignment: .leading, spacing: MortSpace.s3) {
                                MortSectionHeader(
                                    title: "Proof needed",
                                    subtitle: "This poster asked for a photo or note"
                                )
                                MortPrimaryButton(title: "Add proof", symbol: "camera") {
                                    nav.push(.jobProof(jobId))
                                }
                            }
                        }
                    }

                    VStack(spacing: MortSpace.s2) {
                        MortNavRow(title: "Message the poster", symbol: "bubble.left") {
                            nav.push(.conversation(MortFixtures.conversations[0].id))
                        }
                        MortDivider()
                        MortNavRow(title: "Safety Center", symbol: "shield.lefthalf.filled") {
                            nav.push(.safetyCenter)
                        }
                        MortDivider()
                        MortNavRow(title: "Report a problem", symbol: "flag", tone: .danger) {
                            nav.present(.safetyReport(jobId: jobId))
                        }
                    }
                }
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "I've finished the work",
                    symbol: "checkmark.circle",
                    isBusy: isWorking
                ) {
                    Task { await markComplete() }
                }
                MortNote(
                    text: "The poster confirms next. MORT decides the final amount from what's confirmed.",
                    tone: .neutral
                )
            }
        }
        .navigationTitle("Job")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        job = .loading
        do {
            job = .loaded(try await mort.jobs.job(id: jobId))
            checkIn = try? await mort.safety.activeCheckIn()
        } catch let error as MortError {
            job = .failed(error)
        } catch {
            job = .failed(.unknown)
        }
    }

    private func markComplete() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await mort.execution.markComplete(jobId: jobId)
            MortHaptic.success()
            nav.popToRoot()
        } catch {
            MortHaptic.failure()
        }
    }
}

struct JobProofView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var note = ""
    @State private var attachments: [String] = []
    @State private var isWorking = false
    @State private var error: MortError?

    var body: some View {
        MortScreen(
            title: "Add proof",
            subtitle: "A quick photo and note is usually plenty.",
            atmosphereIntensity: 0.65
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error {
                    MortNote(text: error.userMessage, tone: .danger)
                }

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "Photos")
                        if attachments.isEmpty {
                            Text("No photos added yet.").mortMicro()
                        } else {
                            ForEach(attachments, id: \.self) { name in
                                HStack(spacing: MortSpace.s2) {
                                    Image(systemName: "photo")
                                        .foregroundStyle(MortColor.silver1)
                                    Text(name).mortBody().lineLimit(1)
                                    Spacer(minLength: 0)
                                    Button {
                                        attachments.removeAll { $0 == name }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(MortColor.textMuted)
                                            .frame(
                                                width: MortMetric.minTouchTarget,
                                                height: MortMetric.minTouchTarget
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove \(name)")
                                }
                            }
                        }
                        // INTEGRATION: present PhotosPicker / camera here.
                        // Requires NSPhotoLibraryUsageDescription and
                        // NSCameraUsageDescription in project.pbxproj.
                        MortGhostButton(title: "Add a photo", symbol: "camera") {
                            attachments.append("proof-\(attachments.count + 1).jpg")
                            MortHaptic.select()
                        }
                    }
                }

                MortTextArea(
                    label: "Note",
                    placeholder: "e.g. Front and back done, clippings bagged by the side gate.",
                    text: $note
                )

                MortNote(
                    text: "Proof is shared with the poster and kept with the job record. Don't include other people in photos.",
                    tone: .info
                )
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "Submit proof",
                    isBusy: isWorking,
                    isEnabled: !note.isEmpty || !attachments.isEmpty
                ) {
                    Task { await submit() }
                }
            }
        }
        .navigationTitle("Proof")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        isWorking = true
        error = nil
        do {
            try await mort.execution.submitProof(
                jobId: jobId, note: note, attachmentNames: attachments
            )
            MortHaptic.success()
            nav.pop()
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

#Preview("Start PIN — teen") {
    NavigationStack {
        JobStartPinView(jobId: MortFixtures.job.id, user: MortFixtures.teen)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
