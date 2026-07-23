# Voluntary Paywalls Implementation Results

Date: 2026-07-08

Project ref: `rakjydmgwwgtdislanbt`

This pass continued from the existing MORT app/backend. It did not restart the app, rebuild from scratch, reset Supabase, remove working features, print secrets, or put service-role credentials in Expo/mobile source.

## Voluntary Paywalls Designed

- MORT Plus
- Ad-Free
- Username Change Token
- Profile Style Pack
- Adult Pro
- Job Boost
- Guardian Plus

Pricing is documented as suggested setup only. Runtime purchase prices must come from RevenueCat/App Store Connect.

## Monetization Code Integrated

- RevenueCat entitlement mapping now includes `mort_plus`, `mort_lifetime`, `mort_profile_style_pack`, `mort_username_change_token`, and `mort_job_boost`.
- Hook files added for RevenueCat, entitlements, ads, and feature access.
- Split component paths added under `components/monetization` and `components/ads`.
- Username, profile style pack, and job boost screens added.
- Paywall copy now uses optional/no-pressure language.

## Backend Additive Migrations

Fresh backup before remote schema work:

`backups\supabase-rakjydmgwwgtdislanbt-voluntary-paywalls-20260708-170323`

Applied migrations:

- `20260708163330_add_voluntary_paywall_perks.sql`
- `20260708210558_fix_username_change_rpc_ambiguity.sql`

Remote verified state after migration:

- 44 public tables
- 44 RLS-enabled public tables
- 42 public functions
- 35 public triggers
- migration history includes the initial rebuild, monetization tables, service-role grants, voluntary perks, and RPC ambiguity fix

## Username System

Implemented backend objects:

- `profiles.username`
- `username_change_events`
- `username_change_credits`
- `username_reservations`
- `username_moderation_flags`
- `get_username_change_status`
- `request_username_change`
- `consume_username_change_credit`
- `admin_grant_username_change_credit`

Rules implemented:

- 3 free lifetime changes
- Plus monthly allowance check through entitlement cache
- token/admin credits
- direct username profile updates blocked
- validation for length, unsafe terms, phone-like numbers, contact handles, payment handles, and impersonation terms
- user history privacy and admin review visibility

## Verification

- Remote smoke passed after table/function/trigger expectations were updated.
- Remote RLS passed after the ambiguous `username` reference bug was fixed.
- QA user password was generated in-process and not printed or stored.

## Still External

- RevenueCat products, offerings, and App Store Connect products still need dashboard setup unless already configured.
- RevenueCat webhook for consumable fulfillment is not deployed yet.
- Real AdMob live ads need consent/legal/EAS/iPhone testing.
- iPhone manual testing is not done.
- TestFlight is not done.
- App Store/legal/privacy/teen-safety review is not done.
