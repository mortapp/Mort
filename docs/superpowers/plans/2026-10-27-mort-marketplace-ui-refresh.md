# MORT Marketplace UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a fresh Flutter marketplace Home that follows MORT’s approved mobile UI/UX design and feels polished, current, and easy to scan.

**Architecture:** Keep the existing Teen/Adult Flutter shells, routes, repositories, and job lifecycle. Refresh the reusable navigation treatment and the Teen Home’s Quick Jobs and compact job cards in place; keep all job actions wired to existing providers and repositories.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, existing MORT theme tokens and widget tests.

**Spec:** `C:/Users/micha/Downloads/2026-10-12-mort-mobile-ui-ux-design (1).md`

## Global Constraints

- Flutter is the only mobile implementation target for this work.
- Teen tabs remain Home, Explore, Inbox, Profile; adult/business tabs remain Home, Explore, +, Inbox, Profile.
- Home is a marketplace: Quick Jobs first, then compact feed; no greeting, dashboard, analytics, or persistent search.
- Light mode is primary; use white, black, silver, gray, and charcoal. Keep dark mode legible.
- Do not fabricate distance, ratings, trust, payment, or verification states.
- Preserve existing Apply, save, interest, dismissal/undo, privacy, and route behavior.

## Review Focus

- Large text on narrow phones: action rows and cards must remain usable.
- Missing or pending poster verification: never imply a verified identity.
- Unavailable distance or address-like `location_text`: show only privacy-safe neighborhood/city context.
- Dark mode: keep visual hierarchy clear without blue/purple brand color.
- Loading, empty, and error states: keep their current actions and truthful copy.

---

### Task 1: Refresh Teen marketplace presentation

**Files:**
- Modify: `flutter_mort/lib/features/teen/teen_marketplace_home_screen.dart`
- Test: `flutter_mort/test/teen_marketplace_home_test.dart`
- Preview: `flutter_mort/tool/ui_preview/teen_home.dart`

**Interfaces:**
- Consumes: existing `openJobsProvider`, saved/interested providers, jobs/applications repositories, and GoRouter routes.
- Produces: revised Quick Jobs and nearby-job cards with unchanged backend and route contracts.

- [x] Add a focused widget assertion for the refreshed card hierarchy and exact available privacy-safe metadata.
- [x] Run the focused test and confirm the new assertion fails before implementation.
- [x] Refresh the Quick Jobs and compact feed surfaces using existing monochrome theme tokens; retain Apply, save, interest, and swipe/undo behavior.
- [x] Render the synthetic-data Flutter preview at phone and desktop widths and inspect the result.
- [x] Run the Teen marketplace tests and targeted Flutter analysis; fix all regressions in this slice.

### Task 2: Align shared navigation with the new marketplace treatment

**Files:**
- Modify: `flutter_mort/lib/core/widgets/mort_liquid_glass.dart`
- Tests: `flutter_mort/test/teen_shell_navigation_test.dart`, `flutter_mort/test/teen_canonical_navigation_test.dart`

**Interfaces:**
- Consumes: existing Teen and Adult destination definitions and theme.
- Produces: consistent role-specific navigation presentation without changing tab order or routing.

The shared monochrome NavigationBar treatment is already present in base commit 5bcb7e9; this plan run re-verifies it rather than duplicating the shell change.

- [x] Add a focused assertion for the shared bar’s new visual treatment while preserving exact Teen/Adult destinations.
- [x] Run focused navigation tests; verify the existing monochrome navigation theme contract.
- [x] Verify the shared bar surface/indicator colors and role destinations; avoid duplicating the existing shell restyle.
- [x] Run focused shell/navigation tests and targeted Flutter analysis.

### Task 3: Remove the adult Home promo hero

**Files:**
- Modify: `flutter_mort/lib/features/jobs/job_screens.dart`
- Test: `flutter_mort/test/adult_marketplace_home_test.dart`

**Interfaces:**
- Consumes: existing `myJobsProvider`, role-specific AdultShell, and job routes.
- Produces: an adult Home that leads with posted work and keeps the existing job cards and empty/error states.

- [x] Assert the promo headline, brand masthead, and pre-feed slogan are absent.
- [x] Run focused Adult Home tests against the existing jobs-first implementation.
- [x] Verify the promo hero is already replaced by a compact posted-jobs heading and refresh control.
- [x] Run adult Home tests at normal and 200% text scale.

## Acceptance

- A first-time teen sees actual work immediately and can identify area, poster, job, pay, duration/schedule, and Apply.
- No consumer-facing Home reads as a dashboard or uses the rejected historical AAB UI.
- The preview is visibly the Flutter app and remains synthetic-data-only.
- Focused widget tests and analysis pass; remaining whole-suite failures are reported by test name.
