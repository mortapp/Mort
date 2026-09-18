//
//  TipViews.swift
//  MORT iOS V8 — Payment OS / Tips
//
//  TIP RULES enforced by this UI:
//   - Optional, always.
//   - 100% goes to the teen; MORT's fee on a tip is ZERO.
//   - Excluded from Fair Pay.
//   - A SEPARATE provider transaction.
//   - A failed tip never undoes a successful base settlement.
//   - A late tip produces its own separate receipt.
//

import SwiftUI

@Observable
@MainActor
final class TipViewModel {
    var quote: LoadState<PaymentQuote> = .idle
    var config: TipConfig = .reference
    var selection: TipOption = .none
    var customText = ""
    var isSubmitting = false
    var resultState: PaymentState?
    var error: MortError?

    private var idempotencyKey = UUID().uuidString
    private let mort: MortDependencies
    private let jobId: String

    init(mort: MortDependencies, jobId: String) {
        self.mort = mort
        self.jobId = jobId
    }

    func load() async {
        quote = .loading
        do {
            guard let display = try await mort.payments.fundingDisplay(jobId: jobId) else {
                throw MortError.notConfigured("Tip payment context")
            }
            quote = .loaded(display)
            config = try await mort.payments.tipConfig()
        } catch let failure as MortError {
            quote = .failed(failure)
        } catch {
            quote = .failed(.unknown)
        }
    }

    var baseCents: Int64 { quote.value?.baseCents ?? 0 }

    var customValidation: CustomTipValidation {
        CustomTipValidation.evaluate(customText, config: config)
    }

    /// The tip that would be charged. nil when the selection isn't valid yet.
    var tipCents: Int64? {
        switch selection {
        case .custom: customValidation.money?.cents
        default: selection.previewCents(baseCents: baseCents)
        }
    }

    var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard let cents = tipCents else { return false }
        if cents == 0 { return true }   // "no tip" is a valid choice
        return cents >= config.minimumCents && cents <= config.maximumCents
    }

    var isNoTip: Bool { tipCents == 0 }

    func submit() async {
        guard let cents = tipCents, cents > 0 else { return }
        isSubmitting = true
        error = nil
        do {
            resultState = try await mort.payments.submitTip(
                jobId: jobId, tipCents: cents, idempotencyKey: idempotencyKey
            )
            if resultState == .funded { MortHaptic.success() } else { MortHaptic.failure() }
        } catch let failure as MortError {
            error = failure
            resultState = .unknown
            MortHaptic.failure()
        } catch {
            self.error = .unknown
            resultState = .unknown
        }
        isSubmitting = false
        idempotencyKey = UUID().uuidString
    }
}

struct TipSelectView: View {
    let jobId: String
    let isLate: Bool

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(\.dismiss) private var dismiss
    @State private var model: TipViewModel?

    var body: some View {
        MortScreen(
            title: isLate ? "Add a tip" : "Want to add a tip?",
            subtitle: isLate
                ? "This job is already settled. A tip is a separate payment with its own receipt."
                : "Completely optional — and it all goes to your worker.",
            atmosphereIntensity: 0.6
        ) {
            if let model {
                switch model.quote {
                case .idle, .loading:
                    MortSkeletonList(rows: 3)
                case .failed(let error):
                    MortErrorState(message: error.userMessage) { Task { await model.load() } }
                case .loaded(let quote), .offlineCache(let quote):
                    VStack(alignment: .leading, spacing: MortSpace.s5) {
                        if let error = model.error {
                            MortStatusPanel(
                                tone: .danger,
                                symbol: "exclamationmark.triangle",
                                label: "TIP DIDN'T GO THROUGH",
                                detail: error.userMessage
                            )
                            MortNote(
                                text: "The job payment is unaffected — it stays settled.",
                                tone: .info,
                                symbol: "lock.shield"
                            )
                        }

                        TipRecipientBanner(handle: quote.workerHandle)

                        JobContextStrip(
                            title: quote.jobTitle,
                            orderNumber: quote.orderNumber,
                            counterpartyHandle: quote.workerHandle
                        )

                        TipSelector(
                            baseCents: quote.baseCents,
                            selection: Binding(
                                get: { model.selection },
                                set: { model.selection = $0 }
                            )
                        )

                        if case .custom = model.selection {
                            CustomTipInput(
                                text: Binding(get: { model.customText }, set: { model.customText = $0 }),
                                config: model.config
                            )
                        }

                        if let cents = model.tipCents, cents > 0 {
                            MortCard {
                                VStack(alignment: .leading, spacing: MortSpace.s3) {
                                    // BASE PAY stays visually distinct from TIP.
                                    PaymentLineItem(
                                        label: "Base pay (settled)",
                                        amount: quote.base,
                                        isQuiet: true
                                    )
                                    MortDivider()
                                    PaymentLineItem(
                                        label: "Tip",
                                        amount: Money(cents: cents),
                                        note: "100% of your tip goes to \(quote.workerHandle)"
                                    )
                                    MortDivider()
                                    PaymentLineItem(label: "MORT fee on tip", amount: .zero, isQuiet: true)
                                }
                            }
                        }

                        TipRulesNote()
                    }
                }
            }
        } bottom: {
            if let model, model.quote.value != nil {
                MortBottomBar {
                    if model.isNoTip {
                        MortPrimaryButton(title: "Finish without a tip") {
                            dismiss()
                            nav.dismissSheet()
                        }
                    } else {
                        MortPrimaryButton(
                            title: model.tipCents.map { "Tip \(Money(cents: $0).formatted)" } ?? "Choose an amount",
                            symbol: "hand.thumbsup.fill",
                            isBusy: model.isSubmitting,
                            isEnabled: model.canSubmit,
                            busyTitle: "Sending tip…"
                        ) {
                            Task {
                                await model.submit()
                                if model.resultState == .funded {
                                    nav.push(.tipConfirm(jobId: jobId, tipCents: model.tipCents ?? 0))
                                }
                            }
                        }
                        MortQuietButton(title: "Skip the tip") {
                            dismiss()
                            nav.dismissSheet()
                        }
                    }
                    MortNote(
                        text: "Tips are separate from the job payment and don't count toward Fair Pay.",
                        tone: .neutral
                    )
                }
            }
        }
        .navigationTitle("Tip")
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
        .task {
            if model == nil { model = TipViewModel(mort: mort, jobId: jobId) }
            if case .idle = model?.quote { await model?.load() }
        }
    }
}

struct TipCustomView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: TipViewModel?

    var body: some View {
        MortScreen(
            title: "Custom tip",
            subtitle: "Enter any amount you like.",
            atmosphereIntensity: 0.6
        ) {
            if let model, let quote = model.quote.value {
                VStack(alignment: .leading, spacing: MortSpace.s5) {
                    TipRecipientBanner(handle: quote.workerHandle)
                    CustomTipInput(
                        text: Binding(get: { model.customText }, set: { model.customText = $0 }),
                        config: model.config
                    )
                    TipRulesNote()
                }
            } else {
                MortSkeletonList(rows: 3)
            }
        } bottom: {
            if let model {
                MortBottomBar {
                    MortPrimaryButton(
                        title: model.customValidation.money.map { "Tip \($0.formatted)" } ?? "Enter an amount",
                        isBusy: model.isSubmitting,
                        isEnabled: model.customValidation.money != nil && !model.isSubmitting
                    ) {
                        model.selection = .custom
                        Task {
                            await model.submit()
                            if model.resultState == .funded {
                                nav.push(.tipConfirm(jobId: jobId, tipCents: model.tipCents ?? 0))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Custom")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = TipViewModel(mort: mort, jobId: jobId) }
            model?.selection = .custom
            if case .idle = model?.quote { await model?.load() }
        }
    }
}

/// Tip confirmed. The tip gets its OWN receipt, separate from the job payment.
struct TipConfirmView: View {
    let jobId: String
    let tipCents: Int64

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var quote: PaymentQuote?
    @State private var receipt: Receipt?

    var body: some View {
        MortScreen(atmosphereIntensity: 0.7, showsForegroundMeteors: true) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                MortStatusPanel(
                    tone: .success,
                    symbol: "checkmark.circle",
                    label: "TIP SENT",
                    detail: quote.map { "\(Money(cents: tipCents).formatted) is on its way to \($0.workerHandle) — all of it." }
                        ?? "Your tip is on its way."
                )

                if let quote {
                    TipConfirmationBlock(
                        tip: Money(cents: tipCents),
                        handle: quote.workerHandle,
                        baseCents: quote.baseCents
                    )
                }

                MortNote(
                    text: "Your worker gets a separate tip receipt. The original job receipt is unchanged.",
                    tone: .info,
                    symbol: "doc.on.doc"
                )
            }
        } bottom: {
            MortBottomBar {
                if let receipt {
                    MortPrimaryButton(title: "View tip receipt", symbol: "doc.text") {
                        nav.push(.receipt(receipt.id))
                    }
                    MortQuietButton(title: "Done") { nav.popToRoot() }
                } else {
                    MortPrimaryButton(title: "Done") { nav.popToRoot() }
                }
            }
        }
        .navigationTitle("Tip sent")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            quote = try? await mort.payments.fundingDisplay(jobId: jobId)
            receipt = try? await mort.receipts.receipt(jobId: jobId, type: .lateTip)
        }
    }
}

/// Standalone Fair Pay explainer, reachable from job posting and settings.
struct FairPayInfoView: View {
    @State private var offered: Int64 = 2000
    private let policy: FairPayPolicy = .reference

    var body: some View {
        MortScreen(
            title: "How Fair Pay works",
            subtitle: "MORT won't let jobs be posted below what the work is worth.",
            atmosphereIntensity: 0.65
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                FairPayGuardrail(offeredCents: $offered, policy: policy)

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "The three zones")
                        MortNote(text: "Green — in line with what this work usually pays.", tone: .success, symbol: "checkmark.seal")
                        MortNote(text: "Yellow — allowed, but you'll get fewer applicants.", tone: .warning, symbol: "exclamationmark.circle")
                        MortNote(text: "Red — below the hard minimum. Posting is blocked.", tone: .danger, symbol: "xmark.octagon")
                    }
                }

                MortNote(
                    text: "Tips are never counted toward Fair Pay. A generous tip can't make a low base pay acceptable.",
                    tone: .info,
                    symbol: "hand.thumbsup"
                )
            }
        }
        .navigationTitle("Fair Pay")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Tip selector") {
    NavigationStack {
        TipSelectView(jobId: MortFixtures.job.id, isLate: false)
    }
    .environment(\.mort, MortDependencies.preview(user: MortFixtures.adult))
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}

#Preview("Fair Pay red") {
    NavigationStack { FairPayInfoView() }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
