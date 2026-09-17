//
//  CreateAccountView.swift
//  MORT iOS V8 — Auth
//
//  Role selection happens up front because teen, adult and guardian have
//  genuinely different onboarding, safety and financial surfaces.
//
//  MORT deliberately does not collect information it doesn't need.
//

import SwiftUI

struct CreateAccountView: View {
    @Environment(MortSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var role: MortRole?
    @State private var email = ""
    @State private var password = ""
    @State private var acceptedTerms = false

    private var canSubmit: Bool {
        role != nil && email.contains("@") && password.count >= 8 && acceptedTerms && !session.isWorking
    }

    var body: some View {
        MortScreen(
            title: "Create your account",
            subtitle: "Tell us how you'll use MORT. You can't change this later, so pick the one that fits.",
            atmosphereIntensity: 0.7
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error = session.authError {
                    MortStatusPanel(
                        tone: .danger,
                        symbol: "exclamationmark.triangle",
                        label: "COULDN'T CREATE ACCOUNT",
                        detail: error.userMessage
                    )
                }

                VStack(spacing: MortSpace.s3) {
                    ForEach(MortRole.allCases) { option in
                        RoleCard(role: option, isSelected: role == option) {
                            role = option
                        }
                    }
                }

                VStack(spacing: MortSpace.s4) {
                    MortTextField(
                        label: "Email",
                        placeholder: "you@example.com",
                        text: $email,
                        symbol: "envelope",
                        keyboard: .emailAddress,
                        capitalization: .never
                    )
                    MortSecureField(
                        label: "Password",
                        placeholder: "At least 8 characters",
                        text: $password,
                        errorText: password.isEmpty || password.count >= 8
                            ? nil
                            : "Use at least 8 characters.",
                        helpText: "Longer is stronger. Avoid something you use elsewhere."
                    )
                }

                Button {
                    acceptedTerms.toggle()
                    MortHaptic.select()
                } label: {
                    HStack(alignment: .top, spacing: MortSpace.s3) {
                        Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundStyle(acceptedTerms ? MortColor.silver2 : MortColor.textMuted)
                        Text("I agree to the MORT Terms and Privacy Policy, and I understand teen accounts include guardian visibility.")
                            .mortMicro()
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: MortMetric.minTouchTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agree to the Terms and Privacy Policy")
                .accessibilityValue(acceptedTerms ? "Agreed" : "Not agreed")

                if role == .teen {
                    MortNote(
                        text: "We'll help you invite a guardian right after this. A teen account isn't fully active until a guardian is linked.",
                        tone: .info
                    )
                }
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "Create account",
                    isBusy: session.isWorking,
                    isEnabled: canSubmit,
                    busyTitle: "Creating…"
                ) {
                    guard let role else { return }
                    Task { await session.signUp(email: email, password: password, role: role) }
                }
                MortQuietButton(title: "I already have an account") { dismiss() }
            }
        }
        .navigationTitle("Get started")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundStyle(MortColor.textSecondary)
            }
        }
    }
}

private struct RoleCard: View {
    let role: MortRole
    let isSelected: Bool
    let action: () -> Void

    private var symbol: String {
        switch role {
        case .teen: "figure.wave"
        case .adult: "house"
        case .guardian: "person.2"
        }
    }

    private var detail: String {
        switch role {
        case .teen: "I'm a teen who wants to find work nearby."
        case .adult: "I need help with jobs around my home."
        case .guardian: "I'm a parent or guardian supervising a teen."
        }
    }

    var body: some View {
        Button {
            MortHaptic.select()
            action()
        } label: {
            HStack(spacing: MortSpace.s3) {
                ZStack {
                    Circle()
                        .fill(isSelected ? MortColor.silver2.opacity(0.18) : MortColor.graphite3)
                        .frame(width: 42, height: 42)
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(isSelected ? MortColor.ice1 : MortColor.silver1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.displayName).mortBodyStrong()
                    Text(detail)
                        .mortMicro()
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: MortSpace.s2)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? MortColor.success : MortColor.textMuted)
            }
            .padding(MortSpace.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                    .fill(isSelected ? MortColor.graphite3.opacity(0.9) : MortColor.cardBg2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MortRadius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected ? MortColor.borderSilver : MortColor.hairline2,
                        lineWidth: 1
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(role.displayName). \(detail)")
    }
}

#Preview {
    NavigationStack { CreateAccountView() }
        .environment(MortDependencies.preview(signedIn: false).session)
}
