//
//  MortButtons.swift
//  MORT iOS V8 — Components
//
//  Silver metallic CTA material — never accent-blue, never a generic tinted
//  system button. Disabled = opacity .38 and no motion. All targets >= 44pt.
//

import SwiftUI

/// Primary silver CTA. The single strongest action on a screen.
struct MortPrimaryButton: View {
    let title: String
    var symbol: String?
    /// In-flight actions disable the button and swap the label — duplicate
    /// taps are impossible by construction.
    var isBusy: Bool = false
    var isEnabled: Bool = true
    var busyTitle: String?
    let action: () -> Void

    @Environment(\.mortReducedMotion) private var reducedMotion
    @State private var pressed = false

    private var effectiveEnabled: Bool { isEnabled && !isBusy }

    var body: some View {
        Button {
            guard effectiveEnabled else { return }
            MortHaptic.tap()
            action()
        } label: {
            HStack(spacing: MortSpace.s2) {
                if isBusy {
                    MortSpinner(size: 16, tint: MortColor.ink1)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(isBusy ? (busyTitle ?? title) : title)
                    .font(MortFont.button())
                    .tracking(0.3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(MortColor.ink1)
            .frame(maxWidth: .infinity)
            .frame(minHeight: MortMetric.controlHeight)
            .padding(.horizontal, MortSpace.s4)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [MortColor.ice2, MortColor.silver2, MortColor.silver1],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .strokeBorder(MortColor.white.opacity(0.45), lineWidth: 1)
            }
            .opacity(effectiveEnabled ? 1 : 0.38)
            .scaleEffect(pressed && !reducedMotion ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!effectiveEnabled)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isBusy ? (busyTitle ?? title) : title)
        .accessibilityHint(effectiveEnabled ? "" : "Currently unavailable")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard effectiveEnabled else { return }
                    withAnimation(MortMotion.respecting(reducedMotion, MortMotion.press)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(MortMotion.respecting(reducedMotion, MortMotion.press)) { pressed = false }
                }
        )
    }
}

/// Secondary outlined action on graphite.
struct MortGhostButton: View {
    let title: String
    var symbol: String?
    var isEnabled: Bool = true
    var tone: MortTone?
    let action: () -> Void

    @Environment(\.mortReducedMotion) private var reducedMotion
    @State private var pressed = false

    var body: some View {
        Button {
            guard isEnabled else { return }
            MortHaptic.tap()
            action()
        } label: {
            HStack(spacing: MortSpace.s2) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                }
                Text(title)
                    .font(MortFont.button())
                    .tracking(0.3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(tone?.color ?? MortColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: MortMetric.controlHeight)
            .padding(.horizontal, MortSpace.s4)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .fill(MortColor.graphite2.opacity(0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .strokeBorder(tone?.color.opacity(0.45) ?? MortColor.borderGraphite2, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.38)
            .scaleEffect(pressed && !reducedMotion ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled else { return }
                    withAnimation(MortMotion.respecting(reducedMotion, MortMotion.press)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(MortMotion.respecting(reducedMotion, MortMotion.press)) { pressed = false }
                }
        )
    }
}

/// Low-emphasis text action.
struct MortQuietButton: View {
    let title: String
    var symbol: String?
    var tone: MortTone = .neutral
    let action: () -> Void

    var body: some View {
        Button {
            MortHaptic.tap()
            action()
        } label: {
            HStack(spacing: MortSpace.s2) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(title)
                    .font(MortFont.label())
            }
            .foregroundStyle(tone == .neutral ? MortColor.textSecondary : tone.color)
            .frame(maxWidth: .infinity)
            .frame(minHeight: MortMetric.minTouchTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Icon-only control (back button, close, overflow). Always 44x44 with a label.
struct MortIconButton: View {
    let symbol: String
    let accessibilityLabel: String
    var tone: Color = MortColor.textPrimary
    let action: () -> Void

    var body: some View {
        Button {
            MortHaptic.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tone)
                .frame(width: MortMetric.minTouchTarget, height: MortMetric.minTouchTarget)
                .background {
                    Circle().fill(MortColor.graphite2.opacity(0.8))
                }
                .overlay {
                    Circle().strokeBorder(MortColor.hairline2, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Destructive action, used for cancellations and emergency-adjacent flows.
struct MortDangerButton: View {
    let title: String
    var symbol: String?
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            MortHaptic.warning()
            action()
        } label: {
            HStack(spacing: MortSpace.s2) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(MortFont.button())
                    .tracking(0.3)
            }
            .foregroundStyle(MortColor.ice2)
            .frame(maxWidth: .infinity)
            .frame(minHeight: MortMetric.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .fill(MortColor.dangerDeep.opacity(0.55))
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.md, style: .continuous)
                    .strokeBorder(MortColor.danger.opacity(0.7), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
