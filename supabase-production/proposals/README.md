# Production backend proposals — NOT APPLIED

These files are review candidates only. They are deliberately stored outside `../migrations/` and must not be moved into the applied chain until the remaining authenticated workflow tests pass in a legitimate isolated environment and the exact change set receives production review.

## Final independent review finding

Proposal 901 preserves a narrow pre-authorization lock window in
`mort_accept_job_application`: an active authenticated adult can call the
granted RPC with another user's application ID, acquire its application-row
`FOR UPDATE` lock, then fail the poster check after the job lookup. This does
not return the application data and mirrors the existing production contract,
but it permits short-lived lock contention/denial-of-service attempts. Before
production application, consider an unlocked owner-scoped application/job
preflight followed by the existing app → per-job → job → participant-pair lock
sequence and a final ownership recheck. Add a two-session test proving an
unrelated adult cannot hold/block the target application lock. This review did
not alter Proposal 901 or claim the concern is runtime-tested.

The distance-band, safety-report moderation, and Guardian application-decision proposals were copied from `codex/mort-backend-guardian-moderation-20261101`. They have not been applied to production. The Guardian visibility proposal needs the additional direct-table privilege protection in `20261102010500_restrict_job_application_direct_select.sql`: row-level policies do not hide individual columns, and the current table-level SELECT grant otherwise exposes `guardian_id` to posters of visible applications.

Do not run these SQL files in production from the Supabase SQL editor or CLI.

## Guardian identifier response mask — stale proposal

`20261102080000_guardian_id_response_mask.sql` is stale and must not be applied. The latest read-only production inspection found that `public.get_my_job_applications(uuid)` already masks the Guardian ID and the old unmasked replacement anchor occurs zero times. Applying this file should fail its exact-source assertion. This agent made no production change.

The isolated API role matrix remains separately blocked by missing supported onboarding, legal versions, verification provider, staff authorization, and synthetic application fixtures. Current source inspection does not replace that runtime coverage.

## Current focused security proposals

- `20261102090000_verification_evidence_gate.sql`: provider-backed, case-type-matched verification evidence gate. It seeds no providers and keeps verification fail-closed until a reviewed provider integration exists. It requires provider evidence to be generated and received on or after the current case submission/creation time, not in the future, not expired, and bound to the current case ID, subject, verification type, provider and provider reference.
- `20261102090100_application_pair_lock_and_verification.sql`: current teen age, school-ID, and school-email checks at eligibility and acceptance; current adult identity checks at acceptance; poster identity before an application is eligible; participant-pair serialization; Guardian link/profile locks ordered before the teen profile; and a fail-fast per-job acceptance lock for competing accepts. Uses only production columns and existing `jobs.requires_guardian_approval` / dual-consent workflows; does not introduce QA-only Guardian preferences or Guardian decision fields.
- `20261102090200_checkin_idempotency_lifecycle.sql`: payload-bound schedule retry keys, completion request binding, assignment/job lifecycle checks and fixed lock order. An exact previously committed schedule request replays its stored response for the same teen, application, request ID and interval even after the job becomes terminal. A new request ID after termination still fails `active_assignment_required`; changing the application or interval under an existing key fails `idempotency_key_reused`. Legacy rows without the stored interval fail with `idempotency_result_unverifiable` because payload equivalence cannot be established; the client must refresh/reconcile rather than treat it as a confirmed replay.
- `MORT_BACKEND_SECURITY_REMEDIATION_BACKLOG_2026-11-02.md`: severity, exploitability, precise behavior, remediation, regression tests and prerequisites for each priority.

These files are guarded proposals, not deployed production behavior. Their source-hash guards bind to production definitions inspected read-only; all five signatures matched their current production MD5s on 2026-11-02. All three proposals compiled on a fresh, local PostgreSQL 17.11 replay of the 73 production migration files. The revised Proposal 900 review function and Proposal 902 schedule function were separately compiled inside a rollback-only transaction; fixture-free pgTAP passed 23/23 and both function definitions were verified unchanged after rollback. The unchanged direct-SELECT privacy pgTAP passed 5/5. The two-session harness passed lock-key serialization checks only, not authenticated RPC workflows. Local PG17.11 is not a managed Supabase clone. Do not apply the proposals to production or the divergent hosted QA project.

## Controlled implementation order and rollback

The three files have independent production source guards and no direct DDL dependency on one another. Recommended staging order is:

1. `20261102090000_verification_evidence_gate.sql` — install the evidence ledger and reviewer gate. Keep `private.verification_provider_allowlist` empty. Provider positive verification remains unavailable until an independently reviewed signed adapter and provider sandbox evidence exist.
2. `20261102090100_application_pair_lock_and_verification.sql` — install current eligibility/acceptance verification checks and participant-pair serialization. Guardian dual consent remains conditional on `jobs.requires_guardian_approval`.
3. `20261102090200_checkin_idempotency_lifecycle.sql` — add nullable idempotency metadata and replace schedule/completion RPC bodies.

Before each file, verify the production migration baseline still has all 73 expected versions and check that file's exact source-hash guards against the current live function definitions. Apply each file as a separate reviewed transaction and stop immediately on a guard failure. Deploy the compatible Flutter client before or in a coordinated release with Proposal 902 so ambiguous network retries reuse persisted request IDs, and so `job_acceptance_in_progress_retry`, `idempotency_key_reused`, and `idempotency_result_unverifiable` lead users to refresh/retry safely. Existing RPC signatures remain unchanged. The Flutter changes in this branch are local code only and are not deployed.

Each proposal wraps its own changes in a transaction; a SQL error before commit rolls that file back. If a later file fails, earlier committed files remain applied. Do not run a partially applied file again after its function source has changed. A reviewed rollback would restore the captured pre-proposal function definitions in reverse order (902, 901, then 900) while retaining additive columns, indexes, provider evidence, audit rows and other stored data. Do not drop tables/columns/indexes, delete evidence/audit rows, or reverse migration-ledger entries as part of rollback. No executable reverse migrations are prepared yet. Neither apply nor rollback is authorized by this proposal review.

## Provider evidence contract before enabling any provider

The `private.verification_provider_allowlist` is empty. Before enabling an entry, the chosen provider must have a reviewed server-to-server adapter that:

1. Verifies the provider's signature over the exact raw request bytes using documented key rotation, and rejects bad signatures, stale/future event timestamps and wrong environment/account identifiers.
2. Binds each provider session/reference to one MORT verification case, MORT user, verification type and provider tenant before any callback can create a result. Email or client-supplied IDs alone are not sufficient identity binding.
3. Deduplicates the provider's immutable event ID. An exact duplicate is an idempotent no-op; a reused event ID with different subject, case, type, result or payload digest is rejected and audited.
4. Records server receipt time separately from provider event/verification time. Verified results must be generated and received no earlier than the current case submission, must not be future-dated or expired, and must retain an auditable provider result/reference. Expiry cannot exceed the provider's verified evidence expiry.
5. Stores only minimized result metadata and a digest, never raw identity/school documents in this proposal. Retention, appeal, rejection and deletion behavior need legal/privacy approval before document collection or a provider is enabled.

Required provider sandbox tests include forged/rotated signatures, replayed and reordered events, stale/future timestamps, wrong tenant, wrong case/user/type/reference, duplicate event IDs with matching and conflicting payloads, expired evidence, case resubmission/stale snapshots, disabled allowlist, and atomic decision/audit rollback. No provider has been approved or configured; provider-backed positive tests remain blocked.

## Proposal 901 client contract

Production schema and source hashes match the five current guards. Guardian dual consent is required only when `jobs.requires_guardian_approval` is true; the proposal does not import QA-only Guardian decision/preferences. Acceptance's transient `job_acceptance_in_progress_retry` returns a retryable denial without accepting or assigning the application. The existing Flutter RPC signature is unchanged. The current local client maps that code to a refresh-and-retry message; it does not retry automatically. This change is not deployed.

## Proposal 902 retry contract and current Flutter behavior

The backend recommendation is to replay a previously committed operation only for the same authenticated teen and exact request identity/payload, including after terminal lifecycle, while rejecting a new key after termination and a reused key with changed payload. Completion already follows that rule for rows storing a request ID; pre-migration completed rows retain `payload_verified=false` legacy success.

Flutter's safety repository now uses a secure local request coordinator for schedule and completion. It persists the request ID and canonical payload before sending, reuses them after a timeout or process restart, rejects a changed payload while the prior result is uncertain, and clears the record only after explicit success or a definitive `{ok:false}` response. A later user action then receives a new ID. Concurrent duplicate calls share one process-wide in-flight future across repository/coordinator instances, matching the process-wide secure-storage intent. Secure-storage read/write failures prevent the RPC from being sent. The screen distinguishes a replayed success and maps retry/stale/authorization responses to safe refresh guidance. These code changes are not deployed, and no authenticated live RPC was called.

Before the final cross-instance coalescing fix, the Flutter suite passed **629 tests, 2 skipped, 0 failed**. After that fix, the full suite passed **632 tests, 2 skipped, 0 failed**; targeted `dart analyze` reported no issues. Fixture-free client tests prove request persistence/coalescing and response handling, not authenticated Supabase workflows. On a new disposable local PostgreSQL 17.11 replay of all 73 migrations, all five proposal source hashes matched, proposals 900–902 compiled, rollback-only fixture-free pgTAP passed 23/23, and direct-SELECT privacy pgTAP passed 5/5. No authenticated provider/role/RLS or workflow concurrency integration test was run.

## External prerequisites and work that can proceed locally

Counsel must approve isolated synthetic-account legal terms and any age, identity, school-data retention, appeal and deletion policy. The verification provider must supply an approved sandbox, credentials, signed callbacks, documented event timestamps/IDs, tenant binding, and evidence expiry semantics; no provider is selected and none is enabled. MORT operations must authorize and train a human first reviewer with scoped staff membership, MFA/AAL2 and audit access. QA operations must provision synthetic applicant, poster, linked/consenting Guardian, revoked Guardian, unrelated user and administrator through supported onboarding, plus legal/versioned consent and job/check-in fixtures; isolated anon and service-role keys must be placed in a secret store.

Without those prerequisites, local Flutter unit/widget tests, analyzer, static source/ACL checks, clean-baseline SQL compilation, no-claim negative tests, migration/hash checks and rollback-only pgTAP remain available. Provider-positive, authenticated role-matrix, row-backed lifecycle and real two-session RPC race tests remain blocked and must not be represented as passed.

The local direct-SELECT pgTAP setup is `../../scripts/qa-local-hosted-job-applications-acl.ps1`. It restores the hosted `service_role` table ACL on the disposable local container only; the strict five-assertion pgTAP file remains unchanged, and the script verifies anon/authenticated receive no table or column privileges.

`../../scripts/qa-guardian-id-rpc-privacy.mjs` is an API-level regression harness for synthetic isolated accounts. It requires test-only credentials and fixture IDs through environment variables and refuses production or deleted-project URLs. On 2026-11-02 its anonymous checks passed against `ckcxakhxqlkhppsxxjhv`, while authenticated role and service-role checks were blocked by missing accounts, fixtures, and isolated service-role credentials. The repeatable prerequisite and provisioning runbook is `../../docs/MORT_ISOLATED_QA_PROVISIONING_2026-11-02.md`. The isolated project has 82 migrations and is not an exact production clone; proposal 901 source guards do not match its eligibility and acceptance functions. Do not apply source-bound proposals to this project without a reviewed, exact schema baseline. Production's current RPC response already masks Guardian IDs, and direct application-table access is restricted by the reconciled production migration; this does not replace the outstanding authenticated isolated API regression test.

## 2026-11-02 mobile client recheck

The Flutter retry implementation was independently reviewed starting from
commit `78c1d237003a8578d2f065c5ab1ebd5dd148ec6`. Two additional regressions now
cover changed-payload calls during an in-flight request and secure-storage
cleanup failure after a successful server response. The latter must retain the
pending key so a later attempt can replay the same logical operation. Focused
retry tests passed 14/14; the full Flutter suite passed 634, skipped 2, failed
0; analyzer and formatting passed. These are client-side tests, not Supabase
authenticated integration evidence.

The guarded signed closed-test AAB build was not produced. Its read-only server
gate observed `production_public` while the build profile requests
`closed_test`; the authoritative service also reported public marketplace and
real document collection false. The build was stopped without changing release
controls. Reconcile the release mode under the approved release process before
building. The local upload certificate identity checks succeeded before that
gate; no artifact/signature verification can be claimed.
