# MORT Continuation Audit

## Current State Assessment

### What Already Exists
- **Backend Schema:** Supabase migrations indicate a robust backend setup (`202607070001_initial_mort.sql`, `20260708151850_add_monetization_tables.sql`, etc.) with RLS policies, tables for jobs, messaging, and monetization.
- **Flutter Scaffolding:** `flutter_mort` exists with dependencies (Riverpod, Supabase Flutter, Purchases Flutter, GoRouter, Google Mobile Ads) and a large `mort_screens.dart` file containing the UI.
- **Docs:** Extensive documentation exists in the `docs` folder.
- **QA Scripts:** Several test scripts are already in the `scripts` folder.

### What is Working
- **Remote Backend:** The Supabase remote project `rakjydmgwwgtdislanbt` is active and tests previously passed.
- **Edge Functions:** `send-push` and `revenuecat-webhook` (partially) exist.

### What is Fake/Partial
- **Flutter UI Backend Logic:** The UI in `mort_screens.dart` likely uses mock data or simple state management rather than connecting to the real Supabase backend for every action. 
- **RevenueCat Webhook:** Needs completion to properly synchronize purchase state with Supabase.
- **AI Safety:** Needs edge functions and rule-based fallbacks.
- **AdMob:** Configured via IDs, but needs `app-ads.txt` and proper rendering checks.

### What Still Needs Real Backend Wiring
- Auth & Onboarding
- Job posting, applying, and viewing
- Messaging
- Admin Queues & Moderation (Safety Pings, Reporting)
- Monetization checks via backend entitlement caches.

### What Still Needs RevenueCat Dashboard Setup
- Products, Entitlements, and Offerings need to be created/verified on the RevenueCat dashboard using the provided environment variables.

### What Still Needs AdMob Setup
- `app-ads.txt` generation in the root.
- Verification that AdMob IDs are used in the app code correctly.

### What Still Needs Flutter/iPhone Testing
- RevenueCat real purchase flows.
- AdMob ad display logic.
- TestFlight distribution.

### Immediate Next Steps
1. Automate RevenueCat API calls to set up the dashboard.
2. Complete `revenuecat-webhook` edge function and additive migration.
3. Wire the real backend into the Flutter UI screens.
