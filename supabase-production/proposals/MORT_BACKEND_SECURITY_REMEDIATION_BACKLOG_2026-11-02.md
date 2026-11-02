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
- **Narrow proposal:** Add nullable requested-interval and completion-request fields (preserving existing rows), a bounded interval check, and a partial unique index for completion request IDs. Lock assignment then job then check-in (matching safety-cancellation's assignment/application/job order), require assignment `accepted|in_progress` and job `filled|in_progress`, and recheck participant/application/job relationships. Bind schedule retries to the original application and interval; conflict on a different application or a known different interval, while preserving safe legacy retries whose interval was never stored. Bind completion retries to the request ID, make only a `scheduled`→`completed` transition, and fail closed after cancellation/closure.
- **Compatibility refinement:** A legacy schedule retry for the same application now returns the original successful check-in with `payload_verified=false` when its old interval was never stored; a different application still conflicts. Authorized retries against already-completed legacy check-ins remain successful no-ops with `payload_verified=false`; request IDs already bound to another check-in still conflict. This preserves the previous success contract without claiming unverifiable payload equality.
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
- Local clean baseline container `supabase_db_mort-proposals-local-20261102`
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
