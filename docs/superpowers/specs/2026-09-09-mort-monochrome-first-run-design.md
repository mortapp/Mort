# MORT Monochrome First-Run Design

## Scope

Phase 3 converges the active production first-run experience: `/splash`, `/welcome`, `/auth/sign-in`, `/auth/sign-up`, `/auth/forgot-password`, auth confirmation/recovery/OAuth callback routes, `/account-status`, and the four-screen server-authoritative `/onboarding` flow. Legacy onboarding URLs remain redirects and their retired screen implementations are not revived. Connected-account settings stay in the later settings phase, although their auth contracts remain regression-protected here.

The approved master directive and the user's instruction to continue are the design authority for this phase. The implementation stays inside Flutter presentation widgets and tests.

## Visual direction

- Use the Phase 2 `MortSpaceBackground`, `MortLogo`, `MortScaffold`/`MortScreen`, typography, cards, fields, buttons, progress, and state components.
- Keep near-black space, graphite surfaces, silver borders and actions, generous negative space, and only small cool-blue focus or safety signals.
- Splash and welcome prioritize the double-chevron logo, short copy, and clear actions. They remain calm at small screen sizes and with reduced motion.
- Auth keeps native editable fields, visible errors, password rules, OAuth providers, legal disclosure, and the exact reviewer-mode behavior while removing any legacy primary-color treatment.
- Onboarding keeps four server-owned steps. The small silver progress indicator, neutral section hierarchy, and semantic status colors distinguish progress and safety without a colorful wizard aesthetic.

## Behavior and data boundaries

No route names, redirects, repositories, providers, payloads, validation, Supabase calls, OAuth/PKCE callbacks, legal versions, re-consent rules, guardian rules, avatar storage, native permissions, or startup routing may change. Google and Apple provider marks may retain their required brand colors. Semantic danger, warning, and success colors remain where meaning requires them.

Google Play reviewer mode remains disabled by default and available only behind its existing release/config guard. Tests must continue proving the exact synthetic identifier cannot activate reviewer mode in production/default configuration. No real account, hosted write, payment, identity, notification permission, emergency action, or upload is used for visual verification.

## Accessibility and layout

- Preserve native `EditableText`, `TextFormField`, dropdown, checkbox, and Appium semantics nodes; do not add containers that hide editable descendants.
- Preserve the DOB label/hint contract and all existing `qa-onboarding-*` identifiers.
- Keep minimum touch targets, logical focus order, keyboard scrolling, system-back behavior, safe areas, and bottom-action clearance.
- Verify iPhone SE-class width/height, Samsung-class dimensions, 200% text, and reduced motion without overflow or hidden primary actions.

## Test strategy

Add a focused first-run visual contract test and strengthen existing auth/onboarding tests. Assert canonical components and observable colors/layout, not screenshots or private implementation state. Use in-memory provider fakes only. Run existing auth startup, OAuth, reviewer-mode, DOB, onboarding routing/copy/persistence, legal, back-navigation, accessibility, and physical-rendering regressions before the full suite and Android build.

## Acceptance

Phase 3 is accepted when all active first-run routes use the monochrome foundation, active rose-gold primary references in their rendered code are zero, the first-run focused and protected-behavior regressions pass, an independent reviewer has no Critical or Important findings, `flutter analyze --no-pub` and the full Flutter suite pass, Android debug builds, the branch is pushed normally, and PR #8 remains open and untouched.
