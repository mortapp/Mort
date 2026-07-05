//
//  DOBView.swift
//  MORT
//

import SwiftUI

struct DOBView: View {
    @Environment(SessionStore.self) private var session
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -15, to: Date()) ?? Date()

    private var maxDate: Date { Date() }

    var body: some View {
        OnboardingScaffold(
            title: "Your date of birth",
            subtitle: "MORT keeps people safe by matching the right experience to your age. Your birth date stays private.",
            onBack: { session.go(to: .welcome) }
        ) {
            VStack(spacing: MortSpacing.lg) {
                DatePicker("Date of birth", selection: $birthDate, in: ...maxDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(MortColor.roseGold)
                    .padding(MortSpacing.sm)
                    .mortSurface()

                MortSafetyBanner(staticMessage: "Your birth date is stored privately and never shown to other users.")

                MortButton(title: "Continue") {
                    session.submitBirthDate(birthDate)
                }
            }
        }
    }
}

struct UnderageBlockedView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: MortSpacing.lg) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundStyle(MortColor.danger)
            Text("MORT is only available for users 13 and older.")
                .font(MortFont.title())
                .foregroundStyle(MortColor.primaryText)
                .multilineTextAlignment(.center)
            Text("Thanks for your interest. Please come back when you're old enough to join safely.")
                .font(MortFont.body())
                .foregroundStyle(MortColor.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            MortButton(title: "Back to start", kind: .ghost) {
                session.resetFromBlocked()
            }
        }
        .padding(MortSpacing.lg)
        .mortScreen()
    }
}
