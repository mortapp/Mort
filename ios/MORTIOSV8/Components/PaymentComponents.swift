//
//  PaymentComponents.swift
//  MORT iOS V8 — Payment OS Components
//
//  Header hierarchy law: STATUS > AMOUNT > WHAT FOR > WHO > REFS > NEXT ACTION
//

import SwiftUI

/// The payment status header: state icon, big monospaced amount, purpose and
/// guidance. Tone never travels without an icon and a label.
struct PaymentHeader: View {
    let presentation: PaymentStatePresentation
    let amount: Money
    var amountLabel: String
    var jobTitle: String?
    var workerHandle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s4) {
            HStack(spacing: MortSpace.s2) {
                if presentation.showsSpinner {
                    MortSpinner(size: 16, tint: presentation.tone.color)
                } else {
                    Image(systemName: presentation.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(presentation.tone.color)
                }
                Text(presentation.label)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(presentation.tone.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Payment status: \(presentation.label)")

            VStack(alignment: .leading, spacing: MortSpace.s1) {
                Text(amount.formatted)
                    .font(MortFont.money(40, weight: .light))
                    .foregroundStyle(MortColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(amountLabel.uppercased())
                    .mortEyebrow()
            }

            VStack(alignment: .leading, spacing: MortSpace.s2) {
                if let jobTitle {
                    Text(jobTitle)
                        .mortBodyStrong()
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let workerHandle {
                    Text("Worker: \(workerHandle)")
                        .mortLabel()
                }
                Text(presentation.purpose)
                    .mortBody()
                    .fixedSize(horizontal: false, vertical: true)
                Text(presentation.guidance)
                    .mortMicro()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Safe failure reason. The BACKEND maps raw provider codes to this catalog —
/// raw codes are never rendered.
struct PaymentErrorReasonView: View {
    let reason: PaymentFailureReason

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpace.s2) {
                Text(reason.title)
                    .mortBodyStrong()
                    .fixedSize(horizontal: false, vertical: true)
                Text(reason.detail)
                    .mortBody()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One line in the amount breakdown.
struct PaymentLineItem: View {
    let label: String
    let amount: Money
    var note: String?
    var isTotal: Bool = false
    var isQuiet: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: MortSpace.s3) {
                Text(label.uppercased())
                    .font(.system(size: isTotal ? 12 : 11, weight: isTotal ? .semibold : .medium))
                    .tracking(isTotal ? 1.2 : 0.8)
                    .foregroundStyle(isQuiet ? MortColor.textMuted : MortColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: MortSpace.s2)
                Text(amount.formatted)
                    .font(MortFont.money(isTotal ? 22 : 14, weight: isTotal ? .semibold : .regular))
                    .foregroundStyle(isQuiet ? MortColor.textMuted : MortColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if let note {
                Text(note)
                    .mortMicro()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The funding breakdown: base, tip, fee, then TOTAL below a dashed rule.
/// BASE PAY is always visually distinct from TIP.
struct PaymentAmountBreakdown: View {
    let baseCents: Int64
    var tipCents: Int64?
    let feeCents: Int64
    let totalCents: Int64
    var tipRecipient: String?
    var totalLabel: String = "Total"

    var body: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpace.s3) {
                PaymentLineItem(
                    label: "Base pay",
                    amount: Money(cents: baseCents),
                    note: "Goes to the worker in full"
                )
                if let tipCents, tipCents > 0 {
                    MortDivider()
                    PaymentLineItem(
                        label: "Tip",
                        amount: Money(cents: tipCents),
                        note: tipRecipient.map { "100% of your tip goes to \($0)" }
                    )
                }
                MortDivider()
                PaymentLineItem(
                    label: "MORT service fee",
                    amount: Money(cents: feeCents),
                    note: "Added on top — never taken from the worker"
                )
                Rectangle()
                    .fill(.clear)
                    .frame(height: 1)
                    .overlay {
                        Rectangle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundStyle(MortColor.hairline2)
                            .frame(height: 1)
                    }
                    .padding(.vertical, MortSpace.s1)
                PaymentLineItem(
                    label: totalLabel,
                    amount: Money(cents: totalCents),
                    isTotal: true
                )
            }
        }
    }
}

/// Fee explanation. Copy is driven by backend config [CONFIGURABLE].
struct PaymentFeeExplanation: View {
    let text: String

    var body: some View {
        MortInsetSurface {
            MortNote(text: text, tone: .info, symbol: "info.circle")
        }
    }
}

/// Masked payment method row. [PRIVACY] masks only — never PAN or CVV.
struct PaymentMethodRow: View {
    let method: PaymentMethodRef
    var isSelected: Bool = false
    var showsChevron: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            guard method.isUsable, let action else { return }
            MortHaptic.select()
            action()
        } label: {
            HStack(spacing: MortSpace.s3) {
                Image(systemName: method.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(method.isUsable ? MortColor.silver2 : MortColor.textMuted)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.label)
                        .mortBodyStrong()
                    Text(method.mask)
                        .font(MortFont.money(12))
                        .foregroundStyle(MortColor.textSecondary)
                }
                Spacer(minLength: MortSpace.s2)
                if !method.isUsable {
                    MortStatusPill(tone: .warning, symbol: "exclamationmark.circle", label: "Unusable", compact: true)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(MortColor.success)
                } else if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MortColor.textMuted)
                }
            }
            .frame(minHeight: MortMetric.minTouchTarget)
            .padding(.vertical, MortSpace.s2)
            .contentShape(.rect)
            .opacity(method.isUsable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!method.isUsable || action == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(method.label) \(method.mask)\(method.isUsable ? "" : ", unusable")")
    }
}

/// The Payment OS scaffold used by every payment-state screen.
struct PaymentStateScaffold<Body_: View, Actions: View>: View {
    let state: PaymentState
    let amount: Money
    var amountLabel: String
    var jobTitle: String?
    var workerHandle: String?
    var orderNumber: String?
    @ViewBuilder var content: () -> Body_
    @ViewBuilder var actions: () -> Actions

    private var presentation: PaymentStatePresentation {
        PaymentStatePresentation.of(state)
    }

    var body: some View {
        MortScreen(atmosphereIntensity: 0.62) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                PaymentHeader(
                    presentation: presentation,
                    amount: amount,
                    amountLabel: amountLabel,
                    jobTitle: jobTitle,
                    workerHandle: workerHandle
                )

                if presentation.showsNoReceiptBanner {
                    MortNoReceiptBanner()
                }

                content()

                if let orderNumber {
                    MortCard {
                        MortKeyValueRow(label: "ORDER #", value: orderNumber, isMonospaced: true)
                    }
                }

                if presentation.showsDuplicateSafety {
                    MortDuplicateSafetyNote()
                }
            }
        } bottom: {
            MortBottomBar { actions() }
        }
    }
}

/// Settlement summary shown after the work is confirmed. Neither party may
/// authoritatively choose the compensated base — the backend decides it.
struct SettlementSummaryView: View {
    let settlement: SettlementResult

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s4) {
            MortStatusPanel(
                tone: settlement.outcome.tone,
                symbol: settlement.outcome.symbol,
                label: settlement.outcome.label,
                detail: settlement.explanation
            )

            MortCard {
                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "Settlement")
                    PaymentLineItem(label: "Originally funded", amount: settlement.fundedBase)
                    MortDivider()
                    PaymentLineItem(
                        label: "Compensated work",
                        amount: settlement.compensatedBase,
                        note: "Decided by MORT from the confirmed job outcome"
                    )
                    MortDivider()
                    PaymentLineItem(
                        label: "MORT fee retained",
                        amount: settlement.feeRetained,
                        isQuiet: true
                    )
                    if settlement.feeRefundedCents > 0 {
                        PaymentLineItem(
                            label: "MORT fee refunded",
                            amount: settlement.feeRefunded,
                            isQuiet: true
                        )
                    }
                    if settlement.hasRefund {
                        MortDivider()
                        PaymentLineItem(
                            label: "Refunded to you",
                            amount: settlement.adultRefund,
                            isTotal: true
                        )
                    }
                }
            }

            MortNote(
                text: "MORT decides the compensated amount from the confirmed job outcome. Neither you nor your worker can set it directly.",
                tone: .info
            )
        }
    }
}
