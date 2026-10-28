# MORT Flutter Marketplace Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Flutter teen Dashboard-first landing experience with the approved light-first jobs marketplace and canonical four-tab navigation.

**Architecture:** Preserve Flutter, Riverpod, GoRouter, existing job providers, and sensitive workflow routes. Change theme defaults and teen shell labels/routes, then reshape the teen landing screen to compose real feed data and compact job cards.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Material 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-27-mort-flutter-marketplace-refresh-design.md`

## Global Constraints

- Teen tabs are exactly Home · Explore · Inbox · Profile.
- Home is the marketplace; it is not a dashboard and has no persistent search field.
- Light mode is primary; dark mode remains complete.
- Brand palette is white, black, silver, gray, and charcoal. Semantic colors may be used sparingly.
- Only actual backend-fed jobs may appear; no fake sample jobs.
- No release-gate, payment, identity, or safety backend behavior may be weakened.
- Do not change React Native or website sources.

## Review Focus

- A missing/failed feed must show a safe retry or empty state rather than sample jobs; pin this in the Home widget test.
- Jobs with missing duration must not appear in Quick Jobs; pin this in a quick-job filter test.
- Large text/small screens must retain the four destinations without overflow; pin this in the navigation widget test.
- Safety must remain reachable after removing its tab; pin this in the Profile/route contract test.
- Existing dark-mode surfaces must stay legible; pin this with theme contract assertions.

---

### Task 1: Define canonical teen navigation

**Files:**
- Modify: `flutter_mort/lib/features/teen/teen_shell.dart`
- Modify: `flutter_mort/lib/core/routing/app_router.dart`
- Test: `flutter_mort/test/teen_marketplace_navigation_test.dart`

**Interfaces:**
- Consumes existing `StatefulNavigationShell` branches and route guards.
- Produces four indexed destinations mapping Home to `/teen/home`, Explore to `/teen/jobs`, Inbox to `/teen/messages`, and Profile to `/teen/profile`.

- [ ] Write a widget test asserting exactly Home, Explore, Inbox, Profile and no Dashboard/Safety/Jobs primary tab.
- [ ] Run the test and confirm it fails against the current five-tab shell.
- [ ] Update the route branch order and teen destinations while preserving existing safety routes.
- [ ] Run focused navigation tests and analyzer.

### Task 2: Make the visual system light-first and neutral

**Files:**
- Modify: `flutter_mort/lib/core/theme/mort_theme.dart`
- Modify: `flutter_mort/lib/main.dart`
- Test: `flutter_mort/test/mort_theme_contract_test.dart`

**Interfaces:**
- Preserve explicit light and dark theme constructors and existing semantic status colors.
- Default app startup to the light theme while retaining user preference/system behavior if already wired.

- [ ] Write theme assertions for light default, neutral surfaces/brand accents, and an explicit dark theme.
- [ ] Run the test and confirm it fails against the current dark-only default.
- [ ] Implement light theme tokens/components; keep dark theme independently legible.
- [ ] Run focused theme and visual identity tests.

### Task 3: Turn teen Home into the marketplace

**Files:**
- Modify: `flutter_mort/lib/features/mort_screens.dart`
- Modify: `flutter_mort/lib/features/jobs/teen_job_screens.dart` (only if a focused feed widget is needed)
- Test: `flutter_mort/test/teen_marketplace_home_test.dart`

**Interfaces:**
- Reuse `openJobsProvider`, `Job`, and existing application/detail routes.
- Home renders Quick Jobs from real feed results under 30 minutes, then a compact feed. Search remains in Explore.

- [ ] Write tests for jobs-first content, under-30-minute Quick Jobs, missing-duration exclusion, and no fake data.
- [ ] Run tests and confirm they fail against Dashboard-first Home.
- [ ] Implement the smallest reusable Home/feed composition and keep existing safety state reachable contextually.
- [ ] Run focused home/feed tests, then the complete Flutter test suite and analyzer.
