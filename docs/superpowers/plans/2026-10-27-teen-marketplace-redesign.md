# Teen Marketplace Redesign Implementation Plan

> **For agentic workers:** Follow the steps in order and verify each one before continuing.

**Goal:** Replace the dated teen Home presentation with a fresh Flutter marketplace surface grounded in the supplied MORT mobile UI/UX specification.

**Architecture:** Keep existing Riverpod data, GoRouter destinations, and job actions. Redesign only the teen Home presentation: editorial monochrome opening, quick picks, and compact non-duplicated work listings.

**Tech Stack:** Flutter, Material 3, Riverpod, GoRouter, widget tests.

**Spec:** `C:/Users/micha/Downloads/2026-10-12-mort-mobile-ui-ux-design (1).md`; Flutter is retained per the user's explicit platform instruction despite the roadmap's conflicting Expo paragraph.

## Constraints

- Home shows local work immediately and has no permanent search field.
- Search and detailed filters remain in Explore.
- Teen navigation remains Home, Explore, Inbox, Profile.
- Use white, black, silver, gray, and charcoal; semantic colors remain limited to meaning-bearing states.
- Keep pay, duration, schedule, poster trust, and privacy-safe location legible.
- Do not fabricate marketplace data or imply backend confirmation that did not occur.

## Review Focus

- Quick picks must not be repeated in the main feed.
- Long titles, missing poster names, and unavailable duration must remain readable.
- Apply/save actions must retain existing destinations and pending/error behavior.
- Empty, loading, and error states remain actionable.
- Dark theme and large text must remain usable.

### Task 1: Redesign the teen Home presentation

**Files:**
- Modify: `flutter_mort/lib/features/teen/teen_marketplace_home_screen.dart`
- Test: `flutter_mort/test/teen_marketplace_home_test.dart`

- [x] Add widget assertions for the new Home identity, quick-pick deduplication, large text, and dark-mode styling.
- [x] Run the focused tests and confirm the new identity, native navigation, and dark-mode styling fail before implementation.
- [x] Implement the new responsive, monochrome Home layout while preserving the existing data and navigation contracts.
- [x] Run focused Home and navigation widget tests, plus job safety widget tests, then analyze the changed Dart files.
- [x] Capture a Flutter-rendered preview for visual review.

### Task 2: Replace the adult dashboard Home with a jobs-first marketplace surface

**Files:**
- Modify: `flutter_mort/lib/features/jobs/job_screens.dart`
- Test: `flutter_mort/test/adult_marketplace_home_test.dart`

- [x] Add a widget assertion that rejects the old dashboard Home presentation.
- [x] Confirm the assertion fails against the existing Home.
- [x] Replace the adult Home mode with a jobs-first list, honest empty/error states, and the existing job detail and post-job routes.
- [x] Run adult Home, adult navigation, and accessibility-size checks; analyze the changed Dart file.
