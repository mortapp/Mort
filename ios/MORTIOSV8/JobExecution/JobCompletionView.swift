//
//  JobCompletionView.swift
//  MORT iOS V8 — Job Execution
//
//  The adult acknowledges the worker's completion assertion.
//  This does not itself prove settlement, transfer, refund, or payout.
//

import SwiftUI

struct JobCompletionView: View {
    let jobId: String
    let user: MortUser

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var job: LoadState<MortJob> = .idle
    @State private var acknowledgement: CompletionAcknowledgement?
    @State private var isWorking = false
    @State private var error: MortError?

    var body: some View {
        MortScreen(
            title: acknowledgement == nil ? "Confirm the work" : "Completion confirmed",
            subtitle: acknowledgement == nil
                ? "Confirm the worker's completion assertion. Financial settlement remains a separate backend step."
                : "MORT recorded your acknowledgement. Payment, transfer, refund, and payout remain server-authoritative.",
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

                if let acknowledgement {
                    MortStatusPanel(
                        tone: .success,
                        symbol: "checkmark.seal",
                        label: "COMPLETION CONFIRMED",
                        detail: acknowledgement.paymentDue
                            ? "The contractual payment obligation is now due. This does not mean a transfer or payout has completed."
                            : "Your acknowledgement was recorded. MORT has not reported a completed financial settlement."
                    )
                    if acknowledgement.mortProcessedPayment {
                        MortNote(
                            text: "MORT reports a payment-processing action occurred, but this screen does not treat that as proof of transfer or payout. Check authoritative financial history for issued documents.",
                            tone: .info
                        )
                    } else {
                        MortNote(
                            text: "Financial resolution is still separate. Immutable receipts appear in History only after the backend issues them.",
                            tone: .neutral,
                            symbol: "doc.text"
                        )
                    }
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
                if acknowledgement != nil {
                    MortPrimaryButton(title: "Done") { nav.popToRoot() }
                    MortGhostButton(title: "Financial history", symbol: "clock.arrow.circlepath") {
                        nav.push(.history)
                    }
                } else {
                    MortPrimaryButton(
                        title: "Confirm — the work is done",
                        symbol: "checkmark.seal.fill",
                        isBusy: isWorking,
                        busyTitle: "Confirming…"
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
            acknowledgement = try await mort.execution.confirmCompletion(jobId: jobId)
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
                ? "MORT recorded the cancellation. Any eligible refund is a separate immutable financial event."
                : "Tell us why. If the job was funded, MORT evaluates the cancellation and any refund server-side.",
            atmosphereIntensity: 0.62
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if done {
                    MortStatusPanel(
                        tone: .info,
                        symbol: "arrow.uturn.left.circle",
                        label: "CANCELLED",
                        detail: "If a refund is due, MORT records it as a new linked financial document. The original receipt never changes."
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
                        detail: "MORT pauses settlement actions while the review is open. The final financial outcome stays server-authoritative."
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
