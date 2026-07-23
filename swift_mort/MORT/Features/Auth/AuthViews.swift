import SwiftUI

private enum AuthScreen: Hashable {
    case signIn
    case signUp
    case forgotPassword
}

struct AuthView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.xl) {
                    Spacer(minLength: 64)
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        Text("MORT")
                            .font(.system(size: 58, weight: .black, design: .rounded))
                            .foregroundStyle(MortColors.neon)
                        Text("Local work. Real people. Safer hustle.")
                            .font(MortTypography.title)
                        Text("Teens find nearby opportunities, adults post real jobs, and guardians can opt into safety tools.")
                            .foregroundStyle(MortColors.textMuted)
                    }

                    MortSafetyBanner(message: "MORT is for ages 13 and up. Reports, blocking, and Safety Ping are always free.")

                    VStack(spacing: MortSpacing.sm) {
                        NavigationLink(value: AuthScreen.signUp) {
                            Label("Create account", systemImage: "person.badge.plus")
                                .font(MortTypography.label)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MortColors.neon)
                        .foregroundStyle(MortColors.background)

                        NavigationLink(value: AuthScreen.signIn) {
                            Text("Sign in").font(MortTypography.label).frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.bordered)
                        .tint(MortColors.text)
                    }
                }
                .padding(MortSpacing.lg)
            }
            .navigationDestination(for: AuthScreen.self) { screen in
                switch screen {
                case .signIn: SignInView()
                case .signUp: SignUpView()
                case .forgotPassword: ForgotPasswordView()
                }
            }
            .mortScreen()
        }
    }
}

struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Welcome back", subtitle: "Sign in with your Supabase Auth account.")
                MortTextField(title: "Email", text: $email, prompt: "you@example.com", keyboardType: .emailAddress, textContentType: .emailAddress)
                MortSecureField(title: "Password", text: $password)
                MortPrimaryButton(title: "Sign in", icon: "arrow.right", isLoading: session.isWorking) {
                    Task { await session.signIn(email: email, password: password) }
                }
                NavigationLink("Forgot password?", value: AuthScreen.forgotPassword)
                    .font(MortTypography.label)
                    .foregroundStyle(MortColors.safetyBlue)
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }
}

struct SignUpView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var accepted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                MortSectionHeader(title: "Create your account", subtitle: "Your age and role are verified during onboarding.")
                MortTextField(title: "Email", text: $email, prompt: "you@example.com", keyboardType: .emailAddress, textContentType: .emailAddress)
                MortSecureField(title: "Password", text: $password)
                MortSecureField(title: "Confirm password", text: $confirmation)
                Toggle("I agree to the Terms, Privacy Policy, and Community Rules.", isOn: $accepted)
                    .tint(MortColors.neon)
                MortPrimaryButton(
                    title: "Create account",
                    icon: "person.badge.plus",
                    isLoading: session.isWorking,
                    isDisabled: !accepted || password != confirmation
                ) {
                    Task { await session.signUp(email: email, password: password) }
                }
                Text("MORT uses email verification. Never share your password or verification link.")
                    .font(MortTypography.caption)
                    .foregroundStyle(MortColors.textMuted)
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }
}

struct ForgotPasswordView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "Reset password", subtitle: "We will send a secure recovery link if the account exists.")
            MortTextField(title: "Email", text: $email, prompt: "you@example.com", keyboardType: .emailAddress, textContentType: .emailAddress)
            MortPrimaryButton(title: "Send recovery link", icon: "envelope", isLoading: session.isWorking) {
                Task { await session.sendPasswordReset(email: email) }
            }
            Spacer()
        }
        .padding(MortSpacing.lg)
        .navigationTitle("Password reset")
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }
}

struct EmailConfirmationView: View {
    @Environment(SessionStore.self) private var session
    let email: String

    var body: some View {
        VStack(spacing: MortSpacing.lg) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 52))
                .foregroundStyle(MortColors.safetyBlue)
            Text("Check your email").font(MortTypography.title)
            Text("We sent a confirmation link to \(email). Open it on this device, then return to MORT.")
                .multilineTextAlignment(.center)
                .foregroundStyle(MortColors.textMuted)
            MortSecondaryButton(title: "I confirmed my email", icon: "arrow.clockwise") {
                Task { await session.restore() }
            }
            MortSecondaryButton(title: "Use another account", icon: "rectangle.portrait.and.arrow.right") {
                Task { await session.signOut() }
            }
        }
        .padding(MortSpacing.xl)
        .mortScreen()
    }
}

struct PasswordRecoveryView: View {
    @Environment(SessionStore.self) private var session
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: MortSpacing.lg) {
            MortSectionHeader(title: "Choose a new password", subtitle: "Use a unique password you do not use elsewhere.")
            MortSecureField(title: "New password", text: $password)
            MortSecureField(title: "Confirm password", text: $confirmation)
            MortPrimaryButton(
                title: "Update password",
                icon: "key.fill",
                isLoading: session.isWorking,
                isDisabled: password != confirmation
            ) {
                Task { await session.updateRecoveredPassword(password) }
            }
            Spacer()
        }
        .padding(MortSpacing.lg)
        .mortScreen()
    }
}

struct RestrictedAccountView: View {
    @Environment(SessionStore.self) private var session
    let status: String

    var body: some View {
        VStack(spacing: MortSpacing.lg) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(MortColors.warning)
            Text("Account access limited").font(MortTypography.title)
            Text("Status: \(status.replacingOccurrences(of: "_", with: " ").capitalized)")
                .foregroundStyle(MortColors.textMuted)
            Text("Contact support if you believe this is a mistake. Safety restrictions are enforced by the backend, not by hidden buttons.")
                .multilineTextAlignment(.center)
                .foregroundStyle(MortColors.textMuted)
            MortSecondaryButton(title: "Sign out", icon: "rectangle.portrait.and.arrow.right") {
                Task { await session.signOut() }
            }
        }
        .padding(MortSpacing.xl)
        .mortScreen()
    }
}
