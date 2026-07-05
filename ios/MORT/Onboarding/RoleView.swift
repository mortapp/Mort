//
//  RoleView.swift
//  MORT
//

import SwiftUI

struct RoleView: View {
    @Environment(SessionStore.self) private var session
    @State private var selected: UserRole?

    private var options: [UserRole] {
        UserRole.selectable(for: session.draft.ageGroup)
    }

    var body: some View {
        OnboardingScaffold(
            title: "Choose your role",
            subtitle: session.draft.ageGroup == .teen
                ? "As a teen, you'll use MORT to find safe local hustles."
                : "Pick how you'll use MORT. You can only manage one role per account."
        ) {
            VStack(spacing: MortSpacing.md) {
                if session.draft.ageGroup == .teen {
                    MortRoleCard(role: .teen, isSelected: true) { selected = .teen }
                    MortSafetyBanner(staticMessage: "Teen accounts cannot select adult, business, or guardian roles. Admin is not available to sign up.")
                } else {
                    ForEach(options) { role in
                        MortRoleCard(role: role, isSelected: selected == role) {
                            withAnimation { selected = role }
                        }
                    }
                    MortSafetyBanner(staticMessage: "Admin access is internal only and not available during signup.")
                }

                MortButton(title: "Continue", isDisabled: effectiveRole == nil) {
                    if let role = effectiveRole { session.submitRole(role) }
                }
            }
        }
        .onAppear {
            if session.draft.ageGroup == .teen { selected = .teen }
        }
    }

    private var effectiveRole: UserRole? {
        session.draft.ageGroup == .teen ? .teen : selected
    }
}
