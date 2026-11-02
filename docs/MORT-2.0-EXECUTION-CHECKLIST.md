# MORT 2.0 Execution Checklist — backend safety review

Status date: 2026-11-02  
Branch: `codex/guardian-rpc-privacy-20261102`  
Starting commit: `8435e63b73c10991a1ca26d10946e3c58a58226b`  
Scope: production migration replay and review of proposals 900–902. This file
was not present in this checkout at task start; it is added here as the current
execution record.

## Completed with evidence

- [x] Reconcile the historical Git blob check. The local
  `20260918032930_guardian_teen_summary_v1.sql` Git blob is
  `65455e7593dbcb51612f71303ba808063b43f6a6`. The old validator hashed a
  literal backslash-plus-zero separator and returned
  `21eb6a0accd633b5fb92319b4062385a931899b6`; Git uses a NUL byte. The
  validator now uses a NUL and `node scripts/qa-migration-reconciliation-parity.mjs`
  passes. Production has no active ledger row for this version/name, so an
  exact production SQL payload comparison is not available. Historical SQL
  and expected hash were preserved.
- [x] Recreate all 73 production SQL migrations from empty MORT schema state
  on local PostgreSQL 17.11 (`170011`) using byte-exact file streaming:
  `FRESH_PRODUCTION_BASELINE_REPLAY=PASS
  73|20261026194801|20261102113314|73`.
- [x] Verify five proposal source guards against production before applying
  proposals. Production and clean local baseline MD5s matched:
  `9de9e53ea3e300b78819932eabc14594`,
  `401d64ec19cf1fa1ab072709266fe4a7`,
  `a44e036f16579106d9ae615d2a54235f`,
  `68ddb42187ef290145bda12d93a7b00b`,
  `7a7b9ea9824a47e14e783b79aefac098`.
- [x] Apply guarded proposals 900, 901 and 902 locally; all three completed
  their transactions successfully. Proposal 902 now rejects a mismatched
  completion request ID for a newly bound check-in while preserving the
  legacy response only for old rows with no bound request ID.
- [x] Run direct-SELECT privacy pgTAP unchanged: **5/5 passed**. `anon` and
  `authenticated` have no table or column SELECT; `service_role` retains
  SELECT; scoped application RPC remains SECURITY DEFINER.
- [x] Run the fixture-free proposal pgTAP suite: **19/19 passed**. Fourteen
  assertions inspect compiled source predicates; five call unauthenticated
  APIs with no JWT subject and verify denial.
- [x] Run the two-session advisory-lock protocol harness on PostgreSQL 17.11:
  participant-pair serialization in 2.396s, check-in request-key
  serialization in 2.370s, and same-job fail-fast in 0.831s. This tests lock
  keys only, not authenticated application RPC workflows.
- [x] Keep local test state fail-closed after replay. The 73rd historical
  migration sets the local public-marketplace flag true; a test-only local
  override reset it to false. Real document collection is false and the
  provider allowlist is empty. Production runtime values were only read.
- [x] Compare the prior PostgreSQL 17.6 scratch container with fresh 17.11
  using read-only catalog checks. The exact observed difference is server patch
  version (`17.6.1.140` vs `17.11.0.006` image; PostgreSQL reports `17.6` vs
  `17.11`). Both sampled catalogs have `auth.users.email_confirmed_at`,
  Storage `buckets`/`objects`, `storage` owned by `supabase_admin`, and matching
  `job_applications` SELECT privileges after the local ACL bootstrap. The
  17.11 clean replay required the documented Auth/Storage bootstrap. This was
  not an exhaustive Supabase platform parity test. No disposable managed
  17.11 clone was available without creating/charging for a hosted resource.
- [x] Final static proposal suite, migration encoding scan (240 files),
  reconciliation parity, 73-file source recovery, JS syntax checks, and
  `git diff --check` pass. The guarded ACL script was rerun against only the
  fresh 17.11 container and confirmed `anon=false`, `authenticated=false`,
  `service_role=true` for table and column SELECT.

## Proposal review findings still requiring work

- Proposal 900 locks reviewer subject/profile, provider allowlist, case, and
  result; rechecks case identity, requires a successful result received after
  case submission, validates type/provider/reference and expiry, then writes
  the decision and audit in one transaction. It does not require provider
  `verified_at` to be after case submission. Provider timestamp semantics and
  signed webhook binding are unknown. Keep the allowlist empty until the
  provider callback and event semantics are reviewed.
- Proposal 901 uses production Guardian semantics only. Guardian dual consent
  is required only when `jobs.requires_guardian_approval` is true; QA-only
  Guardian preferences/decision fields are absent. New
  `job_acceptance_in_progress_retry` propagates through the existing status
  update wrapper; Flutter currently has no dedicated user-facing retry
  message. Add client/API compatibility and actual concurrency tests.
- Proposal 902 checks active assignment/job before schedule idempotency lookup;
  a retry after terminal lifecycle returns `active_assignment_required`. It
  writes no new row, but terminal retry semantics need a client decision. A
  mismatched completion request ID for newly bound rows now returns
  `idempotency_key_reused`; actual retries still need row-backed tests.

## Validation limits and release blockers

- Local runtime is PostgreSQL 17.11, not the hosted managed Supabase service.
  Bootstrap adds the missing empty `auth.users.email_confirmed_at` column and
  minimal Storage bucket/object tables plus `storage.foldername`. No Auth
  users or Storage objects were copied; this does not emulate the full Auth or
  Storage services.
- No real Auth account, profile, legal acceptance, Guardian link, verification
  case/evidence, staff identity, application, assignment, or check-in fixture
  was created. The fixture-free assertions do not prove runtime state
  transitions or authenticated RLS.
- Still blocked: provider-backed verification positive flows; expired/revoked
  verification against real rows; stale-case concurrency; duplicate
  acceptance; Guardian-consent revocation race; matching/mismatched check-in
  retries against real rows; two-session application/acceptance/block races;
  authenticated RLS; and managed Auth/Storage parity.
- Required prerequisites remain approved legal documents for test accounts,
  supported provider sandbox credentials/results, authorized human reviewer
  provisioning, synthetic accounts through supported onboarding/consent, and
  isolated service-role credentials. Do not fabricate them or bypass
  triggers/RLS.

## Production boundary

Production `jxbnrkasktbhtiujkhay` was queried read-only for migration/function
evidence. No production SQL, data, Auth, RLS, provider configuration,
release-control, marketplace, payment, document-collection, merge, push, or
deployment change occurred. Hosted QA was not modified.
