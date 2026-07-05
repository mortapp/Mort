//
//  TermsView.swift
//  MORT
//

import SwiftUI

struct TermsView: View {
    @Environment(SessionStore.self) private var session
    @State private var agreed = false

    private let points: [String] = [
        "Keep all communication inside MORT.",
        "Do not share contact info (phone, email, address, social, payment tags).",
        "Only accept safe jobs in safe, public, daytime settings.",
        "Report unsafe behavior, messages, or jobs right away.",
        "Follow your guardian's rules and local laws.",
        "MORT can moderate, warn, or remove unsafe activity.",
    ]

    var body: some View {
        OnboardingScaffold(
            title: "Safety agreement",
            subtitle: "MORT is built on trust and safety. Please agree to the basics before you continue."
        ) {
            VStack(alignment: .leading, spacing: MortSpacing.md) {
                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                            HStack(alignment: .top, spacing: MortSpacing.sm) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(MortColor.success)
                                    .padding(.top, 2)
                                Text(point)
                                    .font(MortFont.callout())
                                    .foregroundStyle(MortColor.silver)
                            }
                        }
                    }
                }

                Toggle(isOn: $agreed) {
                    Text("I understand and agree to the MORT Safety Agreement (v\(session.termsVersion)).")
                        .font(MortFont.callout())
                        .foregroundStyle(MortColor.primaryText)
                }
                .tint(MortColor.roseGold)

                MortButton(title: "I agree", isDisabled: !agreed) {
                    session.acceptTerms()
                }
            }
        }
    }
}

struct NotificationPrepView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        OnboardingScaffold(
            title: "Stay in the loop",
            subtitle: "Turn on notifications so you never miss a job update, message, or safety reminder."
        ) {
            VStack(spacing: MortSpacing.lg) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(MortColor.roseGold)
                    .padding(.top, MortSpacing.sm)

                MortCard {
                    VStack(alignment: .leading, spacing: MortSpacing.sm) {
                        NotifRow(icon: "briefcase.fill", text: "Job and application updates")
                        NotifRow(icon: "bubble.left.fill", text: "New messages")
                        NotifRow(icon: "shield.fill", text: "Safety reminders & check-ins")
                        NotifRow(icon: "gearshape.fill", text: "Account alerts")
                    }
                }

                Text("MORT sends notifications for job updates, messages, safety reminders, and account alerts.")
                    .font(MortFont.caption())
                    .foregroundStyle(MortColor.darkSilver)
                    .multilineTextAlignment(.center)

                VStack(spacing: MortSpacing.sm) {
                    MortButton(title: "Enable notifications") {
                        // TODO: Request UNUserNotificationCenter authorization on device.
                        session.setNotifications(requested: true)
                    }
                    MortButton(title: "Maybe later", kind: .ghost) {
                        session.setNotifications(requested: false)
                    }
                }
            }
        }
    }
}

private struct NotifRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: MortSpacing.sm) {
            Image(systemName: icon).foregroundStyle(MortColor.roseGold).frame(width: 24)
            Text(text).font(MortFont.callout()).foregroundStyle(MortColor.silver)
            Spacer()
        }
    }
}

struct TransportationView: View {
    @Environment(SessionStore.self) private var session
    @State private var selected: TransportationMode?

    var body: some View {
        OnboardingScaffold(
            title: "How will you get around?",
            subtitle: "This helps us show jobs you can safely reach. Teens only."
        ) {
            VStack(spacing: MortSpacing.sm) {
                ForEach(TransportationMode.allCases) { mode in
                    Button {
                        withAnimation { selected = mode }
                    } label: {
                        HStack(spacing: MortSpacing.md) {
                            Image(systemName: mode.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(selected == mode ? MortColor.productionBlack : MortColor.roseGold)
                                .frame(width: 44, height: 44)
                                .background(selected == mode ? AnyShapeStyle(MortColor.roseGold) : AnyShapeStyle(MortColor.roseGold.opacity(0.14)))
                                .clipShape(.rect(cornerRadius: MortRadius.sm))
                            Text(mode.label)
                                .font(MortFont.headline())
                                .foregroundStyle(MortColor.primaryText)
                            Spacer()
                            if selected == mode {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(MortColor.roseGold)
                            }
                        }
                        .padding(MortSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MortColor.surface)
                        .clipShape(.rect(cornerRadius: MortRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: MortRadius.md)
                                .stroke(selected == mode ? MortColor.roseGold : MortColor.stroke, lineWidth: selected == mode ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                MortButton(title: "Finish setup", isLoading: session.isWorking, isDisabled: selected == nil) {
                    if let mode = selected { session.submitTransportation(mode) }
                }
                .padding(.top, MortSpacing.xs)
            }
        }
    }
}
