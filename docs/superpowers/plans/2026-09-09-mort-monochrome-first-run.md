# MORT Monochrome First-Run Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge every active splash, welcome, auth, account-status, and onboarding route to MORT's approved monochrome visual system without changing behavior or hosted data.

**Architecture:** Refine the existing production screens in place and delegate their rendering to the Phase 2 canonical components. Preserve the single-writer worktree rule: the primary agent makes edits; a fresh read-only subagent reviews each independently testable slice before the next slice begins.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Material 3, widget tests.

**Spec:** `docs/superpowers/specs/2026-09-09-mort-monochrome-first-run-design.md`

## Global Constraints

- Do not change routes, auth/OAuth/PKCE, repositories, providers, server payloads, legal versions, guardian rules, avatar storage, permissions, or startup routing.
- Do not enable Google Play reviewer mode or weaken its production/default guard.
- Do not perform hosted writes, payments, identity checks, push prompts, emergency actions, or real uploads.
- Preserve native editable/select semantics, DOB label/hint behavior, and every `qa-onboarding-*` identifier.
- Keep PR #8 open and unmerged; do not touch its branch or worktree, `main`, PR #4, or preserved untracked `work/`.
- Use semantic status colors only where meaning requires them; active rose-gold primary usage in rendered Phase 3 surfaces must be zero.

---

### Task 1: Splash and welcome convergence

**Files:**
- Create: `flutter_mort/test/first_run_visual_convergence_test.dart`
- Modify: `flutter_mort/lib/features/mort_screens.dart:60-231,6949-7001`
- Test: `flutter_mort/test/mort_back_navigation_test.dart`

**Interfaces:**
- Consumes: `MortSpaceBackground`, `MortLogo`, `MortAnimatedBrandMark`, `MortScreen`, `MortButton`, `MortGlassCard`, and monochrome theme tokens.
- Produces: unchanged `SplashScreen` and `WelcomeScreen` public widgets and unchanged navigation destinations.

- [ ] **Step 1: Write failing visual contract tests**

  Pump `SplashScreen` and `WelcomeScreen` at 320×568 and 390×844 with reduced motion. Assert the real logo, space background, copy, CTA labels/styles, safe bottom actions, and zero layout exceptions. Inspect the active splash/welcome source slice and require no `roseGold`, `godPink`, or `neon` token references.

- [ ] **Step 2: Verify RED**

  Run `flutter test --no-pub test/first_run_visual_convergence_test.dart`. Expect failure on the welcome feature's active `MortColors.roseGold` reference or its observable icon color.

- [ ] **Step 3: Implement the minimal presentation changes**

  Keep every string and route. Use the canonical logo contract and map ordinary feature icons to silver while reserving the cool-blue signal for the safety feature. Retain pinned safe-area actions and the backend status state.

- [ ] **Step 4: Verify and review**

  Run the focused test plus `flutter test --no-pub test/mort_back_navigation_test.dart test/physical_rendering_regression_test.dart`. Dispatch a fresh read-only reviewer; repair Critical/Important findings with a failing test first.

### Task 2: Auth, provider callbacks, and reset convergence

**Files:**
- Modify: `flutter_mort/lib/features/auth/unified_auth_screen.dart`
- Modify: `flutter_mort/lib/features/mort_screens.dart:623-702`
- Modify only if an observable auth/callback presentation requires it: `flutter_mort/lib/features/auth/google_auth_screens.dart:18-552`, `flutter_mort/lib/features/auth/apple_auth_screens.dart:15-139`
- Test: `flutter_mort/test/first_run_visual_convergence_test.dart`
- Test: `flutter_mort/test/unified_auth_screen_test.dart`

**Interfaces:**
- Consumes: canonical logo/header/form/button/state widgets and existing auth/provider repositories unchanged.
- Produces: unchanged `UnifiedAuthScreen`, `ForgotPasswordScreen`, OAuth callback, email-confirmation, and password-recovery behavior with monochrome rendering.

- [ ] **Step 1: Write failing accessibility/layout tests**

  Assert canonical logo/header use, two native editable fields in ordinary auth, visible OAuth/legal/password/error states, accessible Google/Apple labels, callback loading/error/success states, 200% text and keyboard-safe scrolling, and exact default reviewer-mode isolation.

- [ ] **Step 2: Verify RED**

  Run `flutter test --no-pub test/first_run_visual_convergence_test.dart test/unified_auth_screen_test.dart`. Expect failure where old compatibility branding or active legacy status color remains.

- [ ] **Step 3: Implement presentation-only convergence**

  Replace compatibility brand calls with `MortLogo` where static and retain reduced-motion-safe animated branding where motion is intended. Replace non-semantic legacy color aliases in the active auth/callback slice with silver/accent tokens. Preserve field validators, password visibility, provider-brand button treatments, OAuth widgets, callback schemes, legal links/version, reviewer identifier logic, submissions, routes, and provider calls byte-for-byte where possible.

- [ ] **Step 4: Verify and review**

  Run focused tests plus `auth_startup_test.dart`, `oauth_flow_test.dart`, `google_auth_contract_test.dart`, `apple_auth_contract_test.dart`, `play_reviewer_mode_test.dart`, `account_status_onboarding_route_test.dart`, and auth/back-navigation cases. Dispatch a fresh read-only reviewer and repair all Critical/Important findings RED-first.

### Task 3: Account-status and onboarding-entry convergence

**Files:**
- Modify: `flutter_mort/lib/features/mort_screens.dart:317-622`
- Test: `flutter_mort/test/first_run_visual_convergence_test.dart`
- Test: `flutter_mort/test/account_status_onboarding_route_test.dart`

**Interfaces:**
- Consumes: canonical status/state/card/button widgets and existing profile/release providers unchanged.
- Produces: unchanged `AccountStatusScreen` and `OnboardingRequiredScreen` route decisions with monochrome rendering.

- [ ] **Step 1: Write failing status-state tests**

  Assert incomplete accounts still render the onboarding-required route, restricted accounts retain support/appeal affordances, and active accounts preserve honest release/payment/identity availability states. Require the active account-status source slice to contain no `roseGold`, `godPink`, or `neon` primary token.

- [ ] **Step 2: Verify RED**

  Run `flutter test --no-pub test/first_run_visual_convergence_test.dart test/account_status_onboarding_route_test.dart`. Expect failure on the marketplace-status lock's `MortColors.neon` use.

- [ ] **Step 3: Implement presentation-only convergence**

  Replace the legacy status accent with the restrained cool-blue/silver signal and use canonical state/card components where doing so does not change async branches. Do not change role routing, account restriction, release flags, or the hosted ban-appeal submission.

- [ ] **Step 4: Verify and review**

  Run focused tests plus `auth_startup_test.dart`, `route_access_test.dart`, and account-status back-navigation cases. Dispatch a fresh read-only reviewer and repair all Critical/Important findings RED-first.

### Task 4: Four-step onboarding convergence

**Files:**
- Modify: `flutter_mort/lib/features/onboarding/compact_onboarding.dart`
- Test: `flutter_mort/test/first_run_visual_convergence_test.dart`
- Test: `flutter_mort/test/compact_onboarding_test.dart`

**Interfaces:**
- Consumes: `MortDateField`, `MortSelect`, `MortStepper`, neutral cards/tokens, existing repository/provider interfaces, and existing Appium semantics identifiers.
- Produces: unchanged four-step `CompactOnboardingScreen` server workflow with monochrome presentation.

- [ ] **Step 1: Write failing route-state tests**

  Using in-memory profile/legal fakes, assert step 1 renders the native DOB field and stable adult-choice IDs, progress is silver/graphite, each active step remains reachable, review placeholders and section labels contain no rose-gold primary treatment, bottom actions stay visible at iPhone SE size and 200% text, and reduced motion uses zero-duration switching.

- [ ] **Step 2: Verify RED**

  Run `flutter test --no-pub test/first_run_visual_convergence_test.dart test/compact_onboarding_test.dart`. Expect failure on the review avatar and onboarding section label legacy colors.

- [ ] **Step 3: Implement presentation-only convergence**

  Delegate DOB and select fields to canonical wrappers without changing their native nodes. Replace the placeholder avatar and section-label rose-gold aliases with graphite/silver/accent. Keep semantic danger/warning/success notices, all copy, four-step server projection, save payloads, idempotency keys, location privacy, guardian optionality, permission truth, legal acknowledgements, avatar editor, and back behavior unchanged.

- [ ] **Step 4: Verify and review**

  Run focused tests plus `date_of_birth_field_test.dart`, `onboarding_route_contract_test.dart`, `onboarding_production_copy_test.dart`, `onboarding_persistence_test.dart`, `legal_clickwrap_stability_test.dart`, `pending_legal_reacceptance_test.dart`, and onboarding back-navigation cases. Dispatch a fresh read-only reviewer and repair all Critical/Important findings RED-first.

### Task 5: Phase gate and atomic delivery

**Files:**
- Modify: `.superpowers/sdd/2026-09-08-mort-monochrome-flutter-convergence/progress.md`
- Modify only if review findings require it: Phase 3 files above

**Interfaces:**
- Consumes: accepted Tasks 1–4 and their evidence.
- Produces: one reviewed Phase 3 commit and a verified normal push on `design/mort-monochrome-flutter-convergence`.

- [ ] **Step 1: Run final local gates**

  Run `dart format lib test integration_test`, the no-change format check, `flutter analyze --no-pub`, `flutter test --no-pub`, and `flutter build apk --debug`. Capture exact counts and artifact path.

- [ ] **Step 2: Audit isolation and visual debt**

  Run `git diff --check`, inspect every changed path, count remaining legacy-color matches, confirm no backend/migration/repository/provider/router/QA/release files changed, and verify PR #8 is still open and unmerged.

- [ ] **Step 3: Final independent review**

  Dispatch a fresh read-only reviewer with this spec, plan, base SHA `195de78eecbabaf101a721a8c99563efc0abf623`, and the complete diff. Repair every Critical/Important finding using RED-first tests, then rerun focused and full verification.

- [ ] **Step 4: Record and deliver**

  Update the durable ledger with exact evidence. Commit coherently as `feat(ui): converge MORT first-run experience`, push normally to `origin design/mort-monochrome-flutter-convergence`, verify local/remote SHA equality, and do not merge or modify PR #8.
