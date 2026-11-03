# MORT backend security remediation backlog — 2026-11-02

Scope is the current production source observed read-only on `jxbnrkasktbhtiujkhay` and its checked-in production migrations. This is a proposal backlog. Nothing here was applied to production. SQL drafts are under `supabase-production/proposals/`, outside Supabase CLI's migration directory.

## Priority 0 — verification approval must be backed by evidence

- **Severity / exploitability:** Critical safety-integrity issue; medium exploitability. Only an authorized admin/moderator can call the RPC, but a compromised, mistaken, or malicious reviewer can currently set any existing verification case to `verified` without a matching provider result or evidence. The current minimum-age check does not establish identity, school enrollment, or independent age evidence.
- **Affected:** `public.mort_review_verification_case(uuid,mort_verification_status,text,timestamptz)`, `public.verification_cases`, `public.profiles`, `public.admin_audit_log`; age, identity, school ID/email, business verification and role activation.
- **Unsafe behavior:** The live RPC accepts `verified`, checks only that DOB exists and age is at least 13, then changes status and writes an audit row. It does not require `provider`, `provider_reference`, `evidence_path`, a signed provider result, a case-type match, or evidence provenance.
- **Narrow proposal:** Add a private provider-result ledger keyed to the existing case and subject, restricted to trusted server-side inserts. The reviewer may approve only when a current, successful, case-type-matched result exists and its provider/reference match the case. No manual override is proposed. An empty provider allowlist keeps verification fail-closed until a provider is selected, approved, integrated, and its webhook signature validation is deployed. Retain the existing minimum-age check and audit trail.
- **Regression tests:** unauthenticated/nonstaff denied; staff can reject/mark needs-review without provider evidence; staff cannot verify missing/mismatched/rejected/expired/wrong-type/untrusted evidence; cannot verify under-13 or missing-DOB user; can verify only with matching current successful evidence; replayed provider event is unique; reviewer and evidence attempts are audited; provider result/document details never appear in public reads.
- **Prerequisites:** Provider selection, contract and sandbox credentials; counsel/product approval of accepted evidence per verification type; secure provider callback deployment and signing-secret provisioning. No production documents or real identity data may be collected before those gates pass.
- **Concurrency review:** The first draft locked the case before the subject profile, opposite the application/acceptance eligibility order and therefore deadlock-prone. The proposal now locks profile, then provider allowlist when approving, then case, and rechecks captured subject/provider/type/reference plus status/update timestamp under `FOR UPDATE`, rejecting stale reviewer snapshots. Provider callback code must follow the same subject/profile → allowlist → case → result order. A separate review found eligibility locking profile→job while acceptance locks application→job→pair→profile; eligibility now locks job→pair→profile to remove that cycle. Static lock-order checks pass; multi-session RPC behavior remains required.

## Priority 0 — acceptance must serialize with blocking

- **Severity / exploitability:** High safety/authorization severity; moderate exploitability requiring two concurrent participant actions. A teen or poster can block the other participant while the job poster is accepting an application.
- **Affected:** `public.mort_accept_job_application(uuid)`, `public.block_user_v2(uuid,text,uuid)`, `public.unblock_user_v2(uuid)`, `public.user_blocks`, `public.job_applications`, `public.job_assignments`, `public.jobs`, conversation creation.
- **Unsafe behavior:** Acceptance locks application and job, checks `user_blocks`, then inserts an assignment. The live production function does not acquire the deterministic participant-pair advisory lock used by block and message operations. A block may commit between acceptance's check and assignment creation.
- **Narrow proposal:** After confirming the requested application belongs to the poster and its job, acquire the same transaction advisory lock key as `block_user_v2`/`mort_send_message`: `hashtextextended(least(v_user, applicant_id)::text || ':' || greatest(...)::text, 0)`. Check blocks only after acquiring it; keep existing job/application locks, eligibility checks, state transitions and grants. If a block wins the lock, acceptance observes it and fails; if acceptance wins, the block waits until the assignment is committed.
- **Regression tests:** two database sessions race accept vs block in both orders; exactly one valid ordering wins; no assignment/conversation is created if the block commits first; transaction rollback leaves no partial assignment; self-block/null/application-owner checks remain; unrelated pairs do not serialize.
- **Prerequisites:** None beyond isolated PostgreSQL 17, synthetic applicant/poster fixtures and independent sessions. Marketplace stays disabled.

## Priority 1 — recheck current teen verification at application and acceptance

- **Severity / exploitability:** High safety/eligibility severity; low-to-moderate exploitability. A teen whose role was approved earlier may retain an active profile after age, school-ID, or school-email verification expires or is revoked. The public eligibility RPC currently checks current age verification only; acceptance checks age but not school ID/email.
- **Affected:** `public.get_job_application_eligibility(uuid)`, `public.mort_accept_job_application(uuid)`, `public.verification_cases`, `public.profiles`, `public.jobs`, `public.job_applications`, Guardian links and role activation.
- **Unsafe behavior:** Current role activation requires verified age, school ID and school email, but eligibility/acceptance do not consistently revalidate all three current cases. Expired/rejected/revoked school verification can therefore be ignored while a profile remains `active`.
- **Narrow proposal:** Lock the teen profile and its verified age/school-ID/school-email case rows, capture a fresh `clock_timestamp()` after locks, and require each role-required verification to remain `verified` and unexpired. Apply the same checks in both eligibility and acceptance. Preserve job age bounds, Guardian dual-consent requirements, release controls, block checks and existing return/error shape; use explicit fail-closed codes for each missing track. Recheck adult identity expiry at acceptance using the same post-lock timestamp.
- **Regression tests:** independently expire/reject/revoke each teen track after role activation and confirm both eligibility and acceptance deny; valid three-track teen succeeds; adult identity expiry denies acceptance; boundary expiry is evaluated after lock; update/review concurrent with submission/acceptance serializes; Guardian requirement and existing job age limits remain enforced.
- **Prerequisites:** Correctly classifying an expiry/revocation as invalid requires provider policy; test fixtures need verified-state records issued by an approved QA provider/reviewer. No production approval needed for drafting.

## Priority 1 — check-in request idempotency and active-job lifecycle

- **Severity / exploitability:** Medium-to-high safety-integrity severity; moderate concurrency/expiry risk. Any active teen can call the authenticated RPC for their own check-in. The current completion request ID is required but ignored; completed check-ins can be reported as successful with any new request ID. Scheduling does not lock/recheck the assignment or job lifecycle, and a reused schedule request ID can return an old check-in for a different application or interval.
- **Affected:** `public.schedule_active_job_checkin(uuid,integer,uuid)`, `public.complete_active_job_checkin(uuid,uuid)`, `public.job_safety_checkins`, `public.job_assignments`, `public.jobs`; safety notifications/escalation readers.
- **Unsafe behavior:** Scheduling selects an accepted/in-progress assignment without row locks or checking current job state; on an idempotency-key conflict it returns the prior check-in without comparing application/interval. Completion accepts a required request ID but never stores or compares it and does not verify the related assignment/job remains active.
- **Narrow proposal:** Add nullable requested-interval and completion-request fields (preserving existing rows), a bounded interval check, and a partial unique index for completion request IDs. Lock assignment then job then check-in (matching safety-cancellation's assignment/application/job order), require assignment `accepted|in_progress` and job `filled|in_progress`, and recheck participant/application/job relationships. Bind new schedule retries to the original application and interval; conflict on changed application/interval. For legacy rows with no stored interval, fail with `idempotency_result_unverifiable` rather than assert payload equality. Bind completion retries to the request ID, make only a `scheduled`→`completed` transition, and fail closed after cancellation/closure.
- **Compatibility refinement:** An exact same request ID, application and interval replays the original schedule output, even after job termination. New keys after termination fail the active lifecycle check. A legacy schedule key whose interval was not persisted is explicitly unverifiable and requires refresh/reconciliation. Authorized reads of already-completed legacy check-ins remain no-op success with `payload_verified=false`; bound completion IDs must match.
- **Regression tests:** same-key/same-payload schedule replay; same-key/different-application and different-interval conflict; two-session duplicate schedule; completion same-key replay; key reused across check-ins denied; different key after completion has explicit stable result; concurrent cancel/complete and complete/complete; no new check-in after terminal assignment/job; all existing teen/participant RLS and escalation behavior unchanged; legacy rows with null new fields remain readable and are never overwritten.
- **Prerequisites:** Isolated PostgreSQL 17 with synthetic accepted/in-progress assignments and two independent sessions. Do not create a real funded job; the existing payments-off gate must remain closed.

## Six Guardian privacy QA roles — supported setup prerequisites

The isolated project had no Auth users/profiles, effective published legal versions, verification cases, staff memberships, applications or Guardian links when checked. No user or relationship was fabricated.

| Fixture | Supported prerequisites | External dependency |
|---|---|---|
| Applicant | Confirmed Auth account; DOB 13–17; teen onboarding; effective legally approved terms accepted; verified age, school ID and school email; approved role; one eligible synthetic application with Guardian consent if required | Legal counsel/publication; approved verification provider and QA evidence; staff reviewer/role approval |
| Poster | Confirmed adult Auth account; DOB 18+; adult onboarding and effective legal acceptance; current verified identity; active adult role; synthetic job/application | Legal publication, identity provider QA, staff role approval; isolated-only job/application fixture without enabling production publishing |
| Connected Guardian | Confirmed adult Guardian account; completed adult onboarding/legal acceptance; teen-issued invite; Guardian accepts invite; both teen and Guardian consent current | Legal publication; two synthetic accounts and invitation email/code delivery |
| Revoked Guardian | Establish a valid connected Guardian first, then use supported unlink/revocation workflow and verify no current link | Same as connected Guardian; consent flow and fixture |
| Unrelated user | Confirmed active synthetic account with no application/Guardian relation | Auth email confirmation and test credentials |
| Administrator | Auth user plus approved staff identity/membership, separation-of-duties/first-reviewer authorization, completed training and permissions | Explicit staff authorization and operational provisioning; no self-provisioned admin |

Harness inputs additionally require application ID, Guardian ID, six synthetic credential pairs, isolated URL/anon key and a server-only isolated service-role key. Store credentials only in the approved local secret store/CI secret context. Never place them in source, logs, SQL files, or chat. Current verification RPCs report providers/submissions unavailable and there is no active staff assignment, so the role matrix remains blocked until those dependencies are fulfilled.

## Execution status and controls

- Read-only production inspection only; no DDL/data/Auth/release-control writes.
- Production migration catalog reports 73 applied versions through
  `20261102113314`. The local SQL directory, manifest, and hosted ledger now
  each contain the same 73 version/name pairs in the same ascending order.
- Recovered `20261102040639_restrict_job_application_direct_select` directly
  from the production ledger into
  `supabase-production/recovered-ledger-sources/`; SHA-256 is
  `d816da845f1c71643a0d577b9629b98b3e8db9c0ed4c3667e8a4e7db7a60cf6d`.
  Its existing local migration's executable body matches production after
  line-ending/trailing-newline normalization; local editorial comments are
  preserved and the historical file was not rewritten.
- Recovered exact ledger SQL for
  `20261102113314_guardian_id_response_mask_production` into the migration
  directory; SHA-256 is
  `96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa`.
  This is historical source already applied in production, not an instruction
  to execute it again. Both recovered payloads were byte-for-byte verified
  against their production ledger SQL values.
- Fixture-free local negative tests passed for anonymous/no-claim rejection,
  anon EXECUTE denial, SECURITY DEFINER/empty-search-path preservation, private
  evidence-table RLS and grants, and an empty provider allowlist. The test ran
  inside a transaction and rolled back.
- The production runtime status was read-only verified as marketplace closed,
  new publishing disabled, payments disabled, real document collection false,
  and AI provider disabled. The proposals do not write release-control rows.
- No production migration or the stale Guardian-ID response-mask proposal was applied.
- No changes to marketplace, publishing, payments, document collection, or AI controls are proposed.
- The complete 73-file baseline replay passed on disposable local PostgreSQL
  17, reporting 73 local ledger rows from `20261026194801` through
  `20261102113314`. All three final proposal SQL files compiled from a clean
  baseline. One intervening attempt to reapply drafts over already-replaced
  local functions was rejected by their exact-source guards; a clean local
  reset/replay followed and the final clean compile passed.
- Fixture-free local SQL authorization checks passed and rolled back. A new
  independent two-session test passed for the canonical participant-pair
  advisory lock in reversed participant order and the check-in completion
  request lock (both contenders waited until the holder committed). These
  verify lock-key serialization only; they do not exercise authenticated RPC
  behavior or application/check-in fixtures.
- Provider-evidence, positive authorization, Guardian RLS/API behavior,
  application-vs-block RPC race, and check-in lifecycle RPC race remain unrun.
  Do not run proposals against production; exact-source guards stop if the
  inspected definitions have changed.
- The full isolated Guardian role matrix remains blocked: no approved legal
  versions, provider sandbox/submissions, authorized first-reviewer/staff
  membership, synthetic accounts/application/Guardian relationship, or
  server-only QA service-role credential is provisioned. No such data was
  fabricated.
- Required next actions: choose and approve age, identity and school evidence
  providers/policies; publish
  counsel-approved test legal versions in isolated QA; provision an authorized
  reviewer with training; create six synthetic accounts through Auth and the
  supported onboarding/Guardian flows; issue a synthetic application through
  a reviewed isolated-only fixture path without enabling production gates; then
  run provider evidence, applicant/poster/Guardian/admin privacy and nested
  response tests plus real two-session block/accept and check-in lifecycle
  tests. Review exact SQL before any separate deployment approval.

## Isolated QA execution update — 2026-11-02

- Read-only isolated inspection confirmed project `ckcxakhxqlkhppsxxjhv` is
  active PostgreSQL 17, with 82 migrations, zero Auth users/profiles/legal
  documents/legal role requirements/verification cases/applications/Guardian
  links/staff identities/staff memberships, and no Edge Functions or configured
  provider-result tables. The migration catalog differs from the reconciled
  production baseline: ten isolated-only migrations are present and
  `20261102113314_guardian_id_response_mask_production` is absent. This is not
  an exact production clone.
- The isolated school-domain registry has two active, verified entries; domain
  names were not exposed. No synthetic confirmed mailbox exists. MORT's
  school-email flow depends on a confirmed email domain; this does not satisfy
  school-ID verification.
- Guardian invitation signatures exist in isolated QA:
  `create_guardian_invite_v2(text)`, `accept_guardian_invite(text)`,
  `cancel_guardian_invite(uuid)`, and `resend_guardian_invite(uuid)`; all were
  observed as SECURITY DEFINER. The supported flow also requires the
  authenticated teen/adult onboarding, invite-code acceptance, and both
  `mort_set_guardian_consent(uuid,boolean)` actions. No link was created.
- No supported first-reviewer bootstrap path was found. Staff tables deny
  authenticated and `service_role` INSERT/UPDATE; no provisioning RPC exists;
  the staff audit RPC requires an already active staff membership. First
  reviewer assignment, training, AAL2 and scoped permissions require an
  authorized MORT operator and an approved owner-operated provisioning
  procedure. No staff identity was fabricated or inserted.
- Candidate provider sandbox docs were identified, not selected/configured:
  Yoti age/IDV sandbox, Persona test environments, Veriff test integration, and
  Google Workspace for Education test-domain option. Provider account approval,
  sandbox credentials, signature secrets, counsel-approved evidence policy,
  and confirmation that a provider supports school-ID evidence are still
  external prerequisites. No paid service or provider account was created.
- Ran `scripts/qa-guardian-id-rpc-privacy.mjs` against the isolated API using
  only its publishable key. Actual passes: anonymous
  `get_my_job_applications` denied (42501), anonymous nested status-update RPC
  denied (42501), and anonymous direct application read denied (42501). The
  authenticated role matrix was BLOCKED for missing application/Guardian IDs
  and six credential pairs; service-role preservation was BLOCKED because the
  isolated service-role secret was not configured. No positive Guardian ID or
  nested JSON assertion ran.
- Ran `scripts/qa-isolated-anonymous-safety-rpcs.mjs` against the isolated API.
  Actual passes (all 42501): anonymous denied for
  `get_my_job_applications`, `get_job_application_eligibility`,
  `update_my_job_application_status`, `mort_accept_job_application`,
  `schedule_active_job_checkin`, `complete_active_job_checkin`, and direct
  `job_applications` SELECT.
- Proposal 901 exact-source preflight against isolated QA: three of five
  guarded functions matched the proposal (`mort_review_verification_case`,
  `schedule_active_job_checkin`, `complete_active_job_checkin`); two did not
  (`get_job_application_eligibility`, `mort_accept_job_application`). Actual
  MD5s for eligibility and acceptance are
  `5b701599fe40c74a21e027aae102eea1` and
  `c53a5ecfc861bb6b6eb723ba2f465892`, while expected MD5s are
  `401d64ec19cf1fa1ab072709266fe4a7` and
  `a44e036f16579106d9ae615d2a54235f`. Do not apply proposal 901 there; its exact
  source guard is expected to reject these isolated-only schema differences.
  Proposals 900 and 902 were not applied; no SQL is needed for the anonymous
  API checks, and no authenticated fixtures exist.
- Repeatable prerequisite, supported-account sequence, exact harness inputs,
  concurrency matrix, external dependencies, and output are documented in
  `docs/MORT_ISOLATED_QA_PROVISIONING_2026-11-02.md`. Static/compile checks and
  local Docker PostgreSQL-17 tests are recorded separately above; they are not
  authenticated isolated API or workflow concurrency tests.
- Remaining actual test blockers: approved legal test versions; provider
  selection, sandbox credentials and evidence policy; authorized and trained
  first reviewer; confirmed synthetic mailboxes/accounts; authorized isolated
  job/application fixture procedure; and server-only isolated service-role
  secret. No QA role account or fixture was created, no proposal was applied,
  and production remained unchanged.

## Migration-drift and isolated-baseline update — 2026-11-02

- Full read-only comparison found 73 production ledger rows and 82 isolated
  rows. Seventy-two migration names are shared and their isolated IDs were
  restamped; 71 statement-payload SHA-256 values are identical. The shared
  `restrict_job_application_direct_select` SQL hash differs only by the
  isolated ledger payload's final newline (475 bytes vs 474); normalized
  executable statements are identical. The remaining ten isolated-only
  migrations, their exact versions/hashes, dependencies and effects are in
  `docs/MORT_SUPABASE_MIGRATION_DRIFT_2026-11-02.md`.
- Production-only migration `20261102113314_guardian_id_response_mask_production`
  (SHA-256 `96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa`)
  is absent in isolated QA. Two independent QA harmonization migrations were
  recorded at 11:23 UTC and modify the current reader's Guardian-ID / decision
  reason masks. The function contains stricter active Guardian/adult/confirmed
  email checks. Ledger timestamps support divergence before the production
  migration, but do not establish the operator reason. Do not synthesize a
  history row or replay the stale text replacement.
- Proposal source review across all five guards: verification review and both
  check-in RPCs match production; eligibility (`401d64ec19cf1fa1ab072709266fe4a7`
  vs isolated `5b701599fe40c74a21e027aae102eea1`) and acceptance
  (`a44e036f16579106d9ae615d2a54235f` vs isolated
  `c53a5ecfc861bb6b6eb723ba2f465892`) differ substantively. QA adds a
  verification-triplet helper / optional Guardian-preference gate and a
  Guardian decision-status requirement, respectively. These stem from the
  isolated-only verification and Guardian-decision migrations, not formatting.
  Keep the production guards unchanged; do not port QA Guardian decisions
  without policy approval.
- Current production and isolated catalogs both show RLS+FORCE RLS on
  `job_applications`, anon/authenticated SELECT denied, service_role SELECT
  allowed, no usable SELECT policy, and authenticated-only EXECUTE on the
  SECURITY DEFINER/empty-search-path scoped reader. The reader definition has
  applicant/current-link/dual-consent caller gates in both projects. Anonymous
  API denial tests again passed in isolated QA.
- Earlier local validation snapshot, superseded by the fresh PG17.11 replay
  below: container `supabase_db_mort-proposals-local-20261102`
  has PostgreSQL 17.6 and 73 migration rows through `20261102113314`, including
  the Guardian mask and direct-SELECT restriction. It is a clean SQL baseline
  on the same major, not the hosted 17.11 patch/runtime or a complete ACL clone.
  The direct-SELECT pgTAP test ran in a transaction and rolled back: 4/5 passed;
  service_role SELECT failed because this local baseline does not have the
  hosted ACL. Production and isolated ACLs both explicitly grant the same role
  table rights. Keep the test strict and fix local test bootstrap separately.
- Isolated QA currently has six Storage buckets and zero objects, in addition
  to the ten QA-only migrations; no Auth users, application data, or staff rows
  were present. Preserve it as-is. Reconciliation plan: retain this project as
  the QA-extension environment; use a separate disposable local clean baseline
  for production migrations; before any future QA DDL, snapshot DB/schema,
  Auth/config, bucket metadata and Storage bytes, then test in a new disposable
  branch/clone. If it fails, abandon that new clone and preserve the existing
  isolated project. No reset, migration-table edit, or DDL was done.

## 2026-11-02 — local ACL parity and production-contract review

### Production behavior and Proposal 901 scope

- Read-only production function hashes were rechecked immediately before local
  proposal validation: `mort_review_verification_case` MD5
  `9de9e53ea3e300b78819932eabc14594`; `get_job_application_eligibility`
  `401d64ec19cf1fa1ab072709266fe4a7`; `mort_accept_job_application`
  `a44e036f16579106d9ae615d2a54235f`; `schedule_active_job_checkin`
  `68ddb42187ef290145bda12d93a7b00b`; and
  `complete_active_job_checkin` `7a7b9ea9824a47e14e783b79aefac098`.
- Production eligibility checks an active teen, release control,
  open/safety-approved job, active poster, DOB/job age bounds, current age
  verification, duplicate active application, blocks, and a current dual-
  consent adult Guardian only when `jobs.requires_guardian_approval` is true.
  The RPC is called inside `submit_job_application` and again by the locked
  lower-level submit helper. It does not currently recheck teen school-ID or
  school-email verification, nor the poster's current identity verification.
- Production acceptance requires the job poster to be an active adult, a
  submitted/shortlisted application, no participant block, current adult
  identity verification, an active teen with current age verification and age
  inside the job bounds, and—only for jobs requiring it—a current active,
  dual-consented adult Guardian link whose Guardian account is active, adult,
  and email-confirmed. It creates the assignment, accepts one application,
  rejects other active applications, fills the job, and creates the
  conversation and participant membership in the same transaction. It does
  not currently recheck school-ID or school-email state and has no
  participant-pair lock.
- Production role approval requires current verified `age`, `school_id`, and
  `school_email` cases before activating a teen role; adult approval requires
  current `identity`. Those case types and `expires_at` columns exist in
  production. Because cases can expire or be revoked later, Proposal 901 now
  rechecks all three teen tracks at submission eligibility and acceptance,
  adult identity at acceptance, and the poster's identity before an
  application is treated as eligible. Poster failure uses the generic
  unavailable-job result.
- Guardian preference/optional-approval fields and Guardian application
  decision fields found only in isolated QA are not referenced. Production
  uses `jobs.requires_guardian_approval`, dual-consent fields on
  `guardian_links`, and `job_applications.guardian_id`; Guardian application
  views remain read-only. No Guardian decision state was added.
- Review found a same-job acceptance deadlock in the application-row → job-row
  order: one acceptance could hold application A and the job while another
  held application B waiting for the job; the winner then tried to reject B.
  Proposal 901 now takes a nonblocking per-job transaction advisory lock after
  locking the selected application and before waiting on the job row. A loser
  returns `job_acceptance_in_progress_retry`, releases its application lock,
  and can be retried. The deterministic participant-pair lock remains before
  the block check.
- Eligibility and acceptance lock current Guardian link/profile/auth rows in
  deterministic order before the teen profile, matching the link-before-
  profile order in unlink/consent revocation. Verification rows are locked
  before eligibility is evaluated against a fresh transaction clock.

### Proposal 900 and 902 review

- Proposal 900 remains fail-closed with an empty provider allowlist. Review
  found and fixed an uninitialized `v_now` in the minimum-age check, rejects
  non-future reviewer expiry, requires provider evidence received on/after the
  case's current submission, and records the selected provider-result ID/key
  in the same-transaction audit row. Provider event IDs remain unique; anon
  and authenticated receive no ledger access; service_role has SELECT/INSERT
  only. There is still no signed provider callback function or configured
  provider, so production verification remains unavailable. Cascade deletion
  of evidence metadata remains subject to approved retention/account-erasure
  policy.
- Proposal 902's function source hashes still match production. It uses only
  production assignment/job/application/check-in fields, adds nullable request
  metadata and a partial unique idempotency index, and preserves legacy rows.
  Schedule and completion lock assignment → job → check-in; completion's
  request-key advisory lock is acquired first. It rechecks active
  assignment/job/application state and preserves safe retries. The existing
  check-in workflow does not write an audit or notification event, and Proposal
  902 adds none; a new audit event requires a separate contract decision.
- All three proposals remain local proposal files, unapplied to production and
  hosted QA.

### Local ACL and test-environment parity evidence

- Production `information_schema.role_table_grants` reports seven table
  privileges—`SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER`—
  for service_role on `public.job_applications`, and no table grants to anon or
  authenticated. Added `scripts/qa-local-hosted-job-applications-acl.ps1`.
  It refuses any target except the named disposable local PostgreSQL
  container, requires 73 ledger versions from `20261026194801` through
  `20261102113314`, refuses existing anon/authenticated table or column
  privileges, grants the hosted service_role ACL, then verifies each of those
  privileges remains absent for anon/authenticated.
- The existing five-assertion pgTAP file was not changed. It passes 5/5 on
  the local base and again on the proposal-validation copy. ACL verification
  reports anon=false, authenticated=false, and service_role=true for table and
  column SELECT; local service_role table grants match all seven hosted
  privileges.
- **Correction to earlier environment reporting:** the local base has 73
  migration ledger rows, but its live catalog also contained unledgered empty
  Proposal 900 tables and Proposal 902 columns/index, plus proposal-edited
  function bodies. Earlier calling this a clean baseline was inaccurate. The
  original local container was not reset or cleaned; only the requested
  service_role ACL was changed there. A separate scratch database was created
  from a local dump, the known empty unledgered proposal artifacts were removed
  in that scratch only, and the five functions were restored from committed
  production migration source. All five hashes matched production before the
  drafts were applied. This reconstructs the known production contract for
  local SQL compilation, but is not a full fresh migration replay or exact
  managed Postgres 17.11 clone; the local scratch runs PostgreSQL 17.6.
- All three guarded proposals compiled/applied in the scratch database. The
  fixture-free negative authorization SQL block completed and rolled back;
  direct-SELECT pgTAP passed 5/5; the ledger remained 73; and scratch
  marketplace/document-collection flags were false. The two-session protocol
  script passed pair-lock serialization, check-in-key serialization, and the
  same-job acceptance fail-fast lock test (latest rerun: 609 ms). These test lock protocols,
  not authenticated RPC workflows.
- Static proposal review, 73-file migration recovery and both recovered
  production ledger hashes, migration encoding (240 files), and `git diff
  --check` passed. No Auth fixtures were created. Authenticated application,
  acceptance, revocation, and check-in RPC races remain blocked by the approved
  legal/provider/staff/synthetic-fixture prerequisites already documented.
- Earlier validation snapshot reported a hash failure for the historical
  Guardian migration. The final correction and root cause are recorded in the
  section below; the source SQL and expected Git blob hash were preserved.
- Read-only production release-control check still reports
  `public_marketplace_enabled=false`, `real_document_collection=false`, and
  `maintenance_mode=false`. No production or hosted-QA state changed.

## 2026-11-02 — final technical review and PostgreSQL 17.11 replay

### Historical hash root cause

- `git hash-object supabase/migrations/20260918032930_guardian_teen_summary_v1.sql`
  returns `65455e7593dbcb51612f71303ba808063b43f6a6`, equal to the expected
  Git blob SHA. The validator previously used the literal two-byte separator
  backslash + zero instead of Git's NUL byte, which yields the reported false
  hash `21eb6a0accd633b5fb92319b4062385a931899b6`. The validator now uses NUL;
  `node scripts/qa-migration-reconciliation-parity.mjs` passes. This
  September legacy migration has no row in the active production 73-version
  ledger; the local Git hash validation is separate from the active production
  migration baseline. Neither the historical migration nor expected hash
  changed.

### Proposal 900 findings

- Caller must be authenticated and hold the current admin/moderator staff
  role. The reviewer locks subject profile -> provider allowlist -> case ->
  result, compares the case snapshot after locking, and writes decision plus
  audit in one transaction. A failed audit insert rolls back the decision.
  `verification_provider_allowlist` remains empty; service_role alone can
  read/insert the result ledger, with no client grants.
- Evidence must match case ID, user, verification type, provider key and
  provider reference; result must be `verified`, generated and received no
  earlier than the case submission, not future-dated, and not expired. Review
  also bounds its expiry by provider evidence expiry. Proposal SQL now rejects
  `verified_at` earlier than the current case submission.
- Signature verification, tenant binding, replay/order handling, event-time
  semantics and case-bound provider reference are external adapter
  requirements, not implemented in the SQL proposal. Keep the provider
  allowlist empty and do not claim verification is operational until those
  controls and provider sandbox tests pass.

### Proposal 901 findings

- The fresh production migration replay matched all live hashes before
  proposal compilation: reviewer `9de9e53ea3e300b78819932eabc14594`,
  eligibility `401d64ec19cf1fa1ab072709266fe4a7`, acceptance
  `a44e036f16579106d9ae615d2a54235f`, schedule
  `68ddb42187ef290145bda12d93a7b00b`, completion
  `7a7b9ea9824a47e14e783b79aefac098`.
- Eligibility rechecks current teen age and all existing production
  school-ID/school-email tracks; current poster identity; active accounts,
  job state, release flag, blocks, and the actual Guardian contract.
  Acceptance rechecks current adult identity and teen age/school state, locks
  the application/job and shared participant pair, and rechecks active dual
  Guardian consent only where `requires_guardian_approval` is true. QA-only
  Guardian preference/decision fields are absent.
- Competing same-job accepts fail fast using a nonblocking transaction lock,
  avoiding the prior application-row/job-row cycle. The retry exception is
  propagated through the existing status RPC. The Flutter caller's RPC shape
  is unchanged, but it currently has no specific message/automatic retry for
  `job_acceptance_in_progress_retry`; add client compatibility coverage.
- Row locks prevent concurrent updates to existing verification rows from
  changing status during the decision. Absent rows cannot be predicate-locked;
  later READ COMMITTED checks can see a newly created row. Runtime concurrency
  is still unverified.

### Proposal 902 findings

- Nullable request metadata/unique partial index are additive and legacy
  completed rows remain readable. Lifecycle locks are assignment -> job ->
  check-in; completion serializes a request key first. No audit/notification
  behavior is silently added to a workflow that had neither.
- Fixed a discovered idempotency defect: for newly completed rows, a different
  completion request ID previously fell through the legacy success branch.
  It now returns `idempotency_key_reused`. Legacy success without payload
  proof remains only when the old row has no stored completion request ID.
- Schedule retry lookup is serialized and now happens before active
  assignment/job checks. The recommendation is to replay the original stored
  result only when the authenticated teen, application, request ID and
  interval match exactly, including after terminal job state. A new key after
  termination remains `active_assignment_required`; changed app/interval under
  an existing key is `idempotency_key_reused`. Legacy rows without interval
  metadata fail with `idempotency_result_unverifiable` because the stored
  request payload cannot be proven identical.
- Flutter's safety repository generates a fresh UUID by default; the current
  screen does not retain a request ID across retry. Consequently a network
  timeout followed by another tap is a new request, not an idempotent retry.
  Proposal 902 does not silently change client behavior. A separate client
  change must persist the intent UUID and map `idempotency_key_reused` to a
  clear refresh/reconcile action. Completed check-in rows replay only a
  matching stored request ID; the legacy no-ID row response remains marked
  unverified.

### Local PostgreSQL 17.11 evidence and limitations

- A new PostgreSQL 17.11 (`server_version_num=170011`) container replayed all
  73 `supabase-production/migrations` byte-for-byte in order. The runner stores
  each source SHA in a local-only provenance ledger; result:
  `FRESH_PRODUCTION_BASELINE_REPLAY=PASS
  73|20261026194801|20261102113314|73 PostgreSQL=170011 source_bytes=exact`.
- The Supabase image's empty `auth.users` lacks `email_confirmed_at`, and
  `storage` is owned by `supabase_admin`; test-only bootstrap added that empty
  Auth column and allowed local `postgres` to create minimal `storage.buckets`,
  `storage.objects`, and `storage.foldername` objects used by these migrations.
  No users, objects, or production data were copied. This is not a full hosted
  Supabase Auth/Storage clone.
- All three proposals compiled/applied locally from the clean baseline. The
  unchanged direct-SELECT privacy test passed 5/5 after applying a guarded
  local ACL script. It verified anon/authenticated table and column SELECT
  false and service_role SELECT true. The earlier fixture-free pgTAP run passed
  19/19; the final recheck below expanded it to 23/23. These tests inspect
  source predicates and no-claim denials, not stateful authenticated
  transitions.
- The two-session lock-protocol harness passed on PostgreSQL 17.11: pair lock
  2.396s, check-in request lock 2.370s, same-job fail-fast 0.831s. This
  confirms lock-key serialization only; it does not invoke application RPCs or
  prove row-lock/callback race outcomes.
- The historical migration `20261028031921_mort_public_marketplace_activation`
  sets the replayed local control true. A local-only safety override set
  `public_marketplace_enabled=false` and `real_document_collection=false`
  before proposal validation; the provider allowlist remains empty. Production
  controls were read-only and untouched.
- Authenticated/positive workflow tests, stateful expiry/revocation/retry
  tests, actual two-session application/acceptance/block races, and authenticated
  RLS remain blocked until the approved legal docs, provider sandbox,
  authorized staff reviewer and supported synthetic-account fixtures exist.
  The exact remaining prerequisites are in `docs/MORT-2.0-EXECUTION-CHECKLIST.md`.

- The earlier note that the hash reconciliation still failed and the earlier
  claim that PostgreSQL 17.6 was the best available baseline are superseded by
  this evidence. The older 17.6 scratch containers were not used for the final
  replay; only the byte-exact fresh PG17.11 run counts.
- A read-only catalog comparison of the previous PostgreSQL 17.6.1.140
  container and the fresh 17.11.0.006 container found the sampled Auth
  `email_confirmed_at` column, Storage buckets/objects, `storage` schema owner
  (`supabase_admin`), and post-bootstrap application-table SELECT privileges
  equal. The 17.11 replay started from a clean database and needed the documented
  test-only Auth/Storage bootstrap. This is a bounded catalog comparison, not a
  comprehensive Supabase platform comparison. No disposable managed 17.11
  project was available without creating or paying for a hosted resource.
- The earlier ACL bootstrap used
  `mort-pg1711-baseline6-mort20261102`; the final rerun below uses a separately
  replayed clean container. ACL and two-session harnesses refuse the older
  non-parity container. Both runs verify anon=false, authenticated=false,
  service_role=true for both table and column SELECT.
- Production project `jxbnrkasktbhtiujkhay` and hosted QA were not modified.

## 2026-11-02 — final migration and proposal recheck

### Migration history conclusion

The current read-only Supabase `list_migrations` response and direct query of
`supabase_migrations.schema_migrations` agree on **73** applied production
rows, ordered from `20261026194801` to `20261102113314`. Version
`20261102113314` is present under the exact name
`guardian_id_response_mask_production`; it is not an alias under another
version. The one recorded statement is 1,598 bytes with SHA-256
`96ad143a1c066d3496ca492774c810a9bc196e629f2c7fa2bf908459c4392efa`, matching
the recovered SQL and manifest. The manifest and production API have **zero**
ordered version/name mismatches. The earlier no-row report cannot be
reproduced; its exact query was not preserved, so its false-negative mechanism
is unknown. The production baseline remains 73, with this migration correctly
classified as applied. No migration repair or SQL write was performed.

The separate historical Git hash mismatch concerned the legacy root migration
`20260918032930_guardian_teen_summary_v1.sql`, outside the active production
73-version set. Its expected Git blob hash is correct; only the validator's
NUL-byte encoding was wrong and has already been corrected.

### Final proposal review and severity

| Severity | Finding / exploitability | State and next control |
| --- | --- | --- |
| High, conditional launch gate | Enabling a verification provider without a signed, tenant-bound, replay-safe callback could admit forged, stale, or misbound evidence. This path is not active while the allowlist is empty. | Keep allowlist empty. Require raw-body signature verification, event ID deduplication, timestamp/replay-window checks, provider-account binding, immutable case/session binding, audit and provider sandbox tests before enabling. |
| Medium, client reliability | Flutter creates a new check-in request UUID on each repository call and current screens do not retain one for timeout retries. A second schedule tap can create a separate schedule; a completion retry can conflict with the first stored ID. | Backend exact-key replay is proposed; client intent-ID persistence and a specific `idempotency_key_reused` message remain a separate code change. No current Flutter behavior was changed. |
| Medium, user recovery | Proposal 901 can return `job_acceptance_in_progress_retry`; Flutter has no dedicated retry message or automatic retry. | Surface a recoverable status and refresh/retry with a fresh expected application version before deployment. No application is accepted on this transient denial. |
| Low, legacy compatibility | Old scheduled check-in rows do not store the requested interval, so payload equivalence cannot be proven. Old completed rows do not store a completion request ID. | Schedule returns `idempotency_result_unverifiable` for legacy rows; completed legacy check-ins preserve read-only no-op success with `payload_verified=false`. New rows enforce exact payload/request matching. |
| No reportable defect established | No deadlock cycle was found in the static order among the three proposals, and transaction-local decision/audit and check-in writes roll back atomically. Actual cross-RPC row-lock races remain untested. | Keep authenticated concurrency and audit/notification integration as release gates; do not infer runtime correctness from advisory-key tests. |

### Proposal details

- Proposal 900 requires an active authorized staff reviewer; takes locks in
  subject profile -> provider allowlist -> case -> evidence order; rechecks the
  case snapshot; matches case/user/type/provider/reference; requires a verified
  result generated and received on/after current case submission, not in the
  future or expired; bounds review expiry by evidence expiry; and commits the
  case decision with audit atomically. Its provider allowlist remains empty.
  The evidence predicate now rejects stale `verified_at` timestamps. Signature,
  tenant, replay and provider event-time verification still belong to an
  approved trusted adapter and remain unimplemented.
- Proposal 901 still matches production signatures and uses production fields.
  It preserves teen age, school ID/email and adult identity checks, shared
  participant-pair locking, and current Guardian dual consent only when the
  production job requires Guardian approval. Proposal 901 adds no Guardian
  decision rights. Authorization denial and the transient retry response
  preserve the existing RPC shapes; the Flutter UI needs a dedicated retry
  experience. Pair-lock and same-job advisory-key order show no static
  deadlock cycle, but actual two-session RPC races are not verified.
- Proposal 902 now serializes schedule requests by teen/request ID, checks an
  existing request before lifecycle gates, and replays only when caller,
  application and stored interval match. New/mismatched requests remain
  fail-closed. Completion returns a stored result only for matching request ID
  on new rows and rejects key reuse; its row-lock order remains
  assignment -> job -> check-in after request-key serialization. No audit or
  notification path is added where the current lifecycle has none.

### Tests for this recheck

- Fresh local Supabase PostgreSQL `17.11.0.006` (`170011`) replay: 73/73 source
  files, exact order and exact per-file source bytes; no Auth or profile rows.
- All three full proposal files compiled against that clean baseline before
  revisions. Revised Proposal 900 reviewer and Proposal 902 schedule function
  bodies were then compiled inside a transaction, fixture-free pgTAP passed
  **23/23**, and pre/post function hashes matched after transaction rollback.
- Direct application SELECT privacy pgTAP: **5/5**. ACL evidence confirms
  anon/authenticated have no table or column SELECT and service_role retains
  both. Static proposal, migration recovery, parity, 240-file encoding,
  JavaScript syntax, and `git diff --check` passed.
- Two-session advisory-lock protocol: **3/3** (participant pair 2.395s,
  check-in request key 2.396s, same-job acceptance fail-fast 0.872s). These do
  not call application or check-in RPCs with authenticated users and are not
  workflow race tests.

Authenticated expiry/revocation state changes, Guardian unlink/consent races,
duplicate acceptance, schedule/completion row-backed retries, provider
callbacks and RLS role matrix remain unverified. Approved legal terms, provider
sandbox credentials, an authorized staff reviewer, supported synthetic
accounts/fixtures and isolated authenticated credentials are still required.
No fabricated identity, evidence, legal acceptance, Guardian relationship or
staff identity was used.

Production `jxbnrkasktbhtiujkhay` and hosted QA remained read-only. No production
migration, data, Auth, RLS, provider, release-control, payment, marketplace,
document-collection, or AI setting changed.
