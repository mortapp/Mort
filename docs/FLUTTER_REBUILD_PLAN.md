# MORT Flutter Rebuild Plan

Stage: MORT FLUTTER FULL REBUILD

## Decision

MORT is switching the mobile frontend from Expo React Native to Flutter while keeping the verified Supabase backend.

## Current Status

- Flutter app created at `flutter_mort/`.
- Existing Expo source remains in place as reference.
- Supabase project ref remains `rakjydmgwwgtdislanbt`.
- Supabase Auth, Postgres, RLS, Storage, Edge Functions, push queue, reports, jobs, applications, messaging, guardian approval, verification, proof uploads, notifications, admin moderation, and monetization tables are reused.
- No backend reset, table drop, destructive remote command, or new migration was required for this Flutter pass.
- No service role key is used in Flutter.

## Frontend Scope

- iPhone-first Flutter UI.
- Dark premium MORT design system.
- `go_router` route map for teen, adult, guardian, admin, messaging, safety, monetization, ads, settings, and legal flows.
- Riverpod providers and Supabase repositories wired to the existing backend tables/RPCs.
- RevenueCat and AdMob packages added with conservative guards.

## Explicit Non-Claims

- iPhone manual testing is not done.
- TestFlight is not done.
- App Store/legal/privacy/teen-safety review is not done.
- This is not production-ready.
