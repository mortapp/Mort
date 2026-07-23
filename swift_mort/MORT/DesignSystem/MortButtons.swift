import SwiftUI

struct MortPrimaryButton: View {
    let title: String
    var icon: String?
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MortSpacing.xs) {
                if isLoading { ProgressView().tint(MortColors.background) }
                else if let icon { Image(systemName: icon) }
                Text(title).font(MortTypography.label)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(MortFilledButtonStyle(background: MortColors.neon, foreground: MortColors.background))
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct MortSecondaryButton: View {
    let title: String
    var icon: String?
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon ?? "arrow.right")
                .font(MortTypography.label)
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(MortOutlineButtonStyle(tint: MortColors.text))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct MortDangerButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(MortTypography.label)
            .frame(maxWidth: .infinity, minHeight: 46)
            .buttonStyle(MortFilledButtonStyle(background: MortColors.danger, foreground: .white))
    }
}

struct MortIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MortColors.text)
        .background(MortColors.cardAlternate, in: RoundedRectangle(cornerRadius: MortRadius.medium))
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct MortFilledButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, MortSpacing.md)
            .background(background.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(MortAnimation.quick, value: configuration.isPressed)
    }
}

private struct MortOutlineButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .padding(.horizontal, MortSpacing.md)
            .background(MortColors.card.opacity(configuration.isPressed ? 0.75 : 1))
            .overlay(RoundedRectangle(cornerRadius: MortRadius.medium).stroke(MortColors.line))
            .clipShape(RoundedRectangle(cornerRadius: MortRadius.medium))
    }
}
