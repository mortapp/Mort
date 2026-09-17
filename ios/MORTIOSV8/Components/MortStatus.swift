//
//  MortStatus.swift
//  MORT iOS V8 — Components
//
//  ACCESSIBILITY LAW: a status is NEVER communicated by color alone.
//  Every status surface in MORT renders tone + icon + text together.
//

import SwiftUI

/// Compact status pill: tint + icon + label.
struct MortStatusPill: View {
    let tone: MortTone
    let symbol: String
    let label: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: MortSpace.s1 + 2) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
            Text(label.uppercased())
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .tracking(0.6)
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, compact ? MortSpace.s2 : MortSpace.s3)
        .padding(.vertical, compact ? 4 : 6)
        .background {
            Capsule(style: .continuous).fill(tone.dim)
        }
        .overlay {
            Capsule(style: .continuous).strokeBorder(tone.color.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(label)")
    }
}

/// A prominent status block with an icon, label, and explanatory copy.
struct MortStatusPanel: View {
    let tone: MortTone
    let symbol: String
    let label: String
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: MortSpace.s3) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tone.color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: MortSpace.s1) {
                Text(label.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(tone.color)
                if let detail {
                    Text(detail)
                        .mortBody()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(MortSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous).fill(tone.dim)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                .strokeBorder(tone.color.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Inline note with an icon. Used for guidance, warnings and hard rules.
struct MortNote: View {
    let text: String
    var tone: MortTone = .neutral
    var symbol: String?

    private var resolvedSymbol: String {
        if let symbol { return symbol }
        return switch tone {
        case .success: "checkmark.circle"
        case .danger: "exclamationmark.triangle"
        case .warning: "exclamationmark.circle"
        case .info: "info.circle"
        case .neutral: "info.circle"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: MortSpace.s2) {
            Image(systemName: resolvedSymbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tone == .neutral ? MortColor.textMuted : tone.color)
                .padding(.top, 2)
            Text(text)
                .font(MortFont.micro())
                .foregroundStyle(tone == .neutral ? MortColor.textMuted : tone.color.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The strict "no receipt" banner. Failed transactions receive NO receipt —
/// this must be explicit, never implied.
struct MortNoReceiptBanner: View {
    var body: some View {
        HStack(spacing: MortSpace.s2) {
            Image(systemName: "doc.badge.ellipsis")
                .font(.system(size: 13, weight: .semibold))
            Text("NO RECEIPT WAS CREATED")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.8)
            Spacer(minLength: 0)
        }
        .foregroundStyle(MortColor.textSecondary)
        .padding(.horizontal, MortSpace.s3)
        .padding(.vertical, MortSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                .fill(MortColor.neutralDim)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                .strokeBorder(MortColor.hairline2, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No receipt was created for this payment")
    }
}

/// Duplicate-payment protection reassurance. Shown during and after in-flight
/// states so users never feel pressure to submit twice.
struct MortDuplicateSafetyNote: View {
    var body: some View {
        MortNote(
            text: "MORT blocks duplicate payments for the same job. If you're unsure, check the payment status instead of paying again.",
            tone: .info,
            symbol: "shield.checkerboard"
        )
    }
}

/// Calm, restrained loading spinner. Meaning survives Reduce Motion because
/// the accompanying status text always states what is happening.
struct MortSpinner: View {
    var size: CGFloat = 20
    var tint: Color = MortColor.silver2

    @Environment(\.mortReducedMotion) private var reducedMotion
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.72)
            .stroke(
                AngularGradient(
                    colors: [tint.opacity(0), tint],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: max(1.6, size / 11), lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                guard !reducedMotion else { return }
                withAnimation(.linear(duration: 0.95).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
            .accessibilityHidden(true)
    }
}
