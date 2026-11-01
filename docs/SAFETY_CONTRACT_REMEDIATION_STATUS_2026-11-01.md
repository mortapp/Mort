# MORT Safety-Contract Remediation Status — 2026-11-01

## Scope

The corrected append-only migrations and this report are now present in the `codex/flutter-backend-integration` checkout at feature-branch base commit `e55fdee8a61898965f6fa532bc705b8d38c04303`. No Supabase hosted schema, production data, auth configuration, provider configuration, or GitHub remote branch was changed.

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

### Private job-address release

`20261101123000_private_location_and_block_message_contract.sql` adds a hosted-schema-specific private location table and RPCs:

- `save_job_private_location(...)` stores exact address/coordinates outside the public job row;
- `get_released_job_location(uuid)` explicitly denies when the assignment or agreement row is absent, rather than allowing SQL `NULL` to bypass the denial;
- exact data is returned only to the poster or an active assigned teen after both safety-agreement confirmations match the current agreement version;
- unrelated users and blocked pairs receive only a denial/coarse location response; and
- private reads/writes are recorded in a restricted access-events table.

Saving a changed location now increments `location_version`, resets prior safety confirmations to pending, and binds the agreement to the new location version. The read RPC requires equality between the confirmed agreement version and the stored location version.

### Block/message concurrency

The same migration adds pair-locked `block_user_v2` and `unblock_user_v2` RPCs, and replaces `mort_send_message` with a matching deterministic user-pair advisory lock. Participant locks are acquired in sorted order, the conversation row is locked before status/message checks, and a send and a block for the same pair cannot pass their checks in opposite order.

## Validation completed

- Migration file encoding check passed.
- TypeScript check passed.
- Focused structural assertions passed for the job lock, duplicate guard, link-scoped resend, private location gates, pair locks, and restricted grants.
- Hosted project inspection was read-only.

## Validation not possible yet

- The repository's Supabase CLI could not connect to the Docker daemon in this execution environment, so no local replay ran here. If Docker is available in the user's local environment, the migrations should be replayed there as a syntax/regression check only.
- The billable isolated Supabase branch was not created.
- The repository's historical migration-parity check still fails on a pre-existing hash mismatch in `20260918032930_guardian_teen_summary_v1.sql`; that historical file was not rewritten.
- The new SQL has not been applied or syntax-replayed against a database.
- Independent two-session tests for application submission and block/send ordering remain outstanding.

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
