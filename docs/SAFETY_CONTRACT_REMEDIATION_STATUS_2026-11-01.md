# MORT Safety-Contract Remediation Status — 2026-11-01

## Production rollout update — 2026-11-01

This update supersedes the earlier “not applied” sections below. The owner
explicitly requested production SQL changes. Both migrations were applied to
`jxbnrkasktbhtiujkhay` and appear in Supabase migration history as:

- `20261102003713_atomic_application_and_guardian_resend_contract`
- `20261102003741_private_location_and_block_message_contract`

Post-apply catalog checks confirmed the new RPCs and private tables exist,
`anon` has no execute rights on the new RPCs, and RLS is enabled and forced on
the private location/history tables. Authenticated direct job INSERT/UPDATE,
including exact-address column writes, is revoked. The live website's job
posting action uses the existing server-side `save_job_draft_or_publish` RPC.
Production flags still report marketplace closed, publishing disabled,
payments disabled, and real document collection disabled.

No user rows were changed. Production had and still has zero job applications,
zero safety agreements, and zero jobs with a non-null exact address. The
schema-only Docker clone validation already recorded below passed application
pgTAP (11/11), private-location catalog pgTAP (20/20), location authorization
pgTAP (9/9), and independent two-session application and block/message race
tests. This is not a full database/Auth/Storage restore proof or a hosted
callback test. Job-distance RPC and Guardian application decisions were not
included in these migrations and remain unavailable.

Supabase recorded the migrations at the versions above; the repository files
are renamed to match. The rest of the repository migration history still
diverges from production. Do not use `supabase db push` against the whole local
241-file chain until that historical mismatch is reconciled.

## Step 1 local follow-up — 2026-11-01

The supplied notification and distance SQL was reviewed against the running
schema-only Docker clone. The initial distance draft put approximate
coordinates on `public.jobs` and returned a fine-grained distance; that draft
was not applied. Revised local migrations now keep rounded centers in a
private table and return only broad distance bands after teen, job, age
verification, Guardian, block, release-control, and rate-limit checks.
`supabase/tests/step1_location_distance_integration.sql` passed against the
Docker clone with synthetic fixtures rolled back. These two new migrations
remain unapplied to production. The Flutter distance UI remains unavailable
until an opt-in location flow is integrated. The notification inbox query was
corrected to use production's `notifications.user_id` column.

## Historical scope before production rollout

The corrected append-only migrations and this report were present on the `codex/flutter-backend-integration` branch at the time of that report. The reference website job-write cutover was committed in `763fc1efdf8c323670c8e88b94448b268e26836d`. This paragraph describes the pre-rollout state only; the production changes are documented at the top of this file.

The requested isolated Supabase branch was not created because its recurring cost was **$0.01344/hour** and approval was declined.

## Implemented in repository drafts

### Application eligibility race

`20261101120000_atomic_application_and_guardian_resend_contract.sql` now:

- locks the job row before eligibility is evaluated;
- reports an existing active application deterministically; and
- performs the insert only after the locked eligibility check.

This is designed to make concurrent submissions serialize. It still requires a real two-session database test before deployment.

### Guardian resend mismatch

The same migration adds `resend_guardian_invite(uuid)`:

- requires an authenticated active teen;
- scopes the operation to the selected pending link;
- consumes only that link's previous invite code;
- creates a replacement code for the same link; and
- leaves other pending links untouched.

The resend path now also takes a deterministic per-teen advisory transaction lock
before the 24-hour rate count, locks the selected pending link before rotating it,
and returns `guardian_invite_code_missing` instead of creating a replacement when
the selected link has no active prior code. The focused Guardian resend regression
passes alongside the application-race and private-location migration tests.

### Private job-address release

`20261101123000_private_location_and_block_message_contract.sql` adds a hosted-schema-specific private location table and RPCs:

- `save_job_private_location(...)` stores exact address/coordinates outside the public job row;
- `get_released_job_location(uuid)` explicitly denies when the assignment or agreement row is absent, rather than allowing SQL `NULL` to bypass the denial;
- exact data is returned only to the poster or an active assigned teen after both safety-agreement confirmations match the current agreement version;
- unrelated users and blocked pairs receive only a denial/coarse location response; and
- private reads/writes are recorded in a restricted access-events table.

Saving a changed location now increments `location_version`, updates the agreement binding, and calls the live `private.refresh_job_safety_agreement(application_id)` helper. That helper bumps the agreement version, refreshes terms, and sets the valid `reconfirmation_required` status. The read RPC requires equality between the confirmed agreement version and the stored location version.

The migration also revokes authenticated direct `INSERT` and `UPDATE` privileges on `public.jobs`; exact addresses therefore cannot be written through the client-facing table path and must use the server-side RPC.

### Block/message concurrency

The same migration adds pair-locked `block_user_v2` and `unblock_user_v2` RPCs, and replaces `mort_send_message` with a matching deterministic user-pair advisory lock. Participant locks are acquired in sorted order, the conversation row is locked before status/message checks, and a send and a block for the same pair cannot pass their checks in opposite order.

## Validation completed

- Migration file encoding check passed.
- TypeScript check passed.
- Focused structural assertions passed for the job lock, duplicate guard, link-scoped resend, private location gates, pair locks, and restricted grants.
- New `qa:safety-contracts:static` automated test passed for NULL-safe authorization, location-version binding, valid reconfirmation handling, direct job-write revocation, and deterministic locking.
- The deployable migration is now covered directly, not only through proposal fixtures: `qa:safety-contracts:unit` passes **5/5** tests for application locking, Guardian resend serialization, and private-location cross-job binding. CI runs this suite plus the static contract checks.
- Hosted project inspection was read-only.
- Follow-up review found the live job ACL uses column-level INSERT/UPDATE grants, so a table-level REVOKE alone was insufficient; the migration now removes residual column grants and does not add broad table SELECT. `node scripts/qa-safety-contracts-acl.mjs` and the static regression pass; this checks the ACL block only.
- The schema-preflight expected column was corrected to hosted `guardian_links.teen_user_id` after read-only catalog comparison. Its staging runner now requires an explicit project-ref/host match, refuses production and the deleted project, enforces TLS, and keeps the database password out of psql arguments. Static checks and a wrong-host refusal check pass; no isolated-database preflight has run.
- A fresh rerun at remote tip `32c8d58cc8373c6ef1e5cc78cc9791f95cdfd390` completed the frozen dependency install and `tsc --noEmit` with no errors. The 5-test unit suite, static safety checks, website job-write contract, and migration encoding checks also passed. The disposable PostgreSQL ACL harness could not start in this sandbox because `docker`, `podman`, and `psql` are unavailable; no ACL result was invented or substituted.

## Validation not possible yet

- Docker is available on the current workstation and local Supabase containers are running, but their migration heads are `20261025080236`, `20261015005047`, and `20260824034646`, behind hosted production's `20261101002805`. They are not production-equivalent, so the full migrations were not replayed against them.
- The billable isolated Supabase branch was not created.
- The repository's historical migration-parity check still fails on a pre-existing hash mismatch in `20260918032930_guardian_teen_summary_v1.sql`; that historical file was not rewritten.
- The new SQL has not been applied or syntax-replayed as a complete migration against a database.
- Independent two-session tests for application submission and block/send ordering remain outstanding.
- The production ACL correction removes authenticated direct job INSERT/UPDATE column grants. The reference website now uses `save_job_draft_or_publish(uuid,uuid,jsonb,boolean)` for posting and `admin_moderate_job` for removal; `qa:reference-website-job-write-contract` confirms no direct website `jobs` INSERT/UPDATE remains. The migration must still not be applied until the cutover passes authenticated end-to-end QA and the full hosted-schema replay is complete.

## Hosted findings

Read-only inspection of project `jxbnrkasktbhtiujkhay` found:

- 69 hosted migrations versus the repository's divergent 238/240+ file history;
- no hosted `get_released_job_location` or `save_job_private_location` function;
- no hosted `block_user_v2` function; and
- hosted `mort_send_message` checks `user_blocks` without the shared pair lock.

These findings are why the drafts are not being applied directly to the hosted main project.

## Still externally blocked

The following cannot be completed safely from repository/database SQL alone:

- full backup restore proof;
- real Google OAuth login proof;
- age, identity, and school provider verification proof;
- leaked-password protection, which requires Supabase Auth configuration and may require a paid project tier;
- production provider/test-account setup; and
- final publishing, payments, document collection, and marketplace launch verification.

## Safe next step

Provide or approve a non-billable isolated Postgres/Supabase environment, or approve the Supabase branch cost, then replay the migrations there and run the two-session and RLS/Storage suites before any hosted main-project deployment is considered.
