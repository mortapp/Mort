# MORT Design System

Updated: 2026-07-29

## Scope

This is the code-controlled visual and interaction contract for the
authoritative Flutter application in `flutter_mort`. It does not replace
server authorization, physical-device accessibility testing, or legal review.

## Visual Language

- Deep black surfaces use `MortColors.bg`, `bgSecondary`, and `bgElevated`.
- Metallic rose-gold is the primary brand and action language. The supplied
  MORT arrow is rendered by `MortBrandMark` and is also the source for adaptive
  Android, iOS, and web icons.
- Light blue is reserved for safety, verification, information, location, and
  transportation. It is not a second primary brand color.
- Red is reserved for danger, validation errors, and destructive actions.
- Glass surfaces use `MortGlassCard`; blur is opt-in and is not enabled on
  high-volume list cards.
- Spacing, radii, shadows, gradients, motion, typography, and icon sizes are
  centralized under `lib/core/theme`.

## Reusable Components

`MortScreen` provides safe areas, a 760 px maximum content width, scrolling,
and a consistent background. `MortGlassCard`, `MortButton`, `MortTextField`,
`MortDropdown`, `MortBadge`, `MortTopBar`, and `MortBottomNavigation` form the
base control set. Loading, skeleton, empty, error, confirmation, sheet,
snackbar, safety, verification, guardian, and payment-disclaimer states are
shared components rather than page-specific placeholders.

Touch controls use a minimum 48 px target. Icon-only controls require a
tooltip. Brand, job, price, and PIN components provide semantic labels. Focus
and text-selection states use the safety-blue accent. Core animations become
zero-duration when the platform requests reduced motion.

The PIN, price, and job-card headers adapt to narrow layouts and large text.
Screens resize for the keyboard through Flutter's default Scaffold behavior;
long forms use scrolling surfaces. Native and web layouts share the same
bounded content contract.

## Navigation And Authorization

The router currently resolves 184 Flutter routes with no unresolved builder.
Public routes are limited to splash/welcome, authentication callbacks,
password recovery, the public Support entry, and legal disclosures. Private
routes use `GuardedRoute`; teen, adult, guardian, and admin prefixes also carry
an explicit role guard. Reviewer routes exist only in the reviewer build
profile and require an isolated local reviewer session with no production Auth
session.

Restricted and deletion-pending accounts are stopped before role routing.
Incomplete profiles are limited to onboarding routes. Support staff,
moderator, specialized safety, financial, and admin actions remain
server-authorized by RLS and role-specific RPCs; a visible client route never
grants those capabilities.

Deep-link callbacks have exact URI validation and duplicate-completion
suppression. Parameterized routes remain guarded. Unknown routes render the
shared error state instead of a blank screen.

## Verification

Run from the repository root:

```powershell
node scripts/build-route-action-inventory.mjs
node scripts/qa-design-navigation.mjs
```

Run from `flutter_mort`:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
```

Automated checks do not prove TalkBack quality, every OEM font setting,
physical keyboard behavior, or every GPU's blur performance. Those remain in
the Android physical-device checklist.
