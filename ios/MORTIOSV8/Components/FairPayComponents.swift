//
//  FairPayComponents.swift
//  MORT iOS V8 — Fair Pay Components
//
//  The backend owns the band and the hard minimum and re-validates on submit.
//  Disabling the POST button here is UX, not security.
//
//  Copy is never shaming — it tells the poster how to fix the offer.
//  Tips are EXCLUDED from Fair Pay, always.
//

import SwiftUI

/// The verdict block: icon + title + body, announced to assistive tech.
struct FairPayVerdictView: View {
    let verdict: FairPayVerdict

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s2) {
            HStack(spacing: MortSpace.s2) {
                Image(systemName: verdict.zone.symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(verdict.title)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(verdict.zone.tone.color)

            Text(verdict.body)
                .mortBody()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MortSpace.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                .fill(verdict.zone.tone.dim)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                .strokeBorder(verdict.zone.tone.color.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(verdict.title). \(verdict.body)")
        // Live region: zone changes are announced as the offer moves.
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The recommended-band range bar with a hard-minimum marker and the current
/// offer knob.
struct FairPayRangeBar: View {
    let offeredCents: Int64
    let policy: FairPayPolicy
    let zone: FairPayZone

    /// Scale tops out above the band so the knob has headroom.
    private var scaleMax: Int64 {
        max(policy.recommendedHighCents + 800, offeredCents + 400)
    }

    private func fraction(_ cents: Int64) -> Double {
        guard scaleMax > 0 else { return 0 }
        return min(1, max(0, Double(cents) / Double(scaleMax)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s3) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(MortColor.graphite3)
                        .frame(height: 8)

                    // Recommended band
                    Capsule()
                        .fill(MortColor.success.opacity(0.35))
                        .frame(
                            width: max(
                                0,
                                w * (fraction(policy.recommendedHighCents) - fraction(policy.recommendedLowCents))
                            ),
                            height: 8
                        )
                        .offset(x: w * fraction(policy.recommendedLowCents))

                    // Hard minimum marker
                    Rectangle()
                        .fill(MortColor.danger)
                        .frame(width: 2, height: 18)
                        .offset(x: w * fraction(policy.hardMinimumCents))

                    // Offer knob
                    Circle()
                        .fill(zone.tone.color)
                        .frame(width: 16, height: 16)
                        .overlay { Circle().strokeBorder(MortColor.ink1, lineWidth: 2) }
                        .offset(x: max(0, w * fraction(offeredCents) - 8))
                }
                .frame(height: 20)
            }
            .frame(height: 20)

            HStack(spacing: MortSpace.s3) {
                legend(color: MortColor.success.opacity(0.7), text: "Recommended \(policy.bandText)")
                Spacer(minLength: MortSpace.s2)
                legend(color: MortColor.danger, text: "Min \(policy.hardMinimum.formatted)")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Offer \(Money(cents: offeredCents).formatted). Recommended \(policy.bandText). Minimum \(policy.hardMinimum.formatted)."
        )
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: MortSpace.s1 + 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 6)
            Text(text)
                .mortMicro()
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Amount stepper used to move an offer across zones live (±$1).
struct FairPayAmountStepper: View {
    @Binding var cents: Int64
    var step: Int64 = 100

    var body: some View {
        HStack(spacing: MortSpace.s3) {
            stepButton(symbol: "minus", label: "Decrease offer by one dollar") {
                cents = max(0, cents - step)
            }

            VStack(spacing: 2) {
                Text(Money(cents: cents).formatted)
                    .font(MortFont.money(34, weight: .light))
                    .foregroundStyle(MortColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("OFFERED")
                    .mortEyebrow()
            }
            .frame(maxWidth: .infinity)

            stepButton(symbol: "plus", label: "Increase offer by one dollar") {
                cents += step
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func stepButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            MortHaptic.select()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MortColor.textPrimary)
                .frame(width: MortMetric.minTouchTarget, height: MortMetric.minTouchTarget)
                .background { Circle().fill(MortColor.graphite3) }
                .overlay { Circle().strokeBorder(MortColor.borderGraphite2, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The complete guardrail: offer control, range, verdict and the rules note.
struct FairPayGuardrail: View {
    @Binding var offeredCents: Int64
    let policy: FairPayPolicy

    var verdict: FairPayVerdict {
        FairPayVerdict.evaluate(offeredCents: offeredCents, policy: policy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpace.s5) {
            MortCard {
                VStack(alignment: .leading, spacing: MortSpace.s5) {
                    MortSectionHeader(title: "Base pay", subtitle: policy.jobTypeLabel)
                    FairPayAmountStepper(cents: $offeredCents)
                    FairPayRangeBar(
                        offeredCents: offeredCents,
                        policy: policy,
                        zone: verdict.zone
                    )
                }
            }

            FairPayVerdictView(verdict: verdict)

            MortInsetSurface {
                VStack(alignment: .leading, spacing: MortSpace.s2) {
                    MortNote(
                        text: "Fair Pay looks at base pay only. Tips are never counted toward it.",
                        tone: .neutral,
                        symbol: "hand.thumbsup"
                    )
                    MortNote(
                        text: "MORT checks the offer again when you post, so the final decision always comes from MORT.",
                        tone: .neutral,
                        symbol: "shield.lefthalf.filled"
                    )
                }
            }
        }
    }
}
