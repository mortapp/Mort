# MORT Flutter Marketplace Refresh

**Date:** 2026-10-27
**Product source:** `C:/Users/micha/Downloads/2026-10-12-mort-mobile-ui-ux-design (1).md`
**Platform constraint:** Flutter mobile app only. The accompanying roadmap's React Native and web implementation directions are out of scope.

## Intent

Replace MORT's legacy teen Dashboard-first surface with the approved jobs-first marketplace experience and establish the shared mobile navigation and visual foundation. A teen opening MORT should see nearby work immediately, understand distance, poster trust, category, pay, duration, and schedule, and reach Apply without first navigating a dashboard.

## Goals

- Use a calm white, black, silver, gray, and charcoal system; light mode is the default and dark mode remains supported.
- Give teens exactly four primary destinations: Home, Explore, Inbox, Profile. Remove Dashboard, Jobs, and Safety from the primary tab bar; preserve their safety and work routes through contextual navigation.
- Make Home show a compact Quick Jobs rail and real job feed before optional content. Do not add a persistent search bar or dashboard metrics to Home.
- Preserve privacy-safe location, verification, and payment language already enforced by the backend/client contracts.
- Keep implementation in `flutter_mort`; do not change the React Native app, Flutter web build, or public website.

## Non-goals for this slice

- Rebuild every workflow in the full design specification in one change.
- Enable production marketplace or payments, change release gates, or fabricate data/integrations.
- Change backend schemas, RLS, production data, or Supabase configuration.
- Use the legacy neon/gamified Dashboard as the visual template.

## Approaches

1. **Replace the entire Flutter app shell and all screens in one pass.** Rejected because it is difficult to review and risky across authentication, teen safety, payments, and role-specific flows.
2. **Build the design foundation and first marketplace loop in an additive, testable slice.** Selected: adjust theme, canonical teen tabs, and Home's jobs-first layout while preserving existing detail/application/safety routes. This makes the visible change concrete and keeps sensitive existing workflows intact.
3. **Create a separate demo-only UI.** Rejected because it would not update the actual app the user wants to distribute.

## Design decisions

- Keep MORT's existing Flutter/Riverpod/GoRouter architecture.
- Use a neutral light-first Material theme with a deliberate dark theme. Semantic danger/warning/success colors remain only for meaning.
- Rename the teen shell destinations to Home, Explore, Inbox, and Profile and route the first two to the existing Home and job feed modules.
- Reuse the live job-feed provider and job model; Home must not invent sample jobs. Quick Jobs are selected from real results whose duration is under 30 minutes.
- Keep Safety Center discoverable from Profile and active-job contexts, not as a fifth primary destination.
- No adult/business navigation shell is added in this slice; its tab mapping requires a separate route-tree change after the teen marketplace slice is verified.

## Acceptance

- Flutter widget/contract tests prove the four teen destinations and jobs-first Home content; no Dashboard primary destination remains.
- Light theme is the default; explicit dark theme remains available.
- Existing job, safety, inbox, and profile route contracts continue to work.
- Flutter analyzer and focused/full Flutter tests pass.
