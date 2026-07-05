//
//  OnboardingFlowView.swift
//  MORT
//
//  Routes between onboarding steps based on the session state.
//

import SwiftUI

struct OnboardingFlowView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.step {
            case .welcome: WelcomeView()
            case .login: LoginView()
            case .signup: SignupView()
            case .verifyEmail: VerifyEmailView()
            case .dob: DOBView()
            case .username: UsernameView()
            case .role: RoleView()
            case .terms: TermsView()
            case .notifications: NotificationPrepView()
            case .transportation: TransportationView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        ))
    }
}
