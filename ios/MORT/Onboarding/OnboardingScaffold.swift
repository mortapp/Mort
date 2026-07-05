//
//  OnboardingScaffold.swift
//  MORT
//
//  Shared layout for onboarding step screens with a back control and scroll.
//

import SwiftUI

struct OnboardingScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(MortColor.primaryText)
                            .frame(width: 40, height: 40)
                            .background(MortColor.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(MortColor.stroke, lineWidth: 1))
                    }
                }

                VStack(alignment: .leading, spacing: MortSpacing.xs) {
                    Text(title)
                        .font(MortFont.largeTitle())
                        .foregroundStyle(MortColor.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(MortFont.body())
                            .foregroundStyle(MortColor.secondaryText)
                    }
                }

                content
            }
            .padding(.horizontal, MortSpacing.md)
            .padding(.top, MortSpacing.md)
            .padding(.bottom, MortSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .mortScreen()
    }
}
