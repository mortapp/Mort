//
//  PaymentReviewView.swift
//  MORT iOS V8 — Payment OS
//
//  PRE-WORK PLATFORM FUNDING — step 1.
//
//  Successful funding means JOB FUNDED. It does NOT mean the teen was paid to
//  their bank, and it does NOT mean earnings were settled.
//
//  The total shown here comes from the backend quote. The app never computes
//  a total it then charges.
//

import SwiftUI

@Observable
@MainActor
final class PaymentReviewViewModel {
    var quote: LoadState<PaymentQuote> = .idle
    var methods: [PaymentMethodRef] = []
    var selectedMethodId: String?
    var isSubmitting = false
    var resultState: PaymentState?
    var error: MortError?

    /// One key per attempt makes duplicate submission impossible.
    private var idempotencyKey = UUID().uuidString
    private let mort: MortDependencies
    private let jobId: String

    init(mort: MortDependencies, jobId: String) {
        self.mort = mort
        self.jobId = jobId
    }

    var selectedMethod: PaymentMethodRef? {
        methods.first { $0.id == selectedMethodId } ?? quote.value?.method
    }

    func load() async {
        quote = .loading
        error = nil
        do {
            let loaded = try await mort.payments.fundingQuote(jobId: jobId)
            quote = .loaded(loaded)
            methods = (try? await mort.payments.paymentMethods()) ?? []
            selectedMethodId = loaded.method?.id ?? methods.first { $0.isDefault && $0.isUsable }?.id
        } catch let failure as MortError {
            quote = .failed(failure)
        } catch {
            quote = .failed(.unknown)
        }
    }

    var hasUsableMethod: Bool {
        selectedMethod?.isUsable == true
    }

    /// A saved method is optional: Stripe PaymentSheet can collect a new one.
    var canPresentProviderSheet: Bool { true }

    var isQuoteExpired: Bool {
        quote.value?.isExpired == true
    }

    /// Submits pre-work funding. The returned state is the BACKEND's.
    func fund() async {
        guard !isSubmitting, hasUsableMethod else { return }
        isSubmitting = true
        error = nil
        do {
            resultState = try await mort.payments.beginFunding(
                jobId: jobId,
                methodId: selectedMethodId,
                idempotencyKey: idempotencyKey
            )
            if resultState == .funded {
                MortHaptic.success()
            } else if resultState?.producesNoReceipt == true {
                MortHaptic.failure()
            }
        } catch let failure as MortError {
            error = failure
            // Fail CLOSED: an error is never treated as a success.
            resultState = .unknown
            MortHaptic.failure()
        } catch {
            self.error = .unknown
            resultState = .unknown
        }
        isSubmitting = false
        // A new key only after a terminal, non-retryable outcome.
        if resultState == .declined || resultState == .cancelled {
            idempotencyKey = UUID().uuidString
        }
    }
}

struct PaymentReviewView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var model: PaymentReviewViewModel?

    var body: some View {
        MortScreen(
            title: "Fund this job",
            subtitle: "MORT holds the money until you confirm the work is done.",
            atmosphereIntensity: 0.6
        ) {
            if let model {
                switch model.quote {
                case .idle, .loading:
                    // Context-aware loading: we say what we're fetching.
                    VStack(alignment: .leading, spacing: MortSpace.s4) {
                        Text("Getting the exact amount…").mortBody()
                        MortSkeletonBar(width: 180, height: 34)
                        MortSkeletonList(rows: 3)
                    }
                case .failed(let error):
                    MortErrorState(
                        title: "Couldn't load the amount",
                        message: error.userMessage
                    ) {
                        Task { await model.load() }
                    }
                case .loaded(let quote), .offlineCache(let quote):
                    content(model, quote)
                }
            }
        } bottom: {
            if let model, let quote = model.quote.value {
                MortBottomBar { actions(model, quote) }
            }
        }
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = PaymentReviewViewModel(mort: mort, jobId: jobId) }
            if case .idle = model?.quote { await model?.load() }
        }
        .onChange(of: model?.resultState) { _, state in
            guard let state else { return }
            switch state {
            case .funded, .declined, .failedNetwork, .providerUnavailable,
                 .pending, .cancelled, .unknown, .duplicateBlocked, .quoteExpired,
                 .requiresAction:
                nav.push(.paymentResult(jobId: jobId, state: state))
            case .processing:
                nav.push(.paymentResult(jobId: jobId, state: .processing))
            case .ready:
                break
            }
        }
    }

    @ViewBuilder
    private func content(_ model: PaymentReviewViewModel, _ quote: PaymentQuote) -> some View {
        VStack(alignment: .leading, spacing: MortSpace.s5) {
            if let error = model.error {
                MortStatusPanel(
                    tone: .danger,
                    symbol: "exclamationmark.triangle",
                    label: "COULDN'T START PAYMENT",
                    detail: error.userMessage
                )
            }

            if model.isQuoteExpired {
                MortStatusPanel(
                    tone: .warning,
                    symbol: "clock.arrow.circlepath",
                    label: "AMOUNT EXPIRED",
                    detail: "This total is out of date. Refresh it so you're funding the right amount."
                )
            }

            JobContextStrip(
                title: quote.jobTitle,
                orderNumber: quote.orderNumber,
                counterpartyHandle: quote.workerHandle
            )

            PaymentAmountBreakdown(
                baseCents: quote.baseCents,
                tipCents: nil,
                feeCents: quote.feeCents,
                totalCents: quote.totalCents,
                tipRecipient: quote.workerHandle,
                totalLabel: "Total to fund"
            )

            PaymentFeeExplanation(text: quote.feeExplanation)

            VStack(alignment: .leading, spacing: MortSpace.s3) {
                MortSectionHeader(title: "Paying with") {
                    Button("Change") { nav.present(.paymentMethods) }
                        .font(MortFont.label())
                        .foregroundStyle(MortColor.silver3)
                }
                MortCard {
                    if let method = model.selectedMethod {
                        PaymentMethodRow(method: method, isSelected: true)
                    } else {
                        VStack(alignment: .leading, spacing: MortSpace.s3) {
                            MortNote(
                                text: "Choose or enter a payment method in Stripe's secure payment sheet when you continue.",
                                tone: .info,
                                symbol: "creditcard"
                            )
                        }
                    }
                }
            }

            MortStatusPanel(
                tone: .info,
                symbol: "lock.shield",
                label: "WHAT HAPPENS NEXT",
                detail: "Funding holds the money with MORT so your worker knows it's real. They can then start. After you confirm the job, MORT settles it and sends their earnings — funding is not the same as paying them directly."
            )

            MortNote(
                text: "Tips are separate and always optional. MORT never charges a fee on a tip.",
                tone: .neutral,
                symbol: "hand.thumbsup"
            )
        }
    }

    @ViewBuilder
    private func actions(_ model: PaymentReviewViewModel, _ quote: PaymentQuote) -> some View {
        if model.isQuoteExpired {
            MortPrimaryButton(title: "Refresh the amount", symbol: "arrow.clockwise") {
                Task { await model.load() }
            }
        } else {
            MortPrimaryButton(
                title: "Fund \(quote.total.formatted)",
                symbol: "lock.shield",
                isBusy: model.isSubmitting,
                isEnabled: model.canPresentProviderSheet && !model.isSubmitting,
                busyTitle: "Processing…"
            ) {
                Task { await model.fund() }
            }
            MortQuietButton(title: "Add a tip instead of later") {
                nav.present(.tipSelect(jobId: jobId, isLate: false))
            }
        }
    }
}

#Preview("Review") {
    NavigationStack {
        PaymentReviewView(jobId: MortFixtures.job.id)
    }
    .environment(\.mort, MortDependencies.preview(user: MortFixtures.adult))
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
