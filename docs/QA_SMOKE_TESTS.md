# QA Smoke Tests

Use this as the local/staging checklist before live launch. Prefer a local Supabase stack or a fresh staging project.

## Actual Backend QA Execution - 2026-07-08

Executable checks passed against local Docker Supabase:

- `.\scripts\qa-smoke.ps1`: passed
- `.\scripts\qa-rls.ps1`: passed
- `node scripts/create-local-test-users.mjs`: passed
- `node --check scripts/qa-smoke.mjs`: passed
- `node --check scripts/qa-rls.mjs`: passed
- `node --check scripts/create-local-test-users.mjs`: passed

The smoke script verifies:

- local/staging target guard
- refusal guard for the current mismatched live Supabase ref
- anon client initialization
- required public tables
- `notification_events`
- required private buckets
- `supabase/functions/send-push/index.ts`
- no service-role references in Expo/mobile source

The RLS script verifies:

- teen cannot update another teen profile
- teen cannot access admin data
- adult cannot manage another adult's job
- guardian cannot access unrelated teen
- participants can read their own conversation
- outsiders cannot read unrelated conversation
- non-admin cannot approve verification
- non-admin cannot view report/admin queues
- user can read own notifications only
- private upload paths are not public
- owner can create a signed proof preview URL
- admin can read admin queue

## Old Project Rebuild QA - 2026-07-08

The old Supabase project `rakjydmgwwgtdislanbt` was intentionally rebuilt into the current MORT backend after backup and schema audit. See `docs/OLD_PROJECT_REBUILD_REPORT.md`.

Executable checks passed against the rebuilt remote old project:

- `node scripts/create-old-project-test-users.mjs`: created old-project rebuild QA auth users and sample data
- `pnpm run qa:old-project-smoke`: passed
- `pnpm run qa:old-project-rls`: passed

The old-project smoke script verifies:

- target guard requires `MORT_QA_TARGET=old-project-rebuild`
- exact project URL `https://rakjydmgwwgtdislanbt.supabase.co`
- `.env.local` contains only Expo public values
- no service-role references in Expo/mobile source
- all `23` MORT public tables are reachable through service-role QA checks
- all `23` public tables have RLS enabled by remote catalog check
- private Storage buckets exist and old `profile-avatars` bucket is absent
- remote migration history contains `202607070001 initial_mort`
- selected incompatible old public tables are absent
- `send-push` returns `401` without the internal header and `200` with the server-side invoke secret

The old-project RLS script verifies the same user-isolation and participant-boundary cases as local RLS using `.rebuild@mort.test` QA users.

## Monetization Backend QA - 2026-07-08

After the additive monetization migrations, old-project remote QA was updated and rerun:

- `pnpm run qa:old-project-smoke`: passed
- `pnpm run qa:old-project-rls`: passed

Additional RLS checks now include:

- own ad preference upsert
- another user's ad preferences hidden
- entitlement cache forgery blocked
- own paywall event logging
- own ad impression logging
- non-admin monetization overview denied
- admin monetization overview allowed

## Run Local Smoke

```powershell
cd "$env:USERPROFILE\Mort"
$env:MORT_QA_TARGET="local"
$env:MORT_QA_ALLOW_SERVICE_ROLE="LOCAL_OR_STAGING_ONLY"
$env:SUPABASE_SERVICE_ROLE_KEY (server-side only placeholder)"<local-service-role-key>"
.\scripts\qa-smoke.ps1 -LoadEnvLocal
.\scripts\qa-rls.ps1 -LoadEnvLocal
```

## Auth/Profile

- Sign up a test user.
- Confirm `profiles` row is created by trigger.
- Confirm onboarding is incomplete initially.
- Confirm onboarding requires display name, DOB, role, city, and state.
- Confirm under-13 DOB is blocked.
- Confirm teen 13-17 is allowed.
- Confirm adult 18+ is allowed.
- Confirm guardian 18+ is allowed.
- Confirm admin cannot self-select in app.

## Teen

- Teen can see open jobs.
- Teen can apply to a job.
- Teen cannot apply twice to the same job.
- Teen can see application status.
- Teen cannot access adult, guardian, or admin tabs directly.

## Adult

- Adult submits verification.
- Admin approves verification.
- Verified adult can create job.
- Adult can see own jobs.
- Adult can see applications to own jobs.
- Adult can accept or reject applications.
- Adult cannot manage another adult's jobs.

## Guardian

- Teen creates invite.
- Guardian accepts invite.
- Guardian sees linked teen approvals.
- Guardian approves/rejects linked teen application.
- Guardian cannot access unrelated teen data.
- Guardian pause blocks teen apply/message activity.

## Messaging

- Thread participants can read/send messages.
- Outsiders cannot read/send.
- Blocked users cannot message.
- Safety scanner blocks phone, email, social, payment, secrecy, and unsafe text.

## Reports/Blocking

- User can submit report.
- Report appears for admin.
- User can block another user.
- Blocking prevents messaging.

## Proof Upload

- Teen on an accepted application can upload proof.
- Adult/job owner can view proof through signed URL.
- Guardian/admin participants can review existing proof where RLS permits.
- Unrelated user cannot view private proof.
- Adult can mark accepted application complete or disputed.

## Verification

- Adult can submit verification with business name/type.
- Admin can approve/reject.
- `reviewed_by` is set to the admin user when reviewed.

## Notifications

- Push token can be registered on real iPhone/EAS build.
- `notifications` row can be created by DB triggers.
- `notification_events` row can be queued.
- `send-push` Edge Function can process pending events in local/staging.
- Notification can be marked read.

## Safety Ping

- Teen can send Safety Ping.
- Linked guardian gets notification/event.
- No linked guardian creates admin notification/event.

## Payment Preferences

- Cash, Cash App, Square link, flexible, and none save.
- Disclaimer is shown.
- No payment processing, escrow, card entry, or payout storage exists.

