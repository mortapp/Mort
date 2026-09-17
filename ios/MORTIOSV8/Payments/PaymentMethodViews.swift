//
//  PaymentMethodViews.swift
//  MORT iOS V8 — Payment OS
//
//  Method picker, missing-method block, and retry.
//
//  SECURITY: the app shows masks only. No PAN, no CVV, no expiry entry —
//  card capture happens inside the provider's own sheet.
//

import SwiftUI

struct PaymentMethodPickerView: View {
    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(\.dismiss) private var dismiss

    @State private var methods: LoadState<[PaymentMethodRef]> = .idle
    @State private var selectedId: String?

    var body: some View {
        MortScreen(
            title: "Payment method",
            subtitle: "Pick which method to use for this job.",
            atmosphereIntensity: 0.6
        ) {
            switch methods {
            case .idle, .loading:
                MortSkeletonList(rows: 3)
            case .failed(let error):
                MortErrorState(message: error.userMessage) { Task { await load() } }
            case .loaded(let items), .offlineCache(let items):
                VStack(alignment: .leading, spacing: MortSpace.s4) {
                    if items.isEmpty {
                        MortEmptyState(
                            symbol: "creditcard",
                            title: "No payment methods",
                            message: "Add one to fund jobs. MORT never stores your card details — your provider does."
                        )
                    } else {
                        MortCard {
                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, method in
                                    PaymentMethodRow(
                                        method: method,
                                        isSelected: selectedId == method.id
                                    ) {
                                        selectedId = method.id
                                        Task { try? await mort.payments.setDefaultMethod(id: method.id) }
                                    }
                                    if index < items.count - 1 { MortDivider() }
                                }
                            }
                        }
                    }

                    MortGhostButton(title: "Add a payment method", symbol: "plus") {
                        // INTEGRATION: presents the provider's own add-card
                        // sheet. MORT never builds a card form.
                        nav.push(.paymentMethodMissing)
                    }

                    MortNote(
                        text: "MORT only ever sees the last four digits. Your full card details stay with your payment provider.",
                        tone: .info,
                        symbol: "lock.shield"
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(title: "Use this method", isEnabled: selectedId != nil) {
                    dismiss()
                    nav.dismissSheet()
                }
            }
        }
        .navigationTitle("Methods")
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
        .task { await load() }
    }

    private func load() async {
        methods = .loading
        do {
            let items = try await mort.payments.paymentMethods()
            methods = .loaded(items)
            selectedId = items.first { $0.isDefault && $0.isUsable }?.id
        } catch let error as MortError {
            methods = .failed(error)
        } catch {
            methods = .failed(.unknown)
        }
    }
}

/// Blocked state: funding cannot proceed without a usable method.
struct PaymentMethodMissingView: View {
    @Environment(MortNavigator.self) private var nav

    var body: some View {
        MortScreen(
            title: "Add a payment method",
            subtitle: "You need one before you can fund a job.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                MortStatusPanel(
                    tone: .warning,
                    symbol: "creditcard.trianglebadge.exclamationmark",
                    label: "NO USABLE METHOD",
                    detail: "Jobs are funded before work starts, so MORT needs a working payment method on file."
                )

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpace.s3) {
                        MortSectionHeader(title: "How MORT handles your card")
                        MortNote(text: "Card details go straight to our payment provider — MORT never sees or stores them.", tone: .neutral, symbol: "lock.shield")
                        MortNote(text: "We only keep the last four digits so you can tell your methods apart.", tone: .neutral, symbol: "eye.slash")
                        MortNote(text: "You can remove a method any time in Settings.", tone: .neutral, symbol: "trash")
                    }
                }
            }
        } bottom: {
            MortBottomBar {
                // INTEGRATION: launches the provider's add-payment-method
                // sheet. Until Stripe is wired this fails closed with an
                // honest unavailable state rather than a fake success.
                MortPrimaryButton(title: "Add payment method", symbol: "plus") {
                    nav.present(.paymentMethods)
                }
                MortQuietButton(title: "Not now") { nav.pop() }
            }
        }
        .navigationTitle("Payment method")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Retry with a pre-flight explanation, so a retry is never blind.
struct PaymentRetryView: View {
    let jobId: String

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @State private var quote: PaymentQuote?
    @State private var lastReason: PaymentFailureReason?
    @State private var isSubmitting = false
    @State private var resultState: PaymentState?
    @State private var idempotencyKey = UUID().uuidString

    var body: some View {
        MortScreen(
            title: "Try funding again",
            subtitle: "Here's what happened last time, and what changes.",
            atmosphereIntensity: 0.6
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let lastReason {
                    PaymentErrorReasonView(reason: lastReason)
                }

                MortStatusPanel(
                    tone: .info,
                    symbol: "shield.checkerboard",
                    label: "BEFORE YOU RETRY",
                    detail: "Nothing was charged on the failed attempt, and MORT blocks duplicate payments for the same job. If you're unsure, check the status first."
                )

                if let quote {
                    PaymentAmountBreakdown(
                        baseCents: quote.baseCents,
                        tipCents: nil,
                        feeCents: quote.feeCents,
                        totalCents: quote.totalCents,
                        tipRecipient: quote.workerHandle,
                        totalLabel: "Total to fund"
                    )
                    if let method = quote.method {
                        MortCard { PaymentMethodRow(method: method, isSelected: true) }
                    }
                }
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "Retry payment",
                    symbol: "arrow.clockwise",
                    isBusy: isSubmitting,
                    busyTitle: "Processing…"
                ) {
                    Task { await retry() }
                }
                MortGhostButton(title: "Use a different method", symbol: "creditcard") {
                    nav.push(.paymentMethods)
                }
                MortQuietButton(title: "Check status instead") {
                    nav.push(.paymentStatusCheck(jobId))
                }
            }
        }
        .navigationTitle("Retry")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            quote = try? await mort.payments.fundingQuote(jobId: jobId)
            lastReason = (try? await mort.payments.fundingStatus(jobId: jobId))?.reason
        }
        .onChange(of: resultState) { _, state in
            guard let state else { return }
            nav.push(.paymentResult(jobId: jobId, state: state))
        }
    }

    private func retry() async {
        isSubmitting = true
        do {
            resultState = try await mort.payments.beginFunding(
                jobId: jobId, methodId: quote?.method?.id, idempotencyKey: idempotencyKey
            )
        } catch {
            resultState = .unknown
        }
        isSubmitting = false
        idempotencyKey = UUID().uuidString
    }
}

#Preview {
    NavigationStack { PaymentMethodPickerView() }
        .environment(\.mort, MortDependencies.preview())
        .environment(MortNavigator())
        .preferredColorScheme(.dark)
}
