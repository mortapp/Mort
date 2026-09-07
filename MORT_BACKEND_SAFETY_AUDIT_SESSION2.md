# MORT Backend/Safety Audit — Session 2

Continuation of Session 1. Covers Tracks 3-6 from the completion program: identity
verification, guardian/teen linking, moderation/staff privilege boundaries, and a
broad SECURITY DEFINER/RPC sweep. One real fix applied (see below); everything else
sampled was confirmed sound with no code change needed.

## Scope note on "Financial Safety" (Track 1)

The teen-facing Financial Safety feature described in the completion program (YTD
earnings tracking, expense ledger, receipts, annual export, tax-safety education) does
**not exist on `main`**. It exists only as uncommitted work-in-progress on the separate
`feature/compact-onboarding-and-screen-polish` branch (tied to open PR #4), which this
program was explicitly told not to touch. What *does* exist on main and was audited
instead is the Stripe financial-operations control layer
(`supabase/migrations/20260730120000_financial_operations_completion.sql`):

- `stripe_runtime_phase12_live_gate`: a **database CHECK constraint** (not just
  application logic) that blocks `mode = 'live'` unless ~15 separate approval flags
  (legal, privacy, minor-payout, tax-reporting, negative-balance plan, retention,
  receipts policy, reconciliation schedule, monitoring on-call, versioned partial-
  compensation policy, production release + timestamp) are all true. Cannot be
  bypassed from the API layer.
- `stripe_financial_incidents`: idempotent via `payload_sha256` replay-conflict
  detection, `private` schema (not API-exposed), service-role only.
- `get_my_job_payment_receipt` explicitly labels its output `not_tax_receipt: true`,
  `not_escrow: true` — no misleading financial claims.
- `service_hold_account_deletion_for_financial_retention` correctly pauses account
  deletion when Stripe records exist, rather than silently deleting financial history.

**Verdict:** the backend financial-operations control layer is sound. The client-side
teen earnings/tax-safety feature itself is simply not yet part of `main` and cannot be
scored here — it needs its own audit once/if PR #4 is reconciled.

## Track 2 continuation — payment/dispute lifecycle

- `stripe-create-job-payment-intent`, `-transfer`, `-refund` all pass an
  `idempotencyKey` to Stripe's API, preventing duplicate charge/transfer/refund on
  client retry. Payment-intent creation additionally requires a client-supplied
  `request_id` UUID threaded into a server RPC for DB-level idempotency, the same
  pattern used by messaging (`send_safe_message_v2`).
- Reviewer/operator separation of duties is **enforced in code**, not just displayed:
  `migrations/20260722202208_mort_0_9_3_payment_resolution.sql:284` raises
  `reviewer_financial_operator_separation_required` if the same user who reviewed a
  dispute tries to also execute its financial resolution.

## Track 3 — identity verification state machine

`identity-verification-session/index.ts` + `contract.mjs`:

- Fails closed (503) unless `IDENTITY_VERIFICATION_MODE=production` and every provider
  env var is set — no debug/bypass path.
- Provider handoff response is validated by `normalizeProviderHandoff`: provider-name
  binding check, status allowlist (`pending`/`needs_input` only), URL must be `https:`
  with no embedded credentials, **hostname must be in an explicit allowlist** (SSRF/
  phishing-redirect protection), and expiry must be in the future but capped at 30
  minutes. This is a materially above-average defense against a compromised or
  misbehaving identity provider redirecting users off-platform.
- `identity-verification-webhook` requires a signature/secret and returns 401 on
  `signature_missing`/`signature_invalid`.

**Verdict:** no gap found. `IDENTITY_INTERNAL` work here is complete; going live only
needs a real provider (external gate, unchanged).

## Track 4 — teen/guardian linking and privacy boundaries

- `create_guardian_invite_v2`: teen-only, rate-limited (5/day), caps concurrent pending
  invites at 3, stores the human-entered code only as a SHA-256 hash (not plaintext),
  uses a separate high-entropy token for the deep-link itself.
- `cancel_guardian_invite` / `resend_guardian_invite`: correctly scoped to
  `teen_id = auth.uid()`.
- `unlink_guardian`: either party (teen or guardian) can unlink an active connection;
  both are notified. Matches the documented "teen stays in control, mutual disengage"
  model.
- **Real gap found and fixed:** `accept_guardian_invite` had **no rate limit** on
  invite-code guessing. The human code is 8 hex chars (32 bits of entropy) and the
  lookup was a direct hash-equality scan with no throttle, so an authenticated
  guardian-role account could brute-force a link to an arbitrary teen. Fixed in
  `supabase/migrations/20260907000000_guardian_invite_accept_rate_limit.sql`
  (commit `f9f5861`) using the same `check_rate_limit`/`record_rate_limit_event`
  pattern already used successfully elsewhere (10 attempts/hour, failed attempts
  count toward the limit). Companion client-side friendly-error mapping in commit
  `a1be570`.
  - **Verification limitation:** no local Postgres/Supabase CLI was available in this
    session (Docker Desktop engine unreachable; `supabase` CLI not installed) and the
    repository has no pgTAP/SQL test harness, so this fix was verified by close
    reading and structural parity with the already-working
    `create_guardian_invite_v2`, not by executing it. **Recommend running this
    migration against a staging Supabase project before production deploy.**

## Track 5 — moderation/staff/admin privilege boundaries

- `is_admin()` reduces to `profiles.role = 'admin'`, and a trigger in the very first
  migration hard-blocks self-assignment: `raise exception 'Admin role cannot be
  self-assigned.'` on insert, and `raise exception 'Role changes require admin
  review.'` on any client-attempted `role` change on update. `verification_status` and
  `account_status` are similarly immutable from the client.
- `team_role_assignments` (staff/moderator roles) has **no RLS policy granting
  authenticated users any access at all** — the table is only reachable through
  `admin_create_team_role_assignment`, which requires `is_admin()`, enforces a bounded
  expiry (≤ 90 days, forcing periodic re-approval, no permanent grants), and starts new
  assignments in `pending_training` status. `has_ready_team_role()` (Session 1) then
  additionally requires active confidentiality acknowledgement, cleared conflict
  disclosure, approved device compliance, and completed training before the role
  actually grants anything. This is a genuinely layered staff-provisioning system.

**Verdict:** no gap found.

## Track 6 — broad SECURITY DEFINER / RPC sweep

- Wrote a small script to parse every `create or replace function ... security
  definer ... $$...$$;` block across all 195 migrations: **663 SECURITY DEFINER
  function definitions found, 0 missing an explicit `set search_path`** (the classic
  Postgres search_path-hijacking vector). Universal coverage.
- Confirmed a global hardening migration from very early in the project's history
  (`20260714031704_harden_profile_storage_business_logic.sql`) does
  `revoke execute on all functions in schema public from public, anon` **and**
  `alter default privileges for role postgres in schema public revoke execute on
  functions from public` — so any function added later that forgets an explicit
  `grant execute` is fail-closed (unusable) by default, not fail-open. This resolved
  an initial false-positive concern (some later functions, e.g.
  `stripe_server_update_controls`, appear to have no grant statement in the migration
  that redefines their body — but `CREATE OR REPLACE FUNCTION` preserves prior grants
  when the signature is unchanged, and the original grant from
  `20260722032907_stripe_connect_sandbox_foundation.sql` still applies).
- Checked every `execute format(...)` call using the unsafe generic `%s` placeholder
  instead of `%I`/`%L`: all instances found are `revoke/grant ... function %s ...`
  inside migration-time `do $$ foreach signature in array [...]` loops over
  **hardcoded literal arrays written in the migration source**, not runtime/user-
  supplied values. No SQL-injection vector — there is no attacker-controlled data path
  into these statements.

**Verdict:** no gap found beyond the one already fixed in Track 4.

## Running tally

BACKEND_P0=0, BACKEND_P1=0 (excluding the guardian-invite gap, now fixed)
SAFETY_P0=0, SAFETY_P1=0 (the guardian-invite brute-force gap was the one P1 found; fixed)
IDENTITY_ARCHITECTURE_P0=0, IDENTITY_ARCHITECTURE_P1=0
GUARDIAN_PRIVACY_P0=0, GUARDIAN_PRIVACY_P1=0 (post-fix)
MODERATION_P0=0, MODERATION_P1=0
PAYMENT_ARCHITECTURE_P0=0, PAYMENT_ARCHITECTURE_P1=0
FINANCIAL_SAFETY: backend controls audited and sound; client feature not present on
this branch (not applicable to score here — see scope note above)

Still open from Session 1's "not yet reviewed" list: full RLS policy predicate
correctness across all 195 migrations (existence was checked broadly, not every
predicate individually), storage bucket policies beyond the vault/evidence buckets
sampled, and Flutter-side repository code paths beyond guardian_repository.dart.
