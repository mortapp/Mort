# MORT 2.0 Execution Checklist — backend safety review

Status date: 2026-11-02  
Branch: `codex/guardian-rpc-privacy-20261102`  
Starting commit for this final recheck: `24d7de3457b4168b71d5e0f1983d944b6f723f2a`
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
- [x] Run the fixture-free proposal pgTAP suite: **23/23 passed**. Eighteen
  assertions inspect compiled source predicates, including terminal schedule
  replay and stale-verification-time rules; five call unauthenticated APIs
  with no JWT subject and verify denial.
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
  result; rechecks case identity; requires verified evidence to be generated
  and received no earlier than current case submission, not future-dated or
  expired; validates case/user/type/provider/reference; then writes the
  decision and audit atomically. The allowlist is empty. A real provider
  adapter still must verify signatures, event replay/order, tenant and
  case-bound references before any provider is enabled.
- Proposal 901 uses production Guardian semantics only. Guardian dual consent
  is required only when `jobs.requires_guardian_approval` is true; QA-only
  Guardian preferences/decision fields are absent. New
  `job_acceptance_in_progress_retry` propagates through the existing status
  update wrapper; Flutter has no dedicated retry message or automatic retry.
  The RPC signature is unchanged. Guardian dual consent is enforced only when
  production `jobs.requires_guardian_approval` is true.
- Proposal 902 checks persisted schedule keys before lifecycle state. The same
  teen/application/key/interval replays the original response after terminal
  job state; a new key still requires an active assignment, while a changed
  app/interval under an existing key returns `idempotency_key_reused`. Legacy
  schedule rows without interval metadata fail with
  `idempotency_result_unverifiable`; refresh/reconcile instead of claiming an
  exact retry.
  Completion replays a matching stored request ID and rejects a different ID
  on newly bound rows. Current Flutter UI generates a new UUID for every call
  and does not retain it across network retries; client idempotency is a
  separate follow-up. No Flutter behavior was changed here.

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

## 2026-11-02 — migration history and retry-contract recheck

- The previous “production row absent” conclusion for
  `20261102113314_guardian_id_response_mask_production` was incorrect. Current
  read-only `list_migrations` and `supabase_migrations.schema_migrations`
  inspection show all 73 production rows and this exact version/name as the
  final row, not an alias. Its one SQL payload is 1,598 bytes, SHA-256
  `96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa`, matching
  recovered SQL and manifest. All 73 ordered version/name pairs match the
  manifest. The earlier lookup query was not preserved, so the false-negative
  cause cannot be established more narrowly.
- Five guarded live production function MD5s still match the current
  definitions. A new clean local PostgreSQL 17.11 container replayed all 73
  production migrations with exact-byte streaming. All three proposals
  compiled; revised Proposal 900 review and Proposal 902 schedule definitions
  were separately compiled in a rollback-only transaction. Fixture-free
  pgTAP passed **23/23**, and both function definitions matched their
  pre-transaction hashes after rollback. Direct-select privacy pgTAP passed
  **5/5**. Local ACL checks showed anon/authenticated SELECT false and
  service_role SELECT true; local release controls were false and the provider
  allowlist was empty.
- The lock-key harness passed pair-lock serialization (2.395s), check-in
  request-key serialization (2.396s), and acceptance fail-fast (0.872s). It
  does not execute the actual application/acceptance RPC workflows.
- Authenticated verification, Guardian revocation, row-backed schedule and
  completion retries, real provider webhook events, RLS role matrix, and
  application/block/acceptance concurrency remain unverified until legitimate
  legal/provider/staff/test prerequisites are available. No synthetic
  identity/evidence was created.
- Production and hosted QA remained read-only.

## Production boundary

Production `jxbnrkasktbhtiujkhay` was queried read-only for migration/function
evidence. No production SQL, data, Auth, RLS, provider configuration,
release-control, marketplace, payment, document-collection, merge, push, or
deployment change occurred. Hosted QA was not modified.
