//
//  JobCompletionView.swift
//  MORT iOS V8 — Job Execution
//
//  The adult confirms the work. This triggers AUTHORITATIVE SETTLEMENT:
//  MORT decides the compensated base, retains or refunds its fee, and
//  refunds any difference. Neither party sets the number.
//

import SwiftUI

struct JobCompletionView: View {
    let jobId: String
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var job: LoadState<MortJob> = .idle
    @State private var settlement: SettlementResult?
    @State private var isWorking = false
    @State private var error: MortError?

    var body: some View {
        MortScreen(
            title: settlement == nil ? "Confirm the work" : "Settled",
            subtitle: settlement == nil
                ? "Confirming releases the payment to your worker."
                : "Here's exactly what happened with the money.",
            atmosphereIntensity: 0.62
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error {
                    MortStatusPanel(
                        tone: .danger,
                        symbol: "exclamationmark.triangle",
                        label: "COULDN'T CONFIRM",
                        detail: error.userMessage
                    )
                }

                if let settlement {
                    SettlementSummaryView(settlement: settlement)
                } else {
                    switch job {
                    case .idle, .loading:
                        MortSkeletonList(rows: 3)
                    case .failed(let failure):
                        MortErrorState(message: failure.userMessage) { Task { await load() } }
                    case .loaded(let value), .offlineCache(let value):
                        VStack(alignment: .leading, spacing: MortSpace.s4) {
                            JobContextStrip(
                                title: value.title,
                                orderNumber: value.orderNumber,
                                counterpartyHandle: value.workerHandle
                            )

                            MortCard {
                                VStack(alignment: .leading, spacing: MortSpace.s3) {
                                    MortSectionHeader(title: "What you funded")
                                    PaymentLineItem(label: "Base pay", amount: value.basePay)
                                    MortDivider()
                                    MortNote(
                                        text: "If the work wasn't fully done, say so instead of confirming. MORT will review and settle fairly.",
                                        tone: .warning
                                    )
                                }
                            }

                            MortNote(
                                text: "MORT decides the final amount from the confirmed outcome. You can't set it directly, and neither can your worker.",
                                tone: .info,
                                symbol: "shield.lefthalf.filled"
                            )
                        }
                    }
                }
            }
        } bottom: {
            MortBottomBar {
                if let settlement {
                    MortPrimaryButton(title: "Add a tip", symbol: "hand.thumbsup") {
                        nav.present(.tipSelect(jobId: jobId, isLate: true))
                    }
                    MortGhostButton(title: "View receipt", symbol: "doc.text") {
                        nav.push(.receipt(MortFixtures.adultReceipt.id))
                    }
                    MortQuietButton(title: "Done") { nav.popToRoot() }
                    if settlement.outcome == .disputed {
                        MortNote(text: "This job is under review. We'll update you here.", tone: .warning)
                    }
                } else {
                    MortPrimaryButton(
                        title: "Confirm — the work is done",
                        symbol: "checkmark.seal.fill",
                        isBusy: isWorking,
                        busyTitle: "Settling…"
                    ) {
                        Task { await confirm() }
                    }
                    MortQuietButton(title: "Something wasn't right", tone: .danger) {
                        nav.push(.jobDispute(jobId))
                    }
                }
            }
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        job = .loading
        do {
            job = .loaded(try await mort.jobs.job(id: jobId))
        } catch let failure as MortError {
            job = .failed(failure)
        } catch {
            job = .failed(.unknown)
        }
    }

    private func confirm() async {
        isWorking = true
        error = nil
        do {
            // Settlement is the backend's decision, returned here.
            settlement = try await mort.execution.confirmCompletion(jobId: jobId)
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

struct SettlementView: View {
    let jobId: String
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var settlement: LoadState<SettlementResult> = .idle

    var body: some View {
        MortScreen(
            title: "Settlement",
            subtitle: "What MORT decided, and why.",
            atmosphereIntensity: 0.62
        ) {
            switch settlement {
            case .idle, .loading:
                MortSkeletonList(rows: 4)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let result), .offlineCache(let result):
                SettlementSummaryView(settlement: result)
            }
        }
        .navigationTitle("Settlement")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        settlement = .loading
        do {
            settlement = .loaded(try await mort.execution.settlement(jobId: jobId))
        } catch let error as MortError {
            settlement = .failed(error)
        } catch {
            settlement = .failed(.unknown)
        }
    }
}

struct JobCancelView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var isWorking = false
    @State private var error: MortError?
    @State private var done = false

    var body: some View {
        MortScreen(
            title: done ? "Job cancelled" : "Cancel this job",
            subtitle: done
                ? "Any money held for this job is being returned."
                : "Tell us why. If the job was funded, MORT handles the refund.",
            atmosphereIntensity: 0.62
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if done {
                    MortStatusPanel(
                        tone: .info,
                        symbol: "arrow.uturn.left.circle",
                        label: "CANCELLED",
                        detail: "If this job was funded, MORT issues a refund receipt. Your original receipt is never changed."
                    )
                } else {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    MortTextArea(
                        label: "Reason",
                        placeholder: "What changed?",
                        text: $reason
                    )
                    MortNote(
                        text: "Cancelling repeatedly after someone is picked affects how MORT ranks your posts.",
                        tone: .warning
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                if done {
                    MortPrimaryButton(title: "Done") { dismiss() }
                } else {
                    MortDangerButton(
                        title: "Cancel the job",
                        symbol: "slash.circle",
                        isEnabled: reason.count >= 4 && !isWorking
                    ) {
                        Task { await cancel() }
                    }
                    MortQuietButton(title: "Keep the job") { dismiss() }
                }
            }
        }
        .navigationTitle("Cancel")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cancel() async {
        isWorking = true
        error = nil
        do {
            try await mort.jobs.cancelJob(id: jobId, reason: reason)
            done = true
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

struct JobDisputeView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var category = "Work wasn't completed"
    @State private var detail = ""
    @State private var isWorking = false
    @State private var error: MortError?
    @State private var opened = false

    private let categories = [
        "Work wasn't completed",
        "Work was done differently than agreed",
        "Someone didn't show up",
        "The amount looks wrong",
        "Something else",
    ]

    var body: some View {
        MortScreen(
            title: opened ? "We're on it" : "Something wasn't right",
            subtitle: opened
                ? "MORT reviews this and decides the fair outcome."
                : "Tell us what happened. MORT decides the settlement — not either side.",
            atmosphereIntensity: 0.62
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if opened {
                    MortStatusPanel(
                        tone: .warning,
                        symbol: "exclamationmark.triangle",
                        label: "UNDER REVIEW",
                        detail: "Money for this job stays held while we look at it. Nothing moves until MORT decides."
                    )
                } else {
                    if let error {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                    VStack(alignment: .leading, spacing: MortSpace.s2) {
                        Text("WHAT HAPPENED").mortEyebrow()
                        VStack(spacing: MortSpace.s2) {
                            ForEach(categories, id: \.self) { option in
                                MortChip(label: option, isSelected: category == option) {
                                    category = option
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    MortTextArea(
                        label: "Details",
                        placeholder: "What was agreed, and what actually happened?",
                        text: $detail,
                        minHeight: 140
                    )
                    MortNote(
                        text: "Be factual. Both sides get to explain, and MORT looks at the job record.",
                        tone: .info
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                if opened {
                    MortPrimaryButton(title: "Done") { nav.popToRoot() }
                    MortGhostButton(title: "Contact support", symbol: "headphones") {
                        nav.push(.supportHome)
                    }
                } else {
                    MortPrimaryButton(
                        title: "Open a dispute",
                        isBusy: isWorking,
                        isEnabled: detail.count >= 10 && !isWorking
                    ) {
                        Task { await open() }
                    }
                }
            }
        }
        .navigationTitle("Dispute")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func open() async {
        isWorking = true
        error = nil
        do {
            try await mort.execution.openDispute(jobId: jobId, category: category, detail: detail)
            opened = true
            MortHaptic.warning()
        } catch let failure as MortError {
            error = failure
        } catch {
            self.error = .unknown
        }
        isWorking = false
    }
}

#Preview {
    NavigationStack {
        JobCompletionView(jobId: MortFixtures.job.id, user: MortFixtures.adult)
    }
    .environment(\.mort, MortDependencies.preview(user: MortFixtures.adult))
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
