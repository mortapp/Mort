//
//  PaymentResultView.swift
//  MORT iOS V8 — Payment OS
//
//  Every terminal and non-terminal payment state renders here, from the
//  backend-reported state only.
//
//  Success is premium and calm — never over-celebrated. Failure is serious but
//  recoverable, with "NO RECEIPT WAS CREATED" stated explicitly and no
//  provider detail leaked.
//

import SwiftUI

struct PaymentResultView: View {
    let jobId: String
    let state: PaymentState

    @Environment(\.mort) private var mort
    @Environment(MortNavigator.self) private var nav
    @Environment(\.mortReducedMotion) private var reducedMotion

    @State private var quote: PaymentQuote?
    @State private var reason: PaymentFailureReason?
    @State private var receipt: Receipt?
    @State private var checkedForReceipt = false

    private var presentation: PaymentStatePresentation {
        PaymentStatePresentation.of(state)
    }

    var body: some View {
        MortScreen(
            atmosphereIntensity: state == .funded ? 0.75 : 0.55,
            showsForegroundMeteors: state == .funded
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if state == .funded {
                    SuccessMark()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MortSpace.s4)
                }

                PaymentHeader(
                    presentation: presentation,
                    amount: quote?.total ?? .zero,
                    amountLabel: state == .funded ? "Held for this job" : "Attempted",
                    jobTitle: quote?.jobTitle,
                    workerHandle: quote?.workerHandle
                )

                if presentation.showsNoReceiptBanner {
                    MortNoReceiptBanner()
                }

                if let reason {
                    PaymentErrorReasonView(reason: reason)
                }

                if state == .funded {
                    MortStatusPanel(
                        tone: .info,
                        symbol: "info.circle",
                        label: "WHAT THIS MEANS",
                        detail: "The job is funded and your worker can start. This isn't the same as paying them — MORT settles their earnings after you confirm the work."
                    )
                }

                if let order = quote?.orderNumber {
                    MortCard {
                        VStack(spacing: MortSpace.s2) {
                            MortKeyValueRow(label: "ORDER #", value: order, isMonospaced: true)
                            if let receipt {
                                MortDivider()
                                MortKeyValueRow(label: "RECEIPT #", value: receipt.id, isMonospaced: true)
                            }
                        }
                    }
                }

                if state == .funded, receipt == nil, checkedForReceipt {
                    MortNote(
                        text: "Your receipt is being issued and will appear in Job & Payment History shortly.",
                        tone: .info,
                        symbol: "doc.badge.clock"
                    )
                }

                if presentation.showsDuplicateSafety {
                    MortDuplicateSafetyNote()
                }
            }
        } bottom: {
            MortBottomBar { actions }
        }
        .navigationTitle(state == .funded ? "Funded" : "Payment")
        .navigationBarTitleDisplayMode(.inline)
        // Rule R2: once a terminal state is shown, going "back" into the
        // in-flight screens is not possible.
        .navigationBarBackButtonHidden(state == .funded)
        .task { await load() }
    }

    @ViewBuilder
    private var actions: some View {
        switch state {
        case .funded:
            if let receipt {
                MortPrimaryButton(title: "View receipt", symbol: "doc.text") {
                    nav.push(.receipt(receipt.id))
                }
            } else {
                MortPrimaryButton(title: "Back to the job", symbol: "briefcase") {
                    // Rule R3: return to origin, not stacked payment screens.
                    nav.popToRoot()
                }
            }
            MortQuietButton(title: "Done") { nav.popToRoot() }

        case .declined:
            MortPrimaryButton(title: "Try a different method", symbol: "creditcard") {
                nav.push(.paymentMethods)
            }
            MortGhostButton(title: "Try again", symbol: "arrow.clockwise") {
                nav.push(.paymentRetry(jobId))
            }
            MortQuietButton(title: "Return to the job") { nav.popToRoot() }

        case .failedNetwork, .unknown:
            // Status check FIRST — never a blind retry after a lost outcome.
            MortPrimaryButton(title: "Check payment status", symbol: "arrow.triangle.2.circlepath") {
                nav.push(.paymentStatusCheck(jobId))
            }
            MortQuietButton(title: "Return to the job") { nav.popToRoot() }

        case .providerUnavailable:
            MortPrimaryButton(title: "Return to the job", symbol: "briefcase") {
                nav.popToRoot()
            }
            MortQuietButton(title: "Check payment status") {
                nav.push(.paymentStatusCheck(jobId))
            }

        case .pending:
            MortPrimaryButton(title: "Check payment status", symbol: "arrow.triangle.2.circlepath") {
                nav.push(.paymentStatusCheck(jobId))
            }
            MortQuietButton(title: "Return to the job") { nav.popToRoot() }

        case .requiresAction:
            MortPrimaryButton(title: "Continue to verification", symbol: "hand.raised") {
                nav.present(.paymentProcessing(jobId))
            }
            MortQuietButton(title: "Return to the job") { nav.popToRoot() }

        case .cancelled:
            MortPrimaryButton(title: "Return to review", symbol: "arrow.left") {
                nav.popTo(.paymentReview(jobId))
            }

        case .duplicateBlocked:
            MortPrimaryButton(title: "Check payment status", symbol: "arrow.triangle.2.circlepath") {
                nav.push(.paymentStatusCheck(jobId))
            }
            MortGhostButton(title: "Return to transaction", symbol: "briefcase") {
                nav.popToRoot()
            }

        case .quoteExpired:
            MortPrimaryButton(title: "Refresh the amount", symbol: "arrow.clockwise") {
                nav.popTo(.paymentReview(jobId))
            }

        case .ready, .processing:
            MortPrimaryButton(title: "Continue") { nav.popToRoot() }
        }
    }

    private func load() async {
        quote = try? await mort.payments.fundingQuote(jobId: jobId)
        if state.producesNoReceipt {
            let status = try? await mort.payments.fundingStatus(jobId: jobId)
            reason = status?.reason
        }
        if state == .funded {
            receipt = try? await mort.receipts.receipt(jobId: jobId, type: .adultJobPayment)
            checkedForReceipt = true
        }
    }
}

/// A single calm check-ring draw. No confetti, no bounce — this is money.
private struct SuccessMark: View {
    @Environment(\.mortReducedMotion) private var reducedMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(MortColor.success.opacity(0.22), lineWidth: 1)
                .frame(width: 96, height: 96)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(MortColor.success, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(MortColor.success)
                .opacity(progress > 0.6 ? 1 : 0)
        }
        .onAppear {
            if reducedMotion {
                progress = 1
            } else {
                withAnimation(MortMotion.confirm) { progress = 1 }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Funded") {
    NavigationStack {
        PaymentResultView(jobId: MortFixtures.job.id, state: .funded)
    }
    .environment(\.mort, MortDependencies.preview())
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}

#Preview("Declined") {
    NavigationStack {
        PaymentResultView(jobId: MortFixtures.job.id, state: .declined)
    }
    .environment(\.mort, MortDependencies.preview(paymentOutcome: .declined, paymentReason: .insufficientFunds))
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}

#Preview("Pending") {
    NavigationStack {
        PaymentResultView(jobId: MortFixtures.job.id, state: .pending)
    }
    .environment(\.mort, MortDependencies.preview(paymentOutcome: .pending))
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}

#Preview("Duplicate blocked") {
    NavigationStack {
        PaymentResultView(jobId: MortFixtures.job.id, state: .duplicateBlocked)
    }
    .environment(\.mort, MortDependencies.preview(paymentOutcome: .duplicateBlocked))
    .environment(MortNavigator())
    .preferredColorScheme(.dark)
}
