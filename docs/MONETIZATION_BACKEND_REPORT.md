# Monetization Backend Report

Date: `2026-07-08`

Project ref: `rakjydmgwwgtdislanbt`

This was an additive-only backend change. No tables were dropped, no storage buckets were deleted, and the database was not reset.

## Backup

Before applying monetization migrations, a remote schema/migration backup was created:

```text
backups/supabase-rakjydmgwwgtdislanbt-monetization-20260708-112117/
```

The preflight snapshot showed:

- `23` public tables
- `23` RLS-enabled public tables
- `28` public functions
- `25` public triggers
- private `proof-uploads`, `report-uploads`, `verification-uploads`
- migration history: `202607070001 initial_mort`

Raw backup files are local only and must not be committed or placed in release zips.

## Migrations Applied

Applied remotely:

- `20260708151850_add_monetization_tables.sql`
- `20260708152332_add_monetization_service_role_grants.sql`

## Tables Added

- `monetization_entitlements_cache`
- `revenuecat_events`
- `user_subscription_status`
- `ad_impressions`
- `ad_click_events`
- `ad_frequency_caps`
- `user_ad_preferences`
- `purchase_audit_logs`
- `premium_feature_usage`
- `boosted_jobs`
- `boost_impressions`
- `monetization_experiments`
- `paywall_events`

All new tables have RLS enabled.

## RPCs Added

- `get_my_entitlements`
- `record_paywall_event`
- `record_ad_impression`
- `get_ad_eligibility`
- `get_boosted_jobs`
- `admin_monetization_overview`

## Verification

Remote post-migration state:

- `36` public tables
- `36` RLS-enabled public tables
- `34` public functions
- `31` non-internal public triggers
- migration history includes `initial_mort`, `add_monetization_tables`, and `add_monetization_service_role_grants`

Updated QA:

- `pnpm run qa:old-project-smoke`: passed
- `pnpm run qa:old-project-rls`: passed

RLS verified:

- users can manage their own ad preferences
- users cannot read another user's ad preferences
- users cannot forge entitlement cache rows
- users can record their own paywall/ad events
- non-admin users cannot call admin monetization overview
- admins can call monetization overview

## Important

RevenueCat is still the source of truth for purchases. Supabase monetization tables are cache/audit/analytics support only.

## Voluntary Paywalls Continuation

Additional additive migrations applied:

- `20260708163330_add_voluntary_paywall_perks.sql`
- `20260708210558_fix_username_change_rpc_ambiguity.sql`

New backend support includes username change credits/events/reservations/moderation flags, profile style unlock/settings, saved job folders, and feature usage RPC support. Remote smoke and RLS passed after the RPC ambiguity fix.

No payment cards, job payments, escrow, or payout processing were added.
