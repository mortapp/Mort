# MORT P — Production Architecture Blueprint

**Status:** Architecture specification for Codex implementation  
**Production Supabase project:** `mort p`  
**Supabase project ref:** `jxbnrkasktbhtiujkhay`  
**Region:** `us-east-2` (US East, Ohio)  
**Application repository:** `mortapp/Mort`  
**Decision:** This is the production architecture. Do not treat it as a closed-testing or staging deployment.

## 1. Mission and implementation boundary

Build MORT as a production-grade, teen-safe local work marketplace for teens ages 13–17 and adults/businesses posting suitable local jobs. Keep the existing Flutter application and repository as the source of truth for app behavior; use Supabase as the authoritative backend for authentication, relational data, authorization, private files, and server-side operations.

This document is the architectural source of truth for the new Supabase project. Codex must inspect the current repository and its verified features before implementing, preserve useful existing app behavior, and avoid blindly copying old database state or applying old migrations without review. Do not redesign the product into a generic marketplace, do not create a second competing backend, and do not use Convex or another data store unless repository evidence and an explicit approved decision require it.

**Scope of this architecture task:** document and implement through reviewed, version-controlled changes. Do not make production tables/policies/functions directly from an ad hoc dashboard session; create migration files in the repository, review them, and apply in controlled order. Do not claim a feature is production-ready until tested against the new project.

## 2. Production principles

1. **Production is production.** No closed-testing release plan, fake production data, staging labels, or test-only bypasses in production behavior. Keep local/unit/integration test fixtures isolated from real user data.
2. **Deny by default.** Every exposed table has RLS enabled; every policy has a specific role, ownership, relationship, and state predicate.
3. **Backend authorization is authoritative.** Hiding screens or filtering client-side is never access control.
4. **Minimize sensitive data.** Store only the verification result/status and provider references needed for operations; avoid storing raw identity documents unless explicitly required and legally reviewed.
5. **Fail closed for safety-critical operations.** Unverified, suspended, blocked, or insufficiently authorized accounts cannot bypass gates through alternate clients or direct API calls.
6. **Migrations are the source of truth.** All schema, policies, functions, triggers, buckets, and seed/reference data needed for reproducible setup must be version-controlled.
7. **No secrets in clients or Git.** Only the Supabase publishable/anon client key may be used in a public mobile client. Never bundle the service-role/secret key, database password, or provider secrets.
8. **Observable and recoverable.** Log security-relevant events without logging passwords, tokens, private message bodies, or raw identity evidence. Document backup and restore procedures.
9. **No unsafe rollout claims.** Do not switch the released app to the new backend until migration, integration, security, and rollback checks are evidenced.

## 3. System architecture

- **Client:** Existing Flutter mobile app. Use typed models/repositories and a single configured Supabase client. UI role routing is for experience only; server policies enforce permissions.
- **Identity:** Supabase Auth for sign-in/session lifecycle. A protected application profile and server-controlled role/verification records determine permissions. Never trust user-editable auth metadata for authorization.
- **System of record:** Supabase Postgres. Relational integrity, explicit constraints, indexes, status transitions, and transaction boundaries are required.
- **Authorization:** PostgreSQL RLS for row-level access; carefully scoped grants; private schemas for internal records; Edge Functions or database functions only for operations that require trusted orchestration.
- **Server operations:** Supabase Edge Functions for privileged multi-step actions (verification callbacks, moderation actions, safety escalation, notification dispatch, and future payment orchestration). Validate the caller, input, ownership, current state, and idempotency server-side.
- **Files:** Supabase Storage private buckets with explicit storage.objects policies and short-lived signed URLs only after server-side authorization.
- **External services:** Integrate only after contracts, secrets, failure behavior, privacy, and compliance are documented. Keep payments and identity-provider production credentials disabled until explicitly configured and verified.
- **Operations:** Version-controlled migrations, automated tests, Supabase security/performance advisors, structured operational logs, backups, restore drill, and a documented rollback/cutover runbook.

Do not introduce another backend service or duplicate the source of truth without an architecture decision record.

## 4. Domain model and ownership boundaries

Codex must reconcile these logical domains with the existing app and repository before finalizing physical table names. Prefer normalized tables with UUID primary keys, UTC timestamps, explicit foreign keys, and constrained status enums/checks. Do not blindly create duplicate tables if an equivalent correct model already exists in the codebase.

### Accounts and access
- **profiles:** one row per `auth.users.id`; minimal public profile fields, account state, timestamps.
- **account_roles / role grants:** server-controlled roles such as `teen`, `adult`, `business`, and `admin`. Prevent self-assignment of privileged roles. A business may be represented as an organization linked to an adult owner where the existing product supports it.
- **teen_profiles:** age-band/eligibility and teen-specific settings; do not expose date of birth publicly.
- **adult_profiles / businesses:** adult account and business identity/profile details, with explicit ownership/membership relationships.
- **guardian_relationships:** optional, explicit, revocable guardian relationships and consent/oversight state. Guardian access is not automatic; require verified relationship and the specific permission granted.

### Verification and trust
- **verification_cases / verification_events:** provider references, status, method, review timestamps, reviewer/action metadata, and minimal decision evidence. Raw school ID or identity evidence must not be broadly queryable. School ID and school-email verification may be supported as planned product requirements, but implementation must document provider/manual workflow, retention, appeal, and access restrictions before collecting real documents.
- **safety_flags / account_restrictions:** account restrictions, expiry, reason codes, and authorized resolution path. Sensitive notes stay private to authorized safety staff.

### Marketplace
- **jobs:** owner/poster, category, description, compensation terms, approximate work area, schedule, requirements, visibility and lifecycle status. Never expose a teen's precise home address or exact location publicly.
- **job_applications:** applicant, job, state, timestamps, and relevant decision metadata. Enforce one valid application per intended uniqueness rule and prevent unauthorized status transitions.
- **work_agreements / job_outcomes:** only if required by the existing product; keep agreed terms and completion/cancellation evidence auditable.
- **reviews:** only for verified completed interactions, with abuse prevention and moderation controls.

### Communication and safety
- **conversations / conversation_members:** membership records must authorize access; do not assume a user can read a conversation because they know its ID.
- **messages:** readable only to authorized conversation members and authorized safety workflows. Preserve message safety scanning and report/block behavior. Safety scanning must not be presented as perfect or used as the only protection.
- **blocks:** directional user blocks with server-enforced effects on discovery, applications, and messaging.
- **reports / report_evidence / moderation_cases:** separate user-submitted reports from staff-only case notes and evidence. Enforce least-privilege access and retention rules.
- **safety_events / audit_events:** append-oriented, access-restricted records for sensitive state transitions and admin actions; do not allow normal clients to alter or erase audit history.
- **notifications / device_tokens:** private per-user data; validate ownership and support revocation.

### Payments (not a launch assumption)
- Keep payment state and provider identifiers server-controlled if the existing product requires them. Never store card data. Do not enable real payments or claim payment readiness until a provider is approved, teen/minor compliance is reviewed, webhook signatures and idempotency are tested, and refund/dispute flows are defined. Do not place secrets in client code.

## 5. Role and privacy matrix

| Resource | Teen | Adult/business | Guardian | Admin/safety staff |
|---|---|---|---|---|
| Own profile | Read/update allowed fields | Read/update allowed fields | Only fields explicitly shared by a verified relationship | Least-privilege case-based access |
| Other users' private profiles | No | No | No, except explicitly authorized linked teen fields | Only when necessary for safety operations |
| Public job listing | Read eligible visible listings | Read visible listings; manage only own/authorized business listings | No general access unless product explicitly grants it | Moderation access |
| Applications | Own applications; poster sees applicants only for their own job under policy | Manage applications only for own/authorized job | Only explicitly authorized oversight view | Case-based access |
| Conversations/messages | Members only; block/suspension rules apply | Members only; block/suspension rules apply | No automatic access; only explicit policy/product grant | Restricted safety access with audit trail |
| Verification evidence | Status only; no raw evidence access by default | Status only; no raw evidence access by default | No raw evidence access | Only specifically authorized reviewers |
| Reports/evidence | Submit and see own submission status where safe | Submit and see own submission status where safe | No automatic access | Assigned/authorized case access |
| Admin/audit records | No | No | No | Authorized staff only |

The matrix is a baseline, not permission to grant every row automatically. Where the existing product has a more restrictive rule, retain the stricter rule.

## 6. RLS and authorization requirements

For every table in an exposed schema:
- Enable RLS and explicitly grant only the minimum required SQL privileges.
- Write separate SELECT, INSERT, UPDATE, and DELETE policies as needed; do not use broad `TO authenticated USING (true)` policies.
- Bind ownership to `auth.uid()` and verified relationship rows, not client-supplied role strings or IDs alone.
- UPDATE policies must include both `USING` and `WITH CHECK` to prevent ownership reassignment.
- Prevent clients from creating/updating their own role, admin status, verification approval, moderation outcomes, payment state, or audit records.
- Prefer private/non-exposed schemas for internal tables. Restrict function execution explicitly; avoid SECURITY DEFINER unless essential and independently reviewed.
- For views, use `security_invoker = true` where supported or keep views inaccessible to untrusted roles.
- Storage policies must validate bucket, object path ownership, authorized case relationship, and permitted operation. Verification/evidence buckets remain private.
- Test adversarial cross-account access: guessed UUIDs, changed IDs, role changes, revoked guardian links, blocked users, suspended users, stale sessions, and direct REST/storage calls.

## 7. Critical state machines

Define and enforce explicit server-side transitions for:
- Account: pending verification → eligible/restricted/suspended/closed.
- Verification: submitted → pending review → approved/rejected/needs-more-info/expired/appealed.
- Job: draft → published → paused/filled/cancelled/completed/expired.
- Application: submitted → accepted/declined/withdrawn/cancelled/completed, constrained by job state and actor permissions.
- Report/moderation: submitted → triaged → investigating → actioned/resolved/appealed.
- Block and guardian relationship: active/revoked, with immediate effect on future access.
- Payment (if later enabled): provider-backed, idempotent state transitions only; no client-authoritative settlement.

Reject illegal transitions server-side and test duplicate requests/retries.

## 8. API, Edge Functions, and events

- Use direct Postgres/Data API access only for operations that are safe under RLS and ordinary user grants.
- Use Edge Functions for privileged workflows, external provider calls, webhook verification, moderation decisions, and multi-step operations requiring atomic/idempotent behavior.
- Validate JWT/session, role, ownership, request schema, rate limits, and current record state for every privileged endpoint.
- Use idempotency keys for retried operations and webhook events; verify webhook signatures.
- Keep internal-only functions out of exposed schemas and revoke default execution grants where appropriate.
- Do not rely on client clocks, client-supplied prices, role fields, verification booleans, or arbitrary status strings.

## 9. Migration and implementation workflow

Codex must:
1. Inspect the current repository, app models/repositories, Supabase configuration, migration files, functions, and tests.
2. Write an inventory mapping existing app features to the new schema. Flag missing/ambiguous behavior instead of guessing.
3. Create a clean, ordered migration series in the repository using the Supabase CLI's supported migration workflow. Do not recreate old migration history blindly.
4. Keep schema changes, RLS policies, grants, functions, triggers, storage buckets/policies, and required indexes in reviewed migration files.
5. Validate migrations on a disposable local/test database before applying them to `mort p`.
6. Apply migrations to the production project only after reviewing the diff and passing tests; record exactly which migrations were applied.
7. Generate and commit typed database models where applicable, then integrate Flutter repositories/configuration without leaking secrets.
8. Run unit, integration, RLS, storage, auth/session, and critical workflow tests. Include negative tests, not only happy paths.
9. Run Supabase security and performance advisors; remediate critical/high findings before launch.
10. Produce a final evidence report with commit SHA, migration list, test commands/results, unresolved risks, configuration actions requiring the owner, and rollback instructions.

Never run a destructive reset against the production project. Never seed production with test accounts or fixture data. Never claim a dashboard toggle, migration, external provider, backup, or release is configured unless verified.

## 10. Production acceptance gates

Do not mark the backend ready until all relevant checks are evidenced:
- [ ] Project ref and region match this specification.
- [ ] Schema is reproducible from committed migrations.
- [ ] No unexplained schema drift or untracked manual changes.
- [ ] RLS is enabled on every exposed table and policies are reviewed.
- [ ] Cross-role and cross-user negative tests pass.
- [ ] Teen/adult separation and optional guardian boundaries pass direct API tests.
- [ ] Auth/session lifecycle, suspension, revocation, and account deletion behavior are tested.
- [ ] Private storage access and signed URL expiry/revocation behavior are tested.
- [ ] Message/report/block/moderation flows and audit records are tested.
- [ ] No production secret is present in source control, client bundles, or logs.
- [ ] Supabase security/performance advisors have been reviewed and blocking findings resolved.
- [ ] Backups and a restore drill are verified for the selected plan.
- [ ] Observability, incident response, data retention, and rollback/cutover runbooks are documented.
- [ ] Production app configuration is updated deliberately and smoke-tested.
- [ ] External services (identity, payments, notifications) are either verified production-ready or explicitly disabled without unsafe fallbacks.

## 11. Explicit exclusions

- No closed-testing track or closed-testing release setup.
- No copying the deleted project's database state or secrets.
- No direct production schema edits outside reviewed migrations.
- No automatic guardian access to teen data.
- No client-side-only authorization.
- No exposing private identity documents or precise teen locations.
- No production payment/identity claims without verified configuration and compliance review.
- No deployment or public launch merely because the project has been created.

## 12. Required Codex deliverables

Codex should work in `mortapp/Mort` on a dedicated feature branch and deliver:
1. This architecture reconciled against actual repository evidence.
2. A domain/schema inventory and relationship diagram.
3. Ordered migrations with RLS/grants/storage/functions included.
4. Automated positive and negative security/integration tests.
5. Typed client integration and safe environment configuration.
6. Supabase advisor output and a remediation log.
7. A production readiness report with verified facts separated from assumptions.
8. A cutover and rollback runbook.

Do not merge or deploy automatically if production gates fail. Keep the app's release/distribution plan separate from database architecture; this specification does not authorize a closed-testing release.
