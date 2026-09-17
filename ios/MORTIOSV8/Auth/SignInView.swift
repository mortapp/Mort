//
//  SignInView.swift
//  MORT iOS V8 — Auth
//

import SwiftUI

struct SignInView: View {
    @Environment(MortSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var showForgot = false

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !session.isWorking
    }

    var body: some View {
        MortScreen(
            title: "Welcome back",
            subtitle: "Sign in to pick up where you left off.",
            atmosphereIntensity: 0.7
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if let error = session.authError {
                    MortStatusPanel(
                        tone: .danger,
                        symbol: "exclamationmark.triangle",
                        label: "COULDN'T SIGN IN",
                        detail: error.userMessage
                    )
                }

                if !session.isOnline {
                    MortOfflineBanner()
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
                        placeholder: "Your password",
                        text: $password
                    )
                }

                MortQuietButton(title: "Forgot your password?") {
                    showForgot = true
                }

                VStack(spacing: MortSpace.s3) {
                    Text("OR CONTINUE WITH")
                        .mortEyebrow()
                        .frame(maxWidth: .infinity)

                    MortGhostButton(title: "Continue with Apple", symbol: "applelogo") {
                        Task { await session.signInWithApple() }
                    }
                    MortGhostButton(title: "Continue with Google", symbol: "globe") {
                        Task { await session.signInWithGoogle() }
                    }
                }
                .padding(.top, MortSpace.s2)
            }
        } bottom: {
            MortBottomBar {
                MortPrimaryButton(
                    title: "Sign in",
                    isBusy: session.isWorking,
                    isEnabled: canSubmit,
                    busyTitle: "Signing in…"
                ) {
                    Task { await session.signIn(email: email, password: password) }
                }
            }
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundStyle(MortColor.textSecondary)
            }
        }
        .onChange(of: email) { _, _ in session.clearError() }
        .onChange(of: password) { _, _ in session.clearError() }
        .sheet(isPresented: $showForgot) {
            NavigationStack { ForgotPasswordView(prefilledEmail: email) }
        }
    }
}

struct ForgotPasswordView: View {
    let prefilledEmail: String

    @Environment(MortSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var sent = false

    init(prefilledEmail: String) {
        self.prefilledEmail = prefilledEmail
        _email = State(initialValue: prefilledEmail)
    }

    var body: some View {
        MortScreen(
            title: sent ? "Check your email" : "Reset your password",
            subtitle: sent
                ? "If that address has a MORT account, a reset link is on its way."
                : "We'll email you a link to set a new password.",
            atmosphereIntensity: 0.7
        ) {
            VStack(alignment: .leading, spacing: MortSpace.s5) {
                if sent {
                    MortStatusPanel(
                        tone: .info,
                        symbol: "envelope.badge",
                        label: "RESET LINK SENT",
                        detail: "For your security we don't confirm whether an account exists for that address."
                    )
                } else {
                    MortTextField(
                        label: "Email",
                        placeholder: "you@example.com",
                        text: $email,
                        symbol: "envelope",
                        keyboard: .emailAddress,
                        capitalization: .never
                    )
                    if let error = session.authError {
                        MortNote(text: error.userMessage, tone: .danger)
                    }
                }
            }
        } bottom: {
            MortBottomBar {
                if sent {
                    MortPrimaryButton(title: "Done") { dismiss() }
                } else {
                    MortPrimaryButton(
                        title: "Send reset link",
                        isBusy: session.isWorking,
                        isEnabled: email.contains("@") && !session.isWorking
                    ) {
                        Task { sent = await session.sendPasswordReset(email: email) }
                    }
                }
            }
        }
        .navigationTitle("Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
                    .foregroundStyle(MortColor.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack { SignInView() }
        .environment(MortDependencies.preview(signedIn: false).session)
}
