//
//  WelcomeView.swift
//  MORT
//

import SwiftUI

struct WelcomeView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: MortSpacing.lg) {
            Spacer()

            VStack(spacing: MortSpacing.sm) {
                Text("MORT")
                    .font(MortFont.wordmark())
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(colors: [MortColor.offWhite, MortColor.roseGold], startPoint: .leading, endPoint: .trailing)
                    )
                Text("GET IN MOTION")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(MortColor.secondaryText)
            }

            Text("A teen-safe local hustle marketplace. Find safe local work, post jobs, and stay protected — built for ages 13+.")
                .font(MortFont.body())
                .foregroundStyle(MortColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MortSpacing.lg)

            VStack(spacing: MortSpacing.sm) {
                FeatureRow(icon: "shield.lefthalf.filled", text: "Built-in safety scanning on every post and message")
                FeatureRow(icon: "person.2.fill", text: "Roles for teens, adults, businesses, and guardians")
                FeatureRow(icon: "checkmark.seal.fill", text: "Moderation and trusted-circle check-ins")
            }
            .padding(.horizontal, MortSpacing.md)

            Spacer()

            VStack(spacing: MortSpacing.sm) {
                MortButton(title: "Create account", systemImage: "sparkles") {
                    session.go(to: .signup)
                }
                MortButton(title: "I already have an account", kind: .ghost) {
                    session.go(to: .login)
                }

                Menu {
                    ForEach([UserRole.teen, .adult, .business, .guardian, .admin], id: \.self) { role in
                        Button("Explore as \(role.title)") { session.enterDemo(as: role) }
                    }
                } label: {
                    Text("Explore a demo dashboard")
                        .font(MortFont.caption())
                        .foregroundStyle(MortColor.darkSilver)
                        .padding(.top, MortSpacing.xs)
                }
            }
            .padding(.horizontal, MortSpacing.md)
        }
        .padding(.bottom, MortSpacing.lg)
        .mortScreen()
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: MortSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MortColor.roseGold)
                .frame(width: 26)
            Text(text)
                .font(MortFont.callout())
                .foregroundStyle(MortColor.silver)
            Spacer()
        }
    }
}
