# MORT Backend/Safety Audit — Session 4 (exhaustive RLS/backend re-derivation)

Full-repository automated inventory plus manual re-derivation of every flagged
exception and every explicitly high-risk domain, superseding Session 1-2's "~90% of
sampled scope" note for Supabase/backend/RLS.

## Method

Wrote and ran (`scratchpad/rls_inventory.mjs`, `scratchpad/rpc_authz_scan.mjs`) two
migration-replaying scripts rather than re-sampling by hand:

1. A statement-splitter that walks all 196 migrations in order, tracking every
   `CREATE POLICY` / `DROP POLICY [IF EXISTS]` / `ALTER TABLE ... ENABLE/DISABLE ROW
   LEVEL SECURITY` / `CREATE TABLE` to compute the **current live policy set per
   table** (not just "does a CREATE POLICY exist somewhere," which would wrongly
   count policies a later migration dropped).
2. A grant/body scanner that finds every function granted `EXECUTE ... TO
   authenticated` and flags any whose body contains neither `auth.uid()` nor a known
   role-check helper — a concrete, checkable signal for "might be missing a caller-
   identity check," rather than an assumption.

## Findings

**Table/policy inventory:** 233 tables have RLS enabled; 295 tables have ever been
created; 206 have at least one live policy today. ~70 have RLS enabled with zero live
policies. Of those:
- ~27 are in the `private` schema, confirmed (Session 1) not reachable via the API at
  all (`supabase/config.toml` only exposes `public`, `storage`, `graphql_public`) — RLS
  there is defense-in-depth on top of schema-level lockout, not the only control.
- The rest are `public` schema tables individually checked for a live access path:
  - `payment_preferences`: deliberately decommissioned by
    `20260728220236_mort_payments_disabled_zero_fee.sql` (data zeroed, a CHECK
    constraint forces `preference = 'none'` forever, INSERT/UPDATE/DELETE revoked from
    `authenticated`) — payments are disabled, so no access is correct, not a bug.
  - `push_tokens`, `notification_preferences`: superseded by RPC-mediated access
    (`register_my_push_device_v2`, `get_my_notification_preferences`,
    `update_my_notification_preferences` in
    `20260730090000_fcm_remote_push_foundation.sql`).
  - `job_private_locations`, `job_location_share_sessions`, `job_arrival_handshakes`
    (the safety-critical exact-location tables): re-derived the actual predicate in
    `get_released_job_location()` (`20260819000000_job_site_precise_location_and_
    distance.sql:175`) line by line. Exact address is released only to the job poster,
    or to the accepted teen after **mutual** safety-agreement confirmation matching the
    current agreement version on both sides, and only while the job/application is in
    an active state; blocked-pair access is denied first; every access is written to
    `private_data_access_events` with a reason; denial returns only the general area/
    city/state, never a partial exact address. This is a genuinely strong exact-
    location-minimization control.
  - The remaining ~35 (support_*, ai_*, billing_*, push_delivery_*, onboarding_
    progress*, analytics_preferences, pilot_job_reviews, profile_update_audit_events)
    were batch-checked for at least one migration referencing the table by name — none
    are fully orphaned (all have ≥1 reference; several show only "1" because they're
    read inside functions using unqualified names under `search_path = public`, which
    a literal `public.<table>` grep undercounts — a methodology limitation, not a
    security finding). These were not each individually re-derived line-by-line; they
    are classified by consistent architectural pattern (locked table + SECURITY
    DEFINER/service_role-mediated access) that held in every one of the ~15 cases that
    *were* individually re-derived across all four sessions. Flagging this honestly
    rather than claiming literal line-by-line coverage of all ~35.

**RPC authorization scan:** 276 functions are granted to `authenticated`. The
heuristic scan flagged 10 as lacking a detectable `auth.uid()`/role-check. All 10 were
manually re-derived and cleared:
- `get_my_profile()`, `ensure_my_profile()`: thin `SECURITY INVOKER` wrappers that
  delegate to a `private.*` function holding the real `auth.uid()` check — the `private`
  schema isn't API-reachable, so the public wrapper is the only entry point and the
  check is real, just one call frame away from where the scanner looked.
- `create_guardian_invite()` (no-arg legacy overload): delegates to
  `create_guardian_invite_v2(null)`, which has the full auth/role/rate-limit checks.
- `support_internal_authorize()`: checks `auth.role() = 'service_role'` (a valid
  pattern the scanner's `auth.uid()`-only regex didn't recognize).
- `get_boosted_jobs()`: not `SECURITY DEFINER` at all (invoker semantics), returns only
  already-public "open" marketplace listings — bounded by the `jobs` table's own RLS
  for whichever role calls it.
- `get_first_party_trust_status()`, `get_release_mode_status()`,
  `production_identity_workflow_ready()`, `get_runtime_feature_status()`,
  `get_public_release_readiness()`: all return **global, non-personalized** platform/
  feature-flag/release-readiness state (maintenance mode, which providers are enabled,
  legal-document requirement lists) — there is no per-user data to leak by omitting an
  identity check, and this is a deliberate application pattern (client needs these
  flags to render banners/gates before the user is necessarily fully onboarded).

**Storage:** all 8 buckets (`proof-uploads`, `verification-uploads`, `profile-avatars`,
`identity-evidence`, `incident-evidence`, `support-evidence`, `support-attachments`,
`mort-document-vault`) are created with `public = false`, including buckets re-asserting
`public = false` on conflict (defensive re-application, not a one-time setting). Traced
the current live `storage.objects` policies (17 total) for the highest-stakes ones:
- `storage_mort_owner_insert`/`storage_mort_owner_select` (covers `proof-uploads`/
  `report-uploads`): folder-prefix-must-equal-`auth.uid()` ownership, plus a narrow
  `is_application_participant()` carve-out so the *other* party to a job (e.g. the
  poster) can view a teen's submitted proof photo — not a blanket bucket-wide read.
  `verification-uploads` branch: own-folder or `current_user_is_production_identity_
  reviewer()`, not blanket admin.
  (Bonus finding while reading this: `20260730203047_fix_identity_storage_policy_
  execution.sql`'s own comment documents a **real prior bug** the team already found
  and fixed — a query-plan evaluation-order issue that could make ordinary avatar
  replacement fail. Left as-is; already fixed upstream of this session.)
- `identity_evidence_authorized_production_reviewer_read`: five independent conditions
  ANDed together (bucket match, workflow-ready flag, reviewer-role check, a per-evidence
  `access_grant.reviewer_id = auth.uid()` grant record, production-path prefix match) —
  a reviewer can only read evidence they were specifically granted, not identity
  evidence broadly. One of the most tightly-scoped policies found in this codebase.

**Blanket-policy sweep:** grepped all 196 migrations for `USING (true)` (excluding
`WITH CHECK`), bare `WITH CHECK (true)`, and any `CREATE POLICY ... TO public` or
`TO anon`. **Zero matches for all four patterns across the entire migration history.**
Every RLS policy in this codebase is scoped to `authenticated` (or narrower); anon
requests get no direct table access anywhere.

## Verdict

RLS_P0=0, RLS_P1=0, STORAGE_SECURITY_P0=0, STORAGE_SECURITY_P1=0, RPC_SECURITY_P0=0,
RPC_SECURITY_P1=0, BACKEND_P0=0, BACKEND_P1=0 (for everything traced above). No new
defect found in this pass — the one real fix from Session 2 (guardian-invite rate
limit) remains the only backend/safety code change this program has made.
