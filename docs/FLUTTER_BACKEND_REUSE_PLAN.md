# Flutter Backend Reuse Plan

## Reused Backend

- Project ref: `rakjydmgwwgtdislanbt`.
- Project URL: `https://rakjydmgwwgtdislanbt.supabase.co`.
- Existing migrations remain the source of truth.
- Storage buckets remain private: `proof-uploads`, `verification-uploads`, `report-uploads`.
- `send-push` Edge Function remains server-side.

## Flutter Access Rules

- Flutter uses Supabase Auth and the public Supabase URL plus anon/publishable key only.
- Flutter never uses `SUPABASE_SERVICE_ROLE_KEY`.
- Flutter never uses `SUPABASE_ACCESS_TOKEN`.
- Flutter never uses `SUPABASE_DB_PASSWORD`.
- RLS remains authoritative.
- Admin access is based on backend profile role and policies, not fake local admin IDs.

## Repositories Added

- Auth repository.
- Profile/onboarding/payment/username repository.
- Jobs repository.
- Applications repository.
- Messaging repository using `send_safe_message`.
- Safety/report/block repository.
- Guardian repository using guardian invite and pause RPCs.
- Admin queue repository.
- Notifications repository.
- Uploads repository for private buckets.
- Monetization repository using entitlement/ad/paywall/username RPCs.

## Backend Changes In This Flutter Pass

None. No additive migration was needed, so remote smoke/RLS tests were not rerun in this pass.
