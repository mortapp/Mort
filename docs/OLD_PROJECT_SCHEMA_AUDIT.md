# Old Project Schema Audit

Project ref: `rakjydmgwwgtdislanbt`

Audit source:

```text
backups/supabase-rakjydmgwwgtdislanbt-20260708-094033/remote_audit_snapshot.txt
```

## Summary Before Rebuild

- Public tables: `37`
- Public functions: `4`
- Public RLS policies: `126`
- Public triggers: `11`
- Storage policies: `8`
- Storage buckets: `1`
- Remote migration history rows: `5`

## Existing Public Tables

`active_jobs`, `ad_impressions`, `ad_reward_events`, `ad_settings`, `admin_actions`, `admin_allowlist`, `analytics_events`, `blocked_users`, `conversations`, `disputes`, `guardian_links`, `job_applications`, `job_checkins`, `job_drafts`, `job_proofs`, `jobs`, `leaderboard_entries`, `messages`, `moderation_queue`, `notification_events`, `notifications`, `payment_disputes`, `payment_records`, `profiles`, `rate_limit_events`, `reports`, `reviews`, `rewarded_ad_events`, `safety_events`, `safety_pings`, `safety_reports`, `safety_scans`, `saved_jobs`, `tracked_earnings_events`, `trusted_circle_contacts`, `user_reward_balances`, `verification_requests`.

## Existing Storage

- `profile-avatars`: public bucket

The verified MORT backend requires private buckets `proof-uploads`, `verification-uploads`, and `report-uploads`. The old `profile-avatars` bucket is not part of the current verified MORT backend.

## Existing Remote Migrations

- `20260620134646` - `initial_schema`
- `20260626120000` - `mort_pay_core`
- `20260628120000` - `profile_username_avatar_bio`
- `20260629045115` - `mort_master_backend_completion`
- `20260629052340` - `mort_backend_tables_repair`

The verified local MORT migration is `202607070001_initial_mort.sql`; it is not in remote history.

## Conflicts With Verified MORT

- Several existing table names overlap with the verified migration but have incompatible columns and policies: `profiles`, `jobs`, `messages`, `reports`, `notifications`, `notification_events`, `safety_pings`, `conversations`, `guardian_links`, `job_applications`, and `blocked_users`.
- The old schema has ad/reward/payment tables that are outside the current preference-only MORT model.
- The old storage bucket is public, while the verified MORT upload model uses private buckets and signed URLs.
- Remote migration history contains old migrations not present locally, so a normal `supabase db push` would be unsafe without a rebuild/repair step.

## Rebuild Strategy

The old project will be rebuilt by:

- backing up the old schema/data/catalog first
- dropping old public schema objects through supported SQL only
- leaving Supabase internal schemas alone
- not deleting `auth.users`
- clearing incompatible remote migration history only for the local MORT migration version
- applying `supabase/migrations/202607070001_initial_mort.sql`
- applying `supabase/storage_setup.sql`
- deploying `send-push`
- running old-project QA seed, smoke, and RLS tests

Do not use this project with real users until iPhone, TestFlight, App Store/privacy, teen-safety, and legal checks are complete.

## Rebuild Result

The old project was rebuilt into the current MORT backend baseline after this audit. See `docs/OLD_PROJECT_REBUILD_REPORT.md`.
