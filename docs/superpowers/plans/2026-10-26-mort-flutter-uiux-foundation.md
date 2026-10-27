# MORT Flutter UI/UX Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Flutter app’s visual foundation and consumer navigation in line with the supplied MORT mobile UI/UX specification while preserving production auth, safety, payment, and routing behavior.

**Architecture:** Keep Flutter, Material 3, GoRouter, and existing feature repositories. Add light and dark MORT themes from shared monochrome tokens, then use role-specific shell navigation: four teen destinations and five adult/business destinations with a central post-job action. Keep guardian and moderator workspaces outside the consumer shell. Preserve existing deep links as redirects or guarded standalone routes.

**Tech Stack:** Flutter/Dart, Material 3, Riverpod, GoRouter, Flutter widget tests.

**Spec:** `C:/Users/micha/Downloads/2026-10-12-mort-mobile-ui-ux-design (1).md` (the companion roadmap is `C:/Users/micha/Downloads/2026-10-12-mort-uiux-program-roadmap.md`; its Expo stack instruction is superseded by the user’s Flutter-only direction).

## Global Constraints

- Teen tabs are `Home · Explore · Inbox · Profile`; no teen `+` or Motion tab.
- Adult/business tabs are `Home · Explore · + · Inbox · Profile`; `+` opens Post a job.
- Home is the marketplace; do not add a consumer Dashboard.
- Palette is white, black, silver, gray, and charcoal; reserve semantic colors for meaning.
- Light mode is primary and dark mode is fully designed; support the device theme in this foundation.
- Keep safety, payments, exact-address privacy, role guards, and backend truth unchanged.
- Keep guardian and internal moderator routes outside the consumer navigation shell.
- Do not add Expo/React Native, web-client, or website implementation work.

## Review Focus

- A teen must not see the adult post-job action; verified by shell widget tests.
- A role switch or direct deep link must not bypass `GuardedRoute`; verified by router tests.
- Keyboard display must not cover navigation or primary actions; verified at the shell level.
- Larger text and high-contrast settings must retain readable monochrome contrast; verified with light/dark theme and existing accessibility tests.
- Back navigation must preserve the current branch state and return to the previous tab; verified by navigation tests.

---

### Task 1: Monochrome light/dark theme foundation

**Files:**
- Modify: `flutter_mort/lib/core/theme/mort_colors.dart`
- Modify: `flutter_mort/lib/core/theme/mort_theme.dart`
- Modify: `flutter_mort/lib/core/theme/mort_typography.dart`
- Modify: `flutter_mort/lib/app.dart`
- Test: `flutter_mort/test/mort_theme_mode_test.dart`

**Interfaces:**
- `MortTheme.light()` returns the light Material 3 theme.
- `MortTheme.dark()` remains the dark Material 3 theme for existing callers.
- `MortApp` supplies both themes and resolves the system brightness.

- [x] **Step 1: Write failing theme tests** for light and dark brightness, neutral primary/surface colors, and legible text colors.
- [x] **Step 2: Run** `flutter test --no-pub test/mort_theme_mode_test.dart` and confirm the tests fail because the light theme does not exist.
- [x] **Step 3: Implement** additive light/dark palette tokens and `MortTheme.light()`; keep compatibility aliases so feature screens retain their existing semantics.
- [x] **Step 4: Wire** `theme`, `darkTheme`, and `ThemeMode.system` into `MortApp`.
- [x] **Step 5: Re-run** the focused test, then existing component and accessibility tests.

### Task 2: Teen consumer shell and canonical four-tab navigation

**Files:**
- Modify: `flutter_mort/lib/features/teen/teen_shell.dart`
- Modify: `flutter_mort/lib/core/routing/app_router.dart`
- Modify: `flutter_mort/test/teen_shell_navigation_test.dart`
- Test: `flutter_mort/test/teen_canonical_navigation_test.dart`

**Interfaces:**
- Teen primary branches are `/teen/home`, `/teen/jobs` (Explore), `/teen/messages` (Inbox), and `/teen/profile`.
- Safety, Applications, and saved-job routes remain available as guarded secondary destinations.
- `TeenShell` preserves branch history, keyboard behavior, and system/visible Back parity.

- [x] **Step 1: Write failing tests** asserting exactly four labels, no Dashboard/Safety tab, Explore/Inbox routes, no plus action, and preserved Back behavior.
- [x] **Step 2: Run** `flutter test --no-pub test/teen_canonical_navigation_test.dart` and confirm it fails against the current five-tab shell.
- [x] **Step 3: Update** teen destinations and the stateful shell branches without weakening any route guard; keep `/teen/safety` and its sensitive job workspace outside the tab shell.
- [x] **Step 4: Re-run** the new tests and existing `teen_shell_navigation_test.dart`.

### Task 3: Adult/business consumer shell

**Files:**
- Create: `flutter_mort/lib/features/adult/adult_shell.dart`
- Modify: `flutter_mort/lib/core/routing/app_router.dart`
- Test: `flutter_mort/test/adult_shell_navigation_test.dart`

**Interfaces:**
- Adult/business shell provides `Home`, `Explore`, central `+`, `Inbox`, and `Profile` destinations.
- The center action navigates to the existing guarded `/adult/post-job` route.
- Existing adult job-management, applicant, inbox, profile, and posting routes remain guarded and reachable.

- [x] **Step 1: Write failing tests** for five destinations, central post-job navigation, Back behavior, and absence of the adult shell for guardian/moderator roles.
- [x] **Step 2: Run** `flutter test --no-pub test/adult_shell_navigation_test.dart` and confirm the new shell is missing.
- [x] **Step 3: Implement** `AdultShell` and wrap adult primary destinations in an indexed stateful shell; retain the existing global `/messages` route for legacy/deep-link compatibility.
- [x] **Step 4: Re-run** focused shell tests and router role-guard tests.

### Task 4: Foundation verification and reviewable Flutter preview

**Files:**
- Modify only the files above and required focused tests.

- [x] **Step 1: Run** focused theme/navigation/accessibility tests.
- [x] **Step 2: Run** changed-file `dart analyze` and the full `flutter test --no-pub` suite. (A whole-package `flutter analyze` is still pending.)
- [x] **Step 3: Build** a local Android debug preview using only synthetic fixture data; do not access Supabase, commit keys, or change production service flags.
- [ ] **Step 4: Capture** light and dark screenshots from the Android QA emulator and inspect teen/adult shells. (Teen and adult light captures were inspected; dark capture remains unverified.)
- [x] **Step 5: Review** the diff for unrelated files, backend/auth changes, role-guard regressions, and any non-neutral brand colors.

## Execution ledger

- The user’s explicit Flutter-only direction supersedes the companion roadmap’s Expo/React Native implementation notes.
- Adult Explore searches the adult’s own posted jobs because the existing public teen-job feed is role-restricted; this avoids adding a path that exposes teen profiles or teen-only marketplace data to adults.
- The UI preview uses one synthetic local job and does not connect to or write to either Supabase project.
- Screenshots exposed pale light-mode category/status text. Added a failing widget test, then changed the light-mode selected chip and job-status label colors to pass contrast expectations while preserving the existing dark palette.
- Latest verification after that shared-widget change: full `flutter test --no-pub` completed with 937 passed, 23 skipped, and 0 failed; changed-file `dart analyze` reported no issues; `git diff --check` passed.
- The Android emulator stopped reporting an ADB device during the final contrast-refresh attempt. Teen and adult light-mode screenshots captured before the small contrast-only correction are available under ignored `flutter_mort/build/ui-preview/`; no dark-mode screenshot has been verified.
- This is a UI foundation and consumer-shell phase, not the entire multi-phase UI program or a production release sign-off.
