# Production backend proposals — NOT APPLIED

These files are review candidates only. They are deliberately stored outside `../migrations/` and must not be moved into the applied chain until the remaining authenticated workflow tests pass in a legitimate isolated environment and the exact change set receives production review.

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

## Provider evidence contract before enabling any provider

The `private.verification_provider_allowlist` is empty. Before enabling an entry, the chosen provider must have a reviewed server-to-server adapter that:

1. Verifies the provider's signature over the exact raw request bytes using documented key rotation, and rejects bad signatures, stale/future event timestamps and wrong environment/account identifiers.
2. Binds each provider session/reference to one MORT verification case, MORT user, verification type and provider tenant before any callback can create a result. Email or client-supplied IDs alone are not sufficient identity binding.
3. Deduplicates the provider's immutable event ID. An exact duplicate is an idempotent no-op; a reused event ID with different subject, case, type, result or payload digest is rejected and audited.
4. Records server receipt time separately from provider event/verification time. Verified results must be generated and received no earlier than the current case submission, must not be future-dated or expired, and must retain an auditable provider result/reference. Expiry cannot exceed the provider's verified evidence expiry.
5. Stores only minimized result metadata and a digest, never raw identity/school documents in this proposal. Retention, appeal, rejection and deletion behavior need legal/privacy approval before document collection or a provider is enabled.

Required provider sandbox tests include forged/rotated signatures, replayed and reordered events, stale/future timestamps, wrong tenant, wrong case/user/type/reference, duplicate event IDs with matching and conflicting payloads, expired evidence, case resubmission/stale snapshots, disabled allowlist, and atomic decision/audit rollback. No provider has been approved or configured; provider-backed positive tests remain blocked.

## Proposal 901 client contract

Production schema and source hashes match the five current guards. Guardian dual consent is required only when `jobs.requires_guardian_approval` is true; the proposal does not import QA-only Guardian decision/preferences. Acceptance's transient `job_acceptance_in_progress_retry` returns a retryable denial without accepting or assigning the application. The existing Flutter RPC signature is unchanged, but the client currently has no dedicated message/automatic retry for that code. Add compatibility coverage and a user-visible retry path before rollout; no Flutter behavior was silently changed here.

## Proposal 902 retry contract and current Flutter behavior

The backend recommendation is to replay a previously committed operation only for the same authenticated teen and exact request identity/payload, including after terminal lifecycle, while rejecting a new key after termination and a reused key with changed payload. Completion already follows that rule for rows storing a request ID; pre-migration completed rows retain `payload_verified=false` legacy success.

Flutter's safety repository defaults to a new UUID on every call. The current safety screen does not retain/pass a request ID for a retry, and `userFacingError` has no specific `idempotency_key_reused` message. Thus the existing Flutter UI cannot reliably retry an ambiguous network timeout with the original key; a new tap is a new request. Before claiming client idempotency, a separate client change must retain one request UUID per user intent until response/reconciliation. This proposal does not change that existing client behavior.

The local direct-SELECT pgTAP setup is `../../scripts/qa-local-hosted-job-applications-acl.ps1`. It restores the hosted `service_role` table ACL on the disposable local container only; the strict five-assertion pgTAP file remains unchanged, and the script verifies anon/authenticated receive no table or column privileges.

`../../scripts/qa-guardian-id-rpc-privacy.mjs` is an API-level regression harness for synthetic isolated accounts. It requires test-only credentials and fixture IDs through environment variables and refuses production or deleted-project URLs. On 2026-11-02 its anonymous checks passed against `ckcxakhxqlkhppsxxjhv`, while authenticated role and service-role checks were blocked by missing accounts, fixtures, and isolated service-role credentials. The repeatable prerequisite and provisioning runbook is `../../docs/MORT_ISOLATED_QA_PROVISIONING_2026-11-02.md`. The isolated project has 82 migrations and is not an exact production clone; proposal 901 source guards do not match its eligibility and acceptance functions. Do not apply source-bound proposals to this project without a reviewed, exact schema baseline. Production's current RPC response already masks Guardian IDs, and direct application-table access is restricted by the reconciled production migration; this does not replace the outstanding authenticated isolated API regression test.
