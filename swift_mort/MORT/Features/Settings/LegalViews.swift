import SwiftUI

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MortSpacing.lg) {
                Text(document.title).font(MortTypography.title)
                ForEach(sections, id: \.0) { section in
                    VStack(alignment: .leading, spacing: MortSpacing.xs) {
                        Text(section.0).font(MortTypography.section)
                        Text(section.1).foregroundStyle(MortColors.textMuted)
                    }
                }
                MortAlertBanner(
                    title: "Pre-release legal draft",
                    message: "These in-app summaries must be reviewed and replaced or approved by qualified legal, privacy, and teen-safety counsel before public release.",
                    tint: MortColors.warning,
                    icon: "doc.badge.clock"
                )
            }
            .padding(MortSpacing.lg)
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .mortScreen()
    }

    private var sections: [(String, String)] {
        switch document {
        case .terms:
            [("Use MORT honestly", "Users must provide accurate account information and follow role, age, job, moderation, and safety rules."), ("Marketplace limits", "MORT connects people but is not an employer, payment processor, escrow provider, emergency service, or guarantee of work or payment.")]
        case .privacy:
            [("Data used", "MORT uses account, profile, marketplace, message-safety, report, verification, storage, notification, and purchase-entitlement data to operate the service."), ("Private media", "Avatars, proof, verification, and report uploads use private Supabase storage and short-lived authorized URLs.")]
        case .communityRules:
            [("Keep it safe", "No harassment, discrimination, sexual content, exploitation, scams, dangerous work, weapons, drugs, or requests to evade MORT safety controls."), ("Keep contact in MORT", "Do not pressure teens to move communication off-platform or share exact private locations.")]
        case .paymentDisclaimer:
            [("Preference only", "MORT records payment preferences but does not process money, hold funds, provide escrow, or guarantee payment."), ("Avoid scams", "Never pay deposits, buy gift cards, share account credentials, or send verification codes.")]
        case .verificationDisclaimer:
            [("Limited signal", "Verification reflects only the checks MORT actually completed and is not a guarantee of identity, safety, quality, solvency, or conduct.")]
        case .adDisclosure:
            [("Optional advertising", "Ads remain disabled until native review. When enabled, sensitive screens are excluded and backend eligibility is required."), ("Teen treatment", "MORT requests restricted or non-personalized ad treatment where required and respects ad-free entitlements.")]
        case .subscriptionDisclosure:
            [("Optional perks", "Subscriptions and one-time purchases add style, convenience, or business tools. Core applying and safety tools remain free."), ("Store billing", "Apple and RevenueCat provide the actual localized price, renewal, cancellation, and entitlement status.")]
        case .teenSafety:
            [("Personal safety", "Use general locations, keep communication in MORT, tell a trusted person about work, and leave any situation that feels unsafe."), ("Urgent help", "MORT is not emergency services. Contact local emergency services or a trusted adult when immediate help is needed.")]
        case .guardianGuide:
            [("Optional mode", "Guardian Mode is optional and shares only backend-authorized safety information and selected alerts."), ("Teen privacy", "Guardians do not receive unrestricted access to private message content.")]
        case .aiTransparency:
            [("Safety assistance", "MORT may use rules and machine-assisted signals to flag risky job or message content for prevention and moderation."), ("Human decisions", "Automated signals can be imperfect. Reports and high-impact moderation require appropriate review and appeal processes.")]
        }
    }
}

struct UnavailableFeatureView: View {
    let title: String
    let reason: String

    var body: some View {
        MortEmptyState(title: title, message: reason, systemImage: "hammer.fill")
            .navigationTitle(title)
            .mortScreen()
    }
}
