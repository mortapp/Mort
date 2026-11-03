# MORT 2.0 Execution Checklist — backend safety review

Status date: 2026-11-02  
Branch: `codex/guardian-rpc-privacy-20261102`  
Starting commit for this client-contract task: `3a294d68d9470b2892a6477ace1aed489933254b`
Scope: production migration replay, proposal 900–902 review, and Flutter check-in
retry compatibility. This file was not present in this checkout at task start;
it is the current execution record.

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
  update wrapper; the Flutter client maps it to a refresh-and-retry message but
  does not retry automatically.
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
  on newly bound rows. The updated local Flutter repository persists an
  operation ID and exact payload across ambiguous errors and app restarts;
  confirmed success or an explicit `{ok:false}` response ends that pending
  intent. A subsequent user action gets a new ID. This mobile code has not
  been deployed.

## Flutter retry implementation completed locally

- [x] Added a secure-storage check-in request coordinator. It writes the
  user/operation/entity scoped request ID and canonical payload before the RPC,
  resumes the same ID after timeout/restart, blocks payload changes while the
  previous result is uncertain, and coalesces concurrent duplicate calls
  process-wide across repository/coordinator instances. Secure-storage
  read/write failures prevent an untracked RPC. Malformed recovery state fails
  closed.
- [x] Wired scheduling and completion repository methods through the
  coordinator without changing the RPC names or parameter signatures.
- [x] Updated Safety Center to distinguish Proposal 902 replayed success and
  mapped transient acceptance, idempotency, terminal-lifecycle, stale-state,
  and authorization responses to safe user guidance.
- [x] Before final cross-instance fix: **629 passed, 2 skipped, 0 failed**.
  Final rerun after that fix: **632 passed, 2 skipped, 0 failed**.
  Coordinator/repository, error-mapping and Safety Center replay tests are in
  the full suite.
  Focused coverage includes timeout then process restart, payload mismatch/no
  send, terminal denial followed by a new key, success then a new user action,
  account/operation isolation, duplicate in-flight submission, explicit
  authorization denial, replay UI, stale response and retry errors.
- [x] Dart analyzer on every touched Dart source and test file: **no issues**.
  The earlier whole-package analyzer reported three `unnecessary_underscores`
  infos; those were corrected and the changed-file analyzer passed. The full
  test suite compiled and exercised the changed files after that correction.

## Proposal deployment order and rollback readiness

Recommended staging sequence, after a reviewed isolated authenticated run:

1. `20261102090000_verification_evidence_gate.sql` — provider evidence ledger
   and reviewer gate. Provider allowlist must stay empty.
2. `20261102090100_application_pair_lock_and_verification.sql` — current
   verification rechecks, pair locking and production acceptance contract.
   Guardian dual consent stays conditional on `jobs.requires_guardian_approval`.
3. `20261102090200_checkin_idempotency_lifecycle.sql` — additive nullable
   metadata, schedule retry binding and completion request binding.

The source-hash guards were last verified against the reconciled production
baseline; recheck all 73 versions and each guard immediately before a future
application. Each file owns one transaction and must be applied separately.
SQL failure before commit rolls back that file; previous committed proposals
remain. Rollback must restore captured prior function definitions in reverse
order while retaining additive columns/indexes/evidence/audit data. No reverse
SQL is prepared. Client release should precede or coordinate with Proposal
902; RPC signatures are unchanged. Proposal 901's transient denial now has a
client message, but no automatic retry is performed.

## External QA prerequisites

- **Counsel:** approve synthetic-account legal versions and age/identity/school
  evidence collection, retention, appeals, deletion and consent language.
- **Verification provider:** select/approve provider; supply sandbox credentials,
  documented signed callback/event ID/timestamp/tenant contracts, case binding,
  expiry and positive/negative sandbox results. No provider is enabled.
- **MORT operations:** authorize/train an initial reviewer, scoped staff
  membership/permissions, MFA/AAL2 and audit access using an approved bootstrap.
- **QA operations:** provision the applicant, poster, connected/consenting
  Guardian, revoked Guardian, unrelated user and administrator through supported
  onboarding; provide versioned legal consent, synthetic application/check-in
  fixtures and isolated client/service-role credentials through a secret store.

Until these exist, local client tests, static/schema checks, clean baseline SQL
compilation and fixture-free/negative tests can continue. Provider-positive,
authenticated role, row-backed lifecycle and actual two-session RPC tests stay
blocked. No identities or evidence were fabricated.

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
evidence. The final read-only recheck found 73 migration rows through
`20261102113314` and all five proposal function hashes still match. No
production SQL, data, Auth, RLS, provider configuration,
release-control, marketplace, payment, document-collection, merge, push, or
deployment change occurred. Hosted QA was not modified.

## 2026-11-02 — final retry/proposal review from `ae24fd7`

- The first cross-instance concurrency regression test failed against the
  starting implementation: two separate repository/coordinator instances
  issued **2 RPC calls** for one concurrent logical schedule operation. The
  in-flight registry was instance-local even though the secure intent is
  process-shared.
- The fix makes in-flight coalescing process-wide, keyed by user, operation and
  entity. The regression now requires one RPC and one shared result. It does
  not coordinate multiple OS processes or Flutter isolates.
- Tests verify pending state is stored before the RPC, timeout followed by a
  newly constructed repository reuses the exact request ID and payload, changed
  payload is rejected without network access, storage read/write failures
  prevent an untracked RPC, explicit denial clears the intent, and a later user
  action gets a new ID.
- A new disposable local PostgreSQL 17.11 container replayed all 73 migration
  files byte-exactly. Its five pre-proposal function MD5s matched the source
  guards: 900 `9de9e53ea3e300b78819932eabc14594`; 901
  `401d64ec19cf1fa1ab072709266fe4a7` and
  `a44e036f16579106d9ae615d2a54235f`; 902
  `68ddb42187ef290145bda12d93a7b00b` and
  `7a7b9ea9824a47e14e783b79aefac098`.
- All three proposals compiled on that clean local baseline. The revised 900/902
  function test passed fixture-free pgTAP **23/23** in a rollback-only
  transaction. Application direct-SELECT pgTAP passed **5/5**; local ACL checks
  showed anon/authenticated table and column SELECT false, service_role true.
  Provider allowlist count remained zero and local marketplace/document controls
  were set false by the local test harness only.
- Proposal 900–902 were reviewed locally against that reconciled baseline; no
  hosted environment was contacted for this review. Rollout remains 900 → 901 → 902, each in its own
  reviewed transaction, with captured function definitions restored in reverse
  order and additive evidence/audit data retained. The provider allowlist stays
  empty; Guardian consent remains conditional on
  `jobs.requires_guardian_approval`; Proposal 902 exact-key/exact-payload replay
  remains distinct from new or changed requests.
- Authenticated provider, role/RLS, and real RPC concurrency behavior remains
  unverified. Flutter tests do not establish database behavior.
- Proposal 901 review identified a P2 availability concern preserved from the
  current contract: `mort_accept_job_application` locks the requested
  application before checking the caller owns the job. An unrelated active
  adult cannot read its contents but may briefly contend on the row. Track an
  unlocked owner-scoped preflight + final ownership recheck, preserving the
  existing lock order, and prove denial cannot hold the target row in two
  sessions before production application.
