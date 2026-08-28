# Design System

Direction: premium dark streetwear-tech, iPhone-first, high contrast, large tap targets.

## Tokens

- black/near-black background
- dark cards
- white primary text
- soft gray secondary text
- neon green primary
- safety blue info
- warning orange
- danger red
- premium purple reserved for perks

## Components

Implemented or exported:

- AppScreen, AppHeader, AppCard, AppButton
- AppInput, AppTextArea, AppSelect
- AppBadge, AppAvatar, AppToast
- LoadingState, EmptyState, ErrorState, SkeletonCard
- SafetyBanner, PaymentDisclaimer, VerificationDisclaimer, GuardianModeBanner
- PaywallCard, PlanCard, FeatureLockCard, PremiumBadge, AdFreeBadge
- JobStatusBadge, UserTrustBadge, CategoryPill, ProfileCompletionMeter
- StatCard, ActionRow, NotificationBell, ProgressBar, Stepper, ConfirmationModal

Ads and monetization components are guarded and default to disabled/setup-required states until real native testing is complete.
