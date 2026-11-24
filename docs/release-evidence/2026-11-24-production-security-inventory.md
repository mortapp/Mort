# Production Security Inventory (Local)

**Date:** 2026-11-24  
**Branch:** `feature/compact-onboarding-and-screen-polish`  
**HEAD:** `3d18236937206ae4b34b2103c913ee8a9e3fa44e`  
**Scope:** Local migration/code/document review only. **Hosted Supabase Security Advisor, Database Linter, GraphQL schema introspection, role/grant state, and Auth configuration were not verified in this session.** Counts below reflect migration text/history and may differ from the live project.

## Requested audit targets (user-stated, not locally confirmed)

The following items were reported as blockers and must be verified against the hosted project:

1. Review all **70 authenticated-executable security-definer functions**.
2. Review **39 authenticated-visible GraphQL tables** and **1 anon-visible table**.
3. Resolve inappropriate grants and exposure.
4. Fix the `profiles` permissive-policy warning.
5. Address leaked-password protection.

**Status:** Cannot confirm or close these hosted findings from this local checkout. Any remediation that changes database behavior should be coordinated with Codex/DB ownership and verified in a non-production environment before production.

## Local inventory methodology

Searches run from repo root over `supabase/migrations/*.sql` and `docs/`:

- `security definer` occurrences: literal string search across migrations.
- Security-definer function definitions: extracted by scanning `create [or replace] function ...` and checking for `security definer` in the following definition header.
- Execute grants: `grant execute on function ... to authenticated|anon|service_role` lines.
- Table grants: `grant ... on table ... to anon|authenticated|service_role` lines.
- RLS/policies: `enable row level security`, `create policy`, `alter policy`, and `profiles`-specific policy changes.
- Docs: `docs/ENABLE_LEAKED_PASSWORD_PROTECTION.md`, payment/release/security-related docs.

## 1. Security-definer functions

| Metric (local migrations) | Value | Notes |
| --- | --- | --- |
| `security definer` string occurrences | **771** | Includes redefinitions across historical migrations. |
| Extracted security-definer function definitions | **534** definition entries | Parsed from migration history; not deduplicated to final deployed state. |
| Unique function names with a security-definer definition | **431** | Includes `public.*` and `private.*` functions; may include superseded names. |
| `grant execute on function ... to authenticated` lines | **268** | Migration-history lines; some may be revoked or re-granted later. |
| Unique function signatures/names granted execute to authenticated (parsed) | **226** | Parsed from grant lines; rough indicator only, not a proof of current effective privileges. |
| `grant execute on function ... to anon` lines | **5** | See anon exposure section. |

**Interpretation:** The local migration history contains far more security-definer definitions than the reported “70 authenticated-executable” advisor count. This is expected if the advisor counts current effective, exposed, authenticated-executable functions while migrations include private helpers, service-role-only functions, superseded definitions, and non-exposed routines. A definitive review requires hosted advisor details plus current `pg_proc`, `information_schema.routine_privileges`, and schema exposure state.

**Review focus for the reported 70 functions (hosted):**
- Confirm each function’s `search_path`, ownership, caller checks (`auth.uid()`, role/account checks, contract-party checks), and whether it should be `security invoker` or `security definer`.
- For functions executable by `authenticated`, verify inputs are validated and authorization is enforced inside the function (not only by caller assumptions).
- Ensure sensitive functions are not granted to `anon`/`public` unless intentionally public and safe.
- Compare advisor export against the final migration state and any dashboard-created objects.

## 2. Grants and role exposure

### Function execute grants to `anon` (local evidence)

| Migration | Grant |
| --- | --- |
| `20260717161125_mutual_identity_verification.sql` | `execute on function public.get_public_trust_badges(uuid) to anon, authenticated, service_role` |
| `20260720175005_final_production_pilot_controls.sql` | `execute on function public.get_release_mode_status() to anon, authenticated` |
| `20260722234500_mort_0_9_4_operational_controls.sql` | `execute on function public.get_runtime_feature_status() to anon, authenticated, service_role` |
| `20261027084715_mort_release_mode_status.sql` | `execute on function public.get_release_mode_status() to anon, authenticated, service_role` |
| `20261027084830_mort_release_status_invoker_access.sql` | `execute on function public.get_release_mode_status() to anon, authenticated, service_role` |

These appear intentionally public/runtime-status related in name, but each must be reviewed for returned data sensitivity and abuse/rate-limit posture.

### Explicit table grants to `anon` (local evidence)

| Migration | Grant | Notes |
| --- | --- | --- |
| `20261027084830_mort_release_status_invoker_access.sql` | `grant select on table public.mort_release_control to anon, authenticated` | Likely corresponds to the reported “anon-visible table” candidate; must be confirmed against hosted advisors/GraphQL exposure and data contents. |

No other direct `grant ... on table ... to anon` lines were found by the local search, but schema-level/default privileges and exposed API configuration are not fully represented in migrations.

### Explicit table grants/selects to `authenticated` (local evidence)

Local search found `grant select on ... to authenticated` in many migrations (profiles, support/evidence, identity verification, legal acceptances, notification/safety/dispute-related tables, etc.) and a small number of `insert/update/delete/all` table grants in specific migrations (for example legal contract tables, private/service-role-oriented grants in some contexts). Full effective exposure requires hosted privilege and API-schema review.

## 3. RLS and profiles policies

### Profiles policy history (local)

- Initial: `profiles_select_visible`, `profiles_insert_self`, `profiles_update_self_or_admin` (`202607070001_initial_mort.sql`).
- Later modifications: `20260714031706_optimize_rls_policies.sql` (`alter policy` for profiles/related profile tables), `20260730071000_guardian_age_audit_and_pilot_review_boundary.sql`, `20260730076000_fix_guardian_profile_policy_recursion.sql` (revised `profiles_select_visible` to avoid recursion).
- Related/role-specific profile tables: `teen_profiles`, `adult_profiles`, `guardian_profiles`, `account_trust_profiles` have their own policies and grant changes.

### “Profiles permissive-policy warning” (reported)

**Local status:** Not reproducible from migration text alone. No obvious `using (true)`/`with check (true)` policy on `public.profiles` was identified in the sampled searches. Supabase permissive-policy warnings commonly arise from multiple permissive policies for the same table/role/action, or from policies that allow broader access than intended.

**Required hosted verification/remediation:**
1. Export the exact advisor warning and affected policy names/commands/roles.
2. Inspect effective policies on `public.profiles` (`pg_policies`) and combined permissive behavior for `anon` and `authenticated`.
3. Refactor overlapping permissive policies into restrictive/combined logic as appropriate, preserving legitimate participant/admin access.
4. Add regression SQL tests proving unauthorized cross-tenant/role reads/writes are denied and legitimate flows still work.

## 4. GraphQL / table visibility

The requested blocker states **39 authenticated-visible GraphQL tables and 1 anon-visible table** with inappropriate grants/exposure.

**Local status:** Cannot enumerate actual GraphQL-exposed tables. Local migrations show explicit grants/revokes but not the full hosted API exposure configuration (exposed schemas, GraphQL enablement, default privileges, dashboard changes). `public.mort_release_control` is explicitly selectable by `anon, authenticated` in migrations and is a likely candidate for anon visibility, but this must be confirmed.

**Inventory approach for hosted review:**
1. Run Supabase Security Advisor / GraphQL exposure checks and export the exact object list.
2. For each exposed table/view: confirm intended audience, RLS enabled/forced as applicable, grants, and whether GraphQL/PostgREST exposure is required.
3. Revoke unnecessary `anon`/`authenticated` grants and/or remove objects from exposed schemas; add least-privilege RPCs for required access.
4. Re-run advisors and API contract tests after each change.

## 5. Leaked-password protection

**Status:** **Deferred — plan-limited security enhancement** (documented, not a local code fix).

Evidence in docs:
- [docs/ENABLE_LEAKED_PASSWORD_PROTECTION.md](/C:/Users/micha/Mort/docs/ENABLE_LEAKED_PASSWORD_PROTECTION.md): HaveIBeenPwned leaked-password protection unavailable on Free plan (verified 2026-07-14 per doc); requires Pro+ and immediate enablement after authorized upgrade.
- [docs/codex/MORT_SUPABASE_SECURITY_REGRESSION.md](/C:/Users/micha/Mort/docs/codex/MORT_SUPABASE_SECURITY_REGRESSION.md) and other readiness docs repeat the same classification.

**Action:** When/if an authorized plan upgrade occurs, enable leaked-password protection in Supabase Auth and rerun Auth security advisors. This is blocked on product/billing authorization and hosted configuration, not on application code changes in this repo.

## 6. Recommended remediation sequence (non-destructive, hosted-verified)

1. **Obtain ground truth:** export current Supabase advisors, GraphQL exposure list, `pg_policies`, and role privileges for the reported objects.
2. **Profiles warning:** fix the specific permissive-policy condition with minimal policy changes and SQL regression tests.
3. **Anon/auth exposure:** remove or tightly scope the anon-visible table and any unnecessary authenticated table visibility; replace with RPCs/views where appropriate.
4. **Security-definer audit:** triage the 70 reported functions by risk, set correct `search_path`, enforce authorization, and reduce grants/invoker where safe.
5. **Re-verify:** rerun advisors, lint, RLS tests, and app smoke tests in staging before production.

## Limitations

- No `ALTER ROLE`, dashboard-only settings, or post-migration manual SQL outside `supabase/migrations` are visible here.
- Historical migrations may be superseded; final effective state depends on what has been applied to each environment.
- This inventory does not prove that any table is or is not exposed via GraphQL in the live project.
- No database changes were made by this inventory task.

*This report does not claim security audit completion or production readiness and does not assign a readiness percentage.*