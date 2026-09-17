//
//  TipComponents.swift
//  MORT iOS V8 — Tipping Components
//
//  "100% of your tip goes to @username" is the strongest sentence in this
//  flow and is always visible.
//

import SwiftUI

/// The recipient banner — always present in the tip flow.
struct TipRecipientBanner: View {
    let handle: String

    var body: some View {
        HStack(spacing: MortSpace.s3) {
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MortColor.success)
            Text("100% of your tip goes to \(handle)")
                .font(MortFont.bodyStrong())
                .foregroundStyle(MortColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(MortSpace.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                .fill(MortColor.successDim)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                .strokeBorder(MortColor.success.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The tip selector: No tip / $2 / $5 / $10 / 10% / 15% / 20% / Custom.
struct TipSelector: View {
    let baseCents: Int64
    @Binding var selection: TipOption

    private let columns = [
        GridItem(.flexible(), spacing: MortSpace.s2),
        GridItem(.flexible(), spacing: MortSpace.s2),
        GridItem(.flexible(), spacing: MortSpace.s2),
        GridItem(.flexible(), spacing: MortSpace.s2),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s3) {
            MortSectionHeader(title: "Add a tip", subtitle: "Optional — always")
            LazyVGrid(columns: columns, spacing: MortSpace.s2) {
                ForEach(TipOption.standard) { option in
                    MortChip(
                        label: option.label,
                        isSelected: selection == option
                    ) {
                        selection = option
                    }
                }
            }
            if case .percent(let p) = selection,
               let preview = selection.previewCents(baseCents: baseCents) {
                Text("\(p)% of \(Money(cents: baseCents).formatted) base pay = \(Money(cents: preview).formatted)")
                    .mortMicro()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tip amount")
    }
}

/// The five tip rules. These are product guarantees, not marketing.
struct TipRulesNote: View {
    var body: some View {
        MortInsetSurface {
            VStack(alignment: .leading, spacing: MortSpace.s2) {
                MortNote(text: "Tipping is always optional.", tone: .neutral, symbol: "hand.thumbsup")
                MortNote(text: "Your worker keeps 100% of the tip.", tone: .neutral, symbol: "person.fill.checkmark")
                MortNote(text: "MORT never charges a fee on a tip.", tone: .neutral, symbol: "percent")
                MortNote(text: "Tips don't count toward Fair Pay.", tone: .neutral, symbol: "scalemass")
                MortNote(text: "A tip is its own payment — if it fails, the job payment stays settled.", tone: .neutral, symbol: "arrow.triangle.branch")
            }
        }
    }
}

/// Custom tip entry with live validation states.
struct CustomTipInput: View {
    @Binding var text: String
    let config: TipConfig

    var validation: CustomTipValidation {
        CustomTipValidation.evaluate(text, config: config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s3) {
            MortMoneyField(
                label: "Custom tip",
                text: $text,
                tone: validation.tone,
                message: validation.message
            )
            MortNote(
                text: "Tips here can be \(config.minimum.formatted)–\(config.maximum.formatted).",
                tone: .neutral
            )
        }
    }
}

/// Confirmation block shown before the tip is submitted.
struct TipConfirmationBlock: View {
    let tip: Money
    let handle: String
    let baseCents: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s4) {
            MortCard {
                VStack(alignment: .leading, spacing: MortSpace.s3) {
                    MortSectionHeader(title: "Tip summary")
                    PaymentLineItem(
                        label: "Base pay (already settled)",
                        amount: Money(cents: baseCents),
                        isQuiet: true
                    )
                    MortDivider()
                    PaymentLineItem(
                        label: "Tip",
                        amount: tip,
                        note: "100% of your tip goes to \(handle)"
                    )
                    MortDivider()
                    PaymentLineItem(label: "MORT fee on tip", amount: .zero, isQuiet: true)
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
                    PaymentLineItem(label: "You'll be charged", amount: tip, isTotal: true)
                }
            }
            MortNote(
                text: "This is a separate payment from the job. Your worker gets a separate tip receipt.",
                tone: .info
            )
        }
    }
}
