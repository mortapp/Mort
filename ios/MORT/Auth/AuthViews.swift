//
//  AuthViews.swift
//  MORT
//
//  Login, signup, and email verification screens.
//

import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        OnboardingScaffold(
            title: "Welcome back",
            subtitle: "Log in to get back in motion.",
            onBack: { session.go(to: .welcome) }
        ) {
            VStack(spacing: MortSpacing.md) {
                MortTextField(title: "Email", text: $email, placeholder: "you@example.com", systemImage: "envelope.fill", keyboard: .emailAddress)
                MortTextField(title: "Password", text: $password, placeholder: "Your password", systemImage: "lock.fill", isSecure: true)

                if let error = session.errorMessage {
                    MortSafetyBanner(staticMessage: error)
                }

                MortButton(title: "Log in", isLoading: session.isWorking) {
                    Task { await session.login(email: email, password: password) }
                }

                Button {
                    session.go(to: .signup)
                } label: {
                    Text("New to MORT? Create an account")
                        .font(MortFont.caption())
                        .foregroundStyle(MortColor.darkSilver)
                }
            }
        }
    }
}

struct SignupView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        OnboardingScaffold(
            title: "Create your account",
            subtitle: "First, your email and a password.",
            onBack: { session.go(to: .welcome) }
        ) {
            VStack(spacing: MortSpacing.md) {
                MortTextField(title: "Email", text: $email, placeholder: "you@example.com", systemImage: "envelope.fill", keyboard: .emailAddress)
                MortTextField(title: "Password", text: $password, placeholder: "At least 6 characters", systemImage: "lock.fill", isSecure: true, helper: "Use 6+ characters.")

                if let error = session.errorMessage {
                    MortSafetyBanner(staticMessage: error)
                }

                MortButton(title: "Continue", isLoading: session.isWorking) {
                    Task { await session.signUp(email: email, password: password) }
                }

                Button {
                    session.go(to: .login)
                } label: {
                    Text("Already have an account? Log in")
                        .font(MortFont.caption())
                        .foregroundStyle(MortColor.darkSilver)
                }
            }
        }
    }
}

struct VerifyEmailView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        OnboardingScaffold(
            title: "Verify your email",
            subtitle: "We sent a verification link to \(session.draft.email).",
            onBack: { session.go(to: .signup) }
        ) {
            VStack(spacing: MortSpacing.lg) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(MortColor.roseGold)
                    .padding(.top, MortSpacing.md)

                Text("Open the email and tap the link to confirm your account. In this demo build, you can continue right away.")
                    .font(MortFont.callout())
                    .foregroundStyle(MortColor.secondaryText)
                    .multilineTextAlignment(.center)

                MortButton(title: "I've verified — continue") {
                    session.go(to: .dob)
                }
            }
        }
    }
}
