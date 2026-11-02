# MORT backend security remediation backlog — 2026-11-02

Scope is the current production source observed read-only on `jxbnrkasktbhtiujkhay` and its checked-in production migrations. This is a proposal backlog. Nothing here was applied to production. SQL drafts are under `supabase-production/proposals/`, outside Supabase CLI's migration directory.

## Priority 0 — verification approval must be backed by evidence

- **Severity / exploitability:** Critical safety-integrity issue; medium exploitability. Only an authorized admin/moderator can call the RPC, but a compromised, mistaken, or malicious reviewer can currently set any existing verification case to `verified` without a matching provider result or evidence. The current minimum-age check does not establish identity, school enrollment, or independent age evidence.
- **Affected:** `public.mort_review_verification_case(uuid,mort_verification_status,text,timestamptz)`, `public.verification_cases`, `public.profiles`, `public.admin_audit_log`; age, identity, school ID/email, business verification and role activation.
- **Unsafe behavior:** The live RPC accepts `verified`, checks only that DOB exists and age is at least 13, then changes status and writes an audit row. It does not require `provider`, `provider_reference`, `evidence_path`, a signed provider result, a case-type match, or evidence provenance.
- **Narrow proposal:** Add a private provider-result ledger keyed to the existing case and subject, restricted to trusted server-side inserts. The reviewer may approve only when a current, successful, case-type-matched result exists and its provider/reference match the case. No manual override is proposed. An empty provider allowlist keeps verification fail-closed until a provider is selected, approved, integrated, and its webhook signature validation is deployed. Retain the existing minimum-age check and audit trail.
- **Regression tests:** unauthenticated/nonstaff denied; staff can reject/mark needs-review without provider evidence; staff cannot verify missing/mismatched/rejected/expired/wrong-type/untrusted evidence; cannot verify under-13 or missing-DOB user; can verify only with matching current successful evidence; replayed provider event is unique; reviewer and evidence attempts are audited; provider result/document details never appear in public reads.
- **Prerequisites:** Provider selection, contract and sandbox credentials; counsel/product approval of accepted evidence per verification type; secure provider callback deployment and signing-secret provisioning. No production documents or real identity data may be collected before those gates pass.

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
- **Narrow proposal:** Add nullable requested-interval and completion-request fields (preserving existing rows), a bounded interval check, and a partial unique index for completion request IDs. Lock assignment then job then check-in (matching safety-cancellation's assignment/application/job order), require assignment `accepted|in_progress` and job `filled|in_progress`, and recheck participant/application/job relationships. Bind schedule retries to the original application and interval; return an idempotency conflict for key reuse with a different payload or legacy rows whose payload cannot be verified. Bind completion retries to the request ID, make only a `scheduled`→`completed` transition, and fail closed after cancellation/closure.
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
- Read-only production migration catalog reports 73 applied versions through
  `20261102113314`; the local production workdir has 72 SQL files and its
  checked-in export manifest records 71. The disposable local replay therefore
  is not a complete hosted-history clone: it is missing hosted version
  `20261102113314_guardian_id_response_mask_production`, while the manifest
  omits the already-present local/hosted
  `20261102040639_restrict_job_application_direct_select`. Reconcile and export
  the missing hosted version before claiming full migration parity.
- The five target RPCs' source hashes matched between current production and
  the 72-file local replay. All three proposal SQL files then compiled and
  committed against that disposable local PostgreSQL 17 database.
- Fixture-free local negative tests passed for anonymous/no-claim rejection,
  anon EXECUTE denial, SECURITY DEFINER/empty-search-path preservation, private
  evidence-table RLS and grants, and an empty provider allowlist. The test ran
  inside a transaction and rolled back.
- The production runtime status was read-only verified as marketplace closed,
  new publishing disabled, payments disabled, real document collection false,
  and AI provider disabled. The proposals do not write release-control rows.
- No production migration or the stale Guardian-ID response-mask proposal was applied.
- No changes to marketplace, publishing, payments, document collection, or AI controls are proposed.
- SQL proposals compile locally, but they have not passed positive authorization,
  provider-evidence, RLS, or two-session behavioral tests. Do not run them against
  production; exact-source guards intentionally stop if the inspected
  definitions have changed.
- The full isolated Guardian role matrix remains blocked: no approved legal
  versions, provider sandbox/submissions, authorized first-reviewer/staff
  membership, synthetic accounts/application/Guardian relationship, or
  server-only QA service-role credential is provisioned. No such data was
  fabricated.
- Required next actions: reconcile/export the 73rd hosted migration; choose and
  approve age, identity and school evidence providers/policies; publish
  counsel-approved test legal versions in isolated QA; provision an authorized
  reviewer with training; create six synthetic accounts through Auth and the
  supported onboarding/Guardian flows; issue a synthetic application through
  a reviewed isolated-only fixture path without enabling production gates; then
  run provider evidence, applicant/poster/Guardian/admin privacy and nested
  response tests plus real two-session block/accept and check-in lifecycle
  tests. Review exact SQL before any separate deployment approval.
