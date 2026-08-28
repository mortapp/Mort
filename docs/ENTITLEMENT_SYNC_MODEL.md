# Entitlement Sync Model

Updated: 2026-07-09

## Sources Of Truth

- Client UI access: RevenueCat `CustomerInfo` from the Flutter SDK.
- Server-controlled perks: Supabase tables updated by the RevenueCat webhook.
- Payments: App Store/RevenueCat only. MORT does not process payments, escrow, payouts, or job payments.

## Backend Tables

- `revenuecat_events`: immutable-ish normalized event log, idempotent on RevenueCat event id.
- `monetization_entitlements_cache`: app-facing entitlement cache.
- `user_subscription_status`: booleans for Plus, ad-free, Adult Pro, Guardian Plus.
- `username_change_credits`: server-side username credit ledger.
- `job_boost_credits`: server-side job boost credit ledger.
- `boosted_jobs`: boost requests created only after consuming a backend boost credit.
- `purchase_audit_logs`: server/admin audit trail.
- `paywall_events`: client paywall analytics.

## Rules

- The client can show premium UI from RevenueCat `CustomerInfo`.
- The server decides consumable credits from webhook/cache records.
- Users cannot write their own entitlement cache.
- Users cannot grant themselves username credits.
- Users cannot grant themselves job boost credits.
- Direct `boosted_jobs` insertion by users is blocked; users consume a credit through `consume_job_boost_credit`.
- Username tokens and job boosts should show a syncing state after purchase until webhook fulfillment lands.
- Safety features, basic applying, basic Guardian Mode, reports, blocking, Safety Ping, safe messaging, proof basics, and notifications stay free.

## Current QA

- Remote smoke passed after the additive job boost credit migration.
- Remote RLS passed for entitlement forgery, username credit forgery, job boost credit forgery, and direct boost insertion.
- Username credit happy path passed.
- Job boost credit happy path passed.
- Real iPhone/TestFlight purchase fulfillment has not been tested.
