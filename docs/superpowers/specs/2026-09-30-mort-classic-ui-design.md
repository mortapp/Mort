# MORT classic UI and school eligibility design

## Intent and release boundary

The 2026-09-30 owner directive replaces the dark atmospheric presentation with a mature white, black, and neutral marketplace interface throughout the authoritative Flutter client. It also makes verified school-issued email mandatory for teen eligibility. Preserve every existing route, provider authority, safety control, and role capability. This work runs on `feature/mort-classic-ui-redesign` from completion head `9d6480c8a8f01d73a1b600082c7921964acc562b`; build 114, release PRs, hosted production, and live providers remain untouched.

## Existing system

The baseline has 217 literal GoRouter destinations, 11 onboarding redirects, and 24 public screen/view classes not directly named in the router; see `docs/ui/MORT_CLASSIC_UI_SCREEN_INVENTORY.md`. A five-branch `StatefulShellRoute` serves teens, with dark glass navigation. Adults and guardians currently use separate guarded routes. The palette and theme are centralized, but many widgets also reference dark color aliases directly. Auth signs up before onboarding collects date of birth. School-domain and MORT Verify tables/RPCs exist, but affiliation verification is a distinct later flow and does not enforce school email before teen marketplace access.

## Visual architecture

Evolve the existing `MortColors`, `MortTheme`, spacing/tokens, and shared `Mort*` widgets as the sole design system. Canonical surfaces are white or light neutral; primary text is near black, secondary text gray, hairlines subtle. A black primary button, neutral secondary button, clean input, structural card, restrained semantic status, and simple modal/selector are shared patterns. Remove decorative atmosphere from the production scaffold while preserving safe areas, keyboard behavior, back semantics, and reduced motion. Keep the debug atmosphere preview isolated to debug mode.

Use one reusable bottom bar for teen, adult, and guardian shells. It has familiar icons, labels, a small active pill and soft elevation, minimum touch targets, and no blur/glow. Teen and adult tabs are Home, Jobs, Messages, Safety, Profile; guardian tabs are Home, Safety, Messages, Profile. Admin/reviewer screens retain role-specific navigation but adopt the same components. Deep links retain their existing paths, guards, and sensitive wrappers.

The Profile tab shows the user's actual profile with an accessible gear at top right leading directly to Settings. Settings uses grouped rows; Pro, Companion, progression, account, safety, privacy, support, and legal remain separately reachable. Every screen's primary action, empty/loading/error state, responsive layout, and screen-reader semantics are checked against the inventory. RevenueCat prices remain store-localized, Continue with Free remains clear, and Stripe marketplace remains fail-closed.

## Teen school-email architecture

Before a new registration reaches teen onboarding, collect date of birth and determine the provisional age band. For 13–17, show a searchable, server-backed school directory, confirm a selected school, require a school-issued email whose exact domain is verified and assigned to that school, then prove inbox ownership. A school can be listed while its student domain remains unverified; that state blocks registration. Unknown schools can be requested for staff review without creating an active teen marketplace identity. No personal-email, school-ID, guardian, or Google OAuth fallback satisfies teen school-email eligibility.

The backend is authoritative. Reconcile the existing `school_domains` and MORT Verify structures with additive directory, alias, assignment, request, verification, and audit data; avoid duplicate domain truth. Only authorized staff can approve/suspend/retire exact student domains. Public directory search returns limited school information, with no student email, reviewer, or evidence data. Use bounded search, indexed normalized terms, pagination, and no exact GPS. Verification challenges are one-time, short-lived, attempt-limited, resend-throttled, and never logged with raw email. Existing Supabase Auth confirmation may provide inbox ownership if safely bound to the same normalized address and server eligibility record; otherwise use an isolated server challenge.

An Auth user may exist before eligibility is complete because Supabase Auth creates the identity during email confirmation. Such a user has no active teen marketplace access. New and existing teen profiles must pass a server-side current verified-school-email check before restricted marketplace actions. Safety, support, legal, account controls, and school replacement remain available while restricted. OAuth authentication never grants school authorization. For school changes, preserve the old verified affiliation until a replacement verifies; at adult transition, require adult eligibility checks before allowing personal email. Suspending a domain blocks new verifications immediately and invokes a documented existing-user review policy rather than deleting users.

## Delivery slices

1. Inventory and source-backed design tokens, shared components, and shells.
2. Age-first auth, school directory/review, verification, eligibility enforcement, and existing-teen migration behavior.
3. Teen jobs/lifecycle, adult jobs, messages, profile/settings, Safety/Guardian, Verify, progression, Pro, Companion, support/admin/legal, then state/accessibility polish.
4. Full Flutter/Edge/local DB tests, Android and iOS parity, secret scans, CI, and exact inventory reconciliation.

Each slice must retain a working app and its existing guards. The school migration is code reviewable but must not be deployed to the hosted build-114 backend during this pass. Physical device and provider claims require actual evidence. The final report distinguishes code completion from Docker, device, hosted, legal, and provider gates.
