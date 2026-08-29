# Account Deletion FK Decision Matrix — 2026-08-29

This replaces the blanket "convert every RESTRICT to SET NULL" approach in the
original migration with an explicit, per-relationship disposition. All 87
foreign keys found blocking `auth.admin.deleteUser()` (see
`ACCOUNT_DELETION_IMPLEMENTATION_AUDIT.md` for how they were discovered) are
classified below. The audit also classifies critical pre-existing CASCADE
edges for shared marketplace records, guardian history, and active role/link
authorization. **This document describes the corrected, locally-verified
proposed state. Hosted still has the original, unmodified RESTRICT behavior
— nothing described here has been deployed.**

## Classes

- **A. DELETE / CASCADE** — the row has no independent value once the user
  is gone; it deletes with them.
- **B. SET NULL + DEIDENTIFY** — the row's factual content is retained; the
  identity link is severed.
- **C. RETAIN WITH PRIVATE PSEUDONYMOUS SUBJECT CONTINUITY** — not used in
  this pass. No relationship below was found to need a persistent
  cross-reference to a deleted identity beyond what SET NULL already
  preserves (the content itself, e.g. `content_hash` + `accepted_at` on
  `legal_acceptances`). Flagged explicitly per-row where this was considered
  and rejected, and marked `LEGAL_REVIEW_REQUIRED` where an external legal
  opinion could change that answer.
- **D. TEMPORARY RETENTION UNDER EXPLICIT HOLD** — the existing financial
  retention hold (`service_check_account_deletion_financial_retention`) is
  the real control; the FK action is a safety net, not the primary
  mechanism.
- **E. EXCEPTIONAL DELETE BLOCKER** — RESTRICT kept intentionally. **Zero**
  rows use this class in this matrix; no externally-required reason to block
  deletion outright was found for any of the 87.

## Special mechanisms required (beyond a bare FK action change)

1. **`team_role_assignments.user_id`**: changed to **CASCADE**, not SET
   NULL — matching the *already-established* precedent in this exact
   codebase for the identical semantic pattern:
   `stripe_financial_role_assignments.user_id` and
   `support_staff_assignments.user_id` (the actual role-holder columns, not
   the `assigned_by` actor columns) are **already `ON DELETE CASCADE`**
   (verified live). A live role grant should not survive as an orphaned,
   still-"active"-looking row with a null holder — it should disappear with
   the account, exactly like its two sibling tables. Historical evidence of
   *who accessed what* lives separately in `team_access_audit_events`
   (class B below), which is unaffected by this change.
2. **`incident_assignments.assigned_to`**: needs a close-out step before
   SET NULL, not a bare FK change. The table already has an `ended_at`
   column expressing "this assignment is over." A `BEFORE DELETE` trigger on
   `public.profiles` sets `ended_at = now()` on any of that profile's
   assignment rows where `ended_at IS NULL`, so a case never silently shows
   an assignee that both no longer exists and was never marked as having
   stopped working the case. The FK itself is then SET NULL.
3. **Shared marketplace identity**: `jobs.poster_id` and
   `applications.teen_id` were pre-existing CASCADE relationships. Either
   one could erase the other participant's job, application, and downstream
   evidence, and could itself hit deeper RESTRICT edges. Both become class B.
   Before a poster is deleted, unfinished jobs are closed and non-terminal
   applications are moved to the same terminal statuses used by the
   canonical job-cancellation state machine. Completed/closed evidence is
   preserved unchanged. The existing identity-verification trigger permits
   nulling only inside the UUID-bound `supabase_auth_admin` deletion
   transaction; direct PostgREST UPDATE/UPSERT remains denied.
4. **Guardian authorization versus history**:
   `guardian_connections.teen_id` and `.guardian_id` remain CASCADE so an
   active guardian link never survives deletion of either participant.
   `guardian_connection_audit_events.teen_id` changes from CASCADE to class B
   so the audit event survives deidentified, matching its already-SET-NULL
   guardian/actor columns.
5. **Other active authorization holders**: existing CASCADE behavior is
   pinned by regression for `admin_role_assignments.user_id`,
   `partner_memberships.user_id`, `partner_staff.user_id`,
   `stripe_financial_role_assignments.user_id`, and
   `support_staff_assignments.user_id`. Historical actor/audit columns remain
   class B.

Incident and marketplace close-out are implemented in a single trigger function,
`private.close_out_authorization_before_account_deletion()`, fired
`BEFORE DELETE ON public.profiles FOR EACH ROW` (fires during the cascade
Postgres performs when `auth.admin.deleteUser()` deletes `auth.users`, before
the row and its FK actions are actually applied).

## The matrix

Grouped by table for readability; every row is one of the 87 relationships.
`REFERENCES` omitted where it's `public.profiles(id)` (the default); noted
explicitly for the eight that reference `auth.users(id)` directly.

| TABLE | COLUMN | CURRENT | NULLABLE | SUBJECT/ACTOR/SHARED | FINAL_CLASS | FINAL_ON_DELETE | NOTE |
|---|---|---|---|---|---|---|---|
| account_ban_appeals | user_id | RESTRICT | N | SUBJECT (appellant) | B | SET NULL | appeal text/status/reviewer stay; deidentify appellant |
| appearance_review_assignments | assigned_by | RESTRICT | N | ACTOR | B | SET NULL | |
| appearance_review_assignments | reviewer_id | RESTRICT | N | ACTOR | B | SET NULL | |
| appearance_review_cases | subject_user_id | RESTRICT | N | SUBJECT | B | SET NULL | moderation case record survives, deidentified |
| appearance_review_decisions | reviewer_id | RESTRICT | N | ACTOR | B | SET NULL | |
| completion_evidence_records | submitted_by | RESTRICT | N | ACTOR (shared job record) | B | SET NULL | job completion evidence stays for counterparty |
| document_capture_sessions | subject_user_id | RESTRICT | N | SUBJECT | B | SET NULL | |
| document_review_assignments | assigned_by | RESTRICT | N | ACTOR | B | SET NULL | |
| document_review_assignments | reviewer_id | RESTRICT | N | ACTOR | B | SET NULL | |
| document_review_decisions | reviewer_id | RESTRICT | N | ACTOR | B | SET NULL | |
| document_web_reuse_requests | subject_user_id | RESTRICT | N | SUBJECT | B | SET NULL | |
| identity_verification_evidence | user_id | RESTRICT | N | SUBJECT | B | SET NULL | identity_verifications itself already CASCADEs; this is the separate evidence-artifact table |
| incident_actions | actor_id | RESTRICT | N | ACTOR | B | SET NULL | incident record and action log survive |
| incident_assignments | assigned_by | RESTRICT | N | ACTOR | B | SET NULL | |
| incident_assignments | assigned_to | RESTRICT | N | ACTOR (active case assignee) | B + close-out trigger | SET NULL | see "special mechanisms" — ended_at set first |
| incident_contact_attempts | actor_id | RESTRICT | N | ACTOR | B | SET NULL | |
| incident_outcomes | decided_by | RESTRICT | N | ACTOR | B | SET NULL | |
| incident_preservation_orders | ordered_by | RESTRICT | N | ACTOR | B | SET NULL | legal-hold order record survives regardless of who ordered it |
| job_arrival_handshakes | finish_confirmed_by | RESTRICT | Y (already) | ACTOR (shared job record) | B | SET NULL | |
| job_arrival_handshakes | finish_requested_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| job_arrival_handshakes | start_confirmed_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| job_completion_assertions | asserted_by | RESTRICT | N | ACTOR (shared job record) | B | SET NULL | |
| job_contract_acceptances | user_id | RESTRICT | N | SUBJECT (shared record) | B | SET NULL | contract acceptance timestamp/version survive for the other party |
| job_contract_change_acceptances | user_id | RESTRICT | N | SUBJECT (shared record) | B | SET NULL | |
| job_contract_change_requests | requested_by | RESTRICT | N | ACTOR (shared record) | B | SET NULL | |
| job_contract_versions | created_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| job_contracts | adult_id | RESTRICT | N | SHARED PARTY | B | SET NULL | contract terms/status survive for the surviving teen party |
| job_contracts | teen_id | RESTRICT | N | SHARED PARTY | B | SET NULL | contract terms/status survive for the surviving adult party |
| job_execution_cancellations | actor_id | RESTRICT | N | ACTOR (shared record) | B | SET NULL | |
| job_payment_obligations | obligated_poster_id | RESTRICT | N | SHARED PARTY | B | SET NULL | factual obligation (amount, timestamps) survives for the worker's record |
| job_payment_obligations | worker_id | RESTRICT | N | SHARED PARTY | B | SET NULL | survives for the poster's record |
| legal_acceptance_audit_events | user_id | RESTRICT | N | SUBJECT (audit trail) | B | SET NULL | `LEGAL_REVIEW_REQUIRED` — see dedicated section below |
| legal_acceptances | user_id | RESTRICT | N | SUBJECT | B | SET NULL | `LEGAL_REVIEW_REQUIRED` — see dedicated section below |
| legal_declines | user_id | RESTRICT | N | SUBJECT | B | SET NULL | `LEGAL_REVIEW_REQUIRED` — same reasoning as legal_acceptances |
| legal_reacceptance_requirements | user_id | RESTRICT | N | SUBJECT | B | SET NULL | requirement is moot once the account is gone; deidentify rather than delete for audit consistency with the other legal_* tables |
| live_presence_challenges | subject_user_id | RESTRICT | N | SUBJECT | B | SET NULL | |
| message_safety_evidence | sender_id | RESTRICT | N | SUBJECT/ACTOR | B | SET NULL | evidence content (the flagged message) survives for the report it supports |
| partner_invite_codes | created_by | RESTRICT | N | ACTOR | B | SET NULL | |
| partner_permissions | granted_by | RESTRICT | N | ACTOR | B | SET NULL | |
| payment_confirmation_records | confirmed_by | RESTRICT | N | ACTOR (shared record) | B | SET NULL | |
| payment_dispute_appeals | appellant_id | RESTRICT | N | SUBJECT | B | SET NULL | `LEGAL_REVIEW_REQUIRED` — financial dispute evidentiary record, see below |
| payment_dispute_appeals | reviewed_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| payment_dispute_assignments | assigned_by | RESTRICT | N | ACTOR | B | SET NULL | |
| payment_dispute_assignments | reviewer_id | RESTRICT | N | ACTOR | B | SET NULL | |
| payment_dispute_decisions | reviewer_id | RESTRICT | N | ACTOR | B | SET NULL | |
| payment_dispute_evidence | submitted_by | RESTRICT | N | ACTOR (shared record) | B | SET NULL | |
| payment_dispute_statements | author_id | RESTRICT | N | ACTOR (shared record) | B | SET NULL | `LEGAL_REVIEW_REQUIRED` — a party's dispute statement, see below |
| payment_dispute_timeline | actor_id | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| payment_disputes | opened_by | RESTRICT | N | ACTOR | B | SET NULL | `LEGAL_REVIEW_REQUIRED` |
| payment_disputes | poster_id | RESTRICT | N | SHARED PARTY | B | SET NULL | `LEGAL_REVIEW_REQUIRED` |
| payment_disputes | worker_id | RESTRICT | N | SHARED PARTY | B | SET NULL | `LEGAL_REVIEW_REQUIRED` |
| payment_evidence_export_events | requested_by | RESTRICT | N | ACTOR | B | SET NULL | |
| poster_payment_restrictions | imposed_by | RESTRICT | N | ACTOR | B | SET NULL | |
| poster_payment_restrictions | lifted_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| poster_payment_restrictions | poster_id | RESTRICT | N | SUBJECT of restriction | B | SET NULL | restriction is moot once the restricted account is deleted; record retained for moderation-pattern history |
| private.document_vault_access_grants | reviewer_id | RESTRICT | N | ACTOR | B | SET NULL | |
| private.first_party_trust_control | enabled_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| private.identity_verification_webhook_events | user_id | RESTRICT | Y (already) | SUBJECT (webhook log) | B | SET NULL | |
| private.stripe_account_onboarding_sessions | user_id | RESTRICT, → auth.users | N | SUBJECT | B | SET NULL | attempted-but-incomplete onboarding; not covered by the financial hold (see Stripe section) |
| private.stripe_connected_accounts | user_id | RESTRICT, → auth.users | N | SUBJECT | D | SET NULL | covered by the financial-retention hold; SET NULL is the safety net, not the primary control |
| private.stripe_customers | user_id | RESTRICT, → auth.users | N | SUBJECT | D | SET NULL | covered by the hold; safety net only |
| private.stripe_financial_role_assignments | assigned_by | RESTRICT, → auth.users | N | ACTOR | B | SET NULL | (the `user_id` holder column on this same table is unaffected — already CASCADE) |
| private.stripe_job_payment_attempts | initiated_by | RESTRICT, → auth.users | N | ACTOR | B | SET NULL | historical reconciliation record; not covered by the hold |
| private.stripe_job_payment_intents | adult_id | RESTRICT, → auth.users | N | SHARED PARTY | D | SET NULL | covered by the hold; safety net only |
| private.stripe_job_payment_intents | teen_id | RESTRICT, → auth.users | N | SHARED PARTY | D | SET NULL | covered by the hold; safety net only |
| private.stripe_payment_resolutions | financial_operator_id | RESTRICT, → auth.users | Y (already) | ACTOR | B | SET NULL | not covered by the hold |
| private.stripe_payment_resolutions | reviewer_id | RESTRICT, → auth.users | Y (already) | ACTOR | B | SET NULL | not covered by the hold |
| private.support_staff_assignments | assigned_by | RESTRICT, → auth.users | N | ACTOR | B | SET NULL | (the `user_id` holder column is unaffected — already CASCADE) |
| safety_cancellations | actor_id | RESTRICT | N | ACTOR (shared record) | B | SET NULL | |
| support_attachments | owner_id | RESTRICT | N | SUBJECT | B | SET NULL | |
| support_evidence_attachments | owner_id | RESTRICT | N | SUBJECT | B | SET NULL | |
| support_internal_notes | author_id | RESTRICT | N | ACTOR | B | SET NULL | |
| support_ticket_appeals | requester_id | RESTRICT | N | SUBJECT | B | SET NULL | |
| team_access_audit_events | user_id | RESTRICT | N | SUBJECT (historical audit) | B | SET NULL | historical access-audit trail — deliberately distinct from team_role_assignments (below) |
| team_confidentiality_acknowledgements | user_id | RESTRICT | N | SUBJECT (historical) | B | SET NULL | |
| team_conflict_disclosures | reviewed_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| team_conflict_disclosures | user_id | RESTRICT | N | SUBJECT (historical) | B | SET NULL | |
| team_device_compliance | reviewed_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| team_device_compliance | user_id | RESTRICT | N | SUBJECT (historical) | B | SET NULL | |
| **team_role_assignments** | **user_id** | RESTRICT | N | **HOLDER (active authorization)** | **A** | **CASCADE** | see "special mechanisms" — matches the CASCADE already used for the identical pattern on stripe_financial_role_assignments.user_id and support_staff_assignments.user_id |
| team_role_assignments | approved_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| team_role_assignments | revoked_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| team_training_completions | approved_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| team_training_completions | user_id | RESTRICT | N | SUBJECT (historical) | B | SET NULL | |
| teen_abandonment_reports | decided_by | RESTRICT | Y (already) | ACTOR | B | SET NULL | |
| teen_abandonment_reports | reported_by_adult_id | RESTRICT | Y (already) | ACTOR/REPORTER | B | SET NULL | |
| teen_abandonment_reports | teen_id | RESTRICT | N | SUBJECT | B | SET NULL | safety report about the teen survives even if that account is later deleted |

**Original blocker total: 87 rows classified. 0 unclassified. Class A: 1.
Class B: 82. Class D: 4. Class C: 0. Class E: 0.**

Precise count reconciliation: reading the table above, Class D applies to
exactly the four columns the hold mechanism actually checks —
`stripe_connected_accounts.user_id`, `stripe_customers.user_id`,
`stripe_job_payment_intents.adult_id`, `stripe_job_payment_intents.teen_id`
— all still resolve to `ON DELETE SET NULL` at the schema level (D describes
*why* SET NULL is safe here, not a different SQL action). Every other row is
B (`SET NULL`) except `team_role_assignments.user_id`, which is A
(`CASCADE`). No row is C or E.

### Critical pre-existing relationships audited with the blocker matrix

These are not part of the original 87 RESTRICT/NO ACTION defects. They are
included because their pre-existing CASCADE behavior either represented
active authorization that must disappear, or destroyed shared evidence that
must survive.

| TABLE | COLUMN | ORIGINAL | FINAL_CLASS | FINAL_ON_DELETE | RATIONALE |
|---|---|---|---|---|---|
| jobs | poster_id | CASCADE | B + close-out | SET NULL | preserve the applicant's shared record; close unfinished job first |
| applications | teen_id | CASCADE | B | SET NULL | preserve poster/shared application and downstream contract/safety history |
| guardian_connection_audit_events | teen_id | CASCADE | B | SET NULL | preserve deidentified historical link audit |
| guardian_connections | teen_id | CASCADE | A | CASCADE | active guardian authorization cannot survive the teen account |
| guardian_connections | guardian_id | CASCADE | A | CASCADE | active guardian authorization cannot survive the guardian account |
| admin_role_assignments | user_id | CASCADE | A | CASCADE | active admin authorization holder |
| partner_memberships | user_id | CASCADE | A | CASCADE | active organization authorization holder |
| partner_staff | user_id | CASCADE | A | CASCADE | active partner staff authorization holder |
| private.stripe_financial_role_assignments | user_id | CASCADE | A | CASCADE | active financial authorization holder |
| private.support_staff_assignments | user_id | CASCADE | A | CASCADE | active support authorization holder |

The durable contract currently pins 99 relationships exactly: the 87
original blockers plus 12 pre-existing relationships reviewed during the
audit (`account_ban_appeals.assigned_reviewer_id` and
`account_deletion_requests.user_id` are the remaining two historical class-B
edges). It also checks all 336 direct `profiles`/`auth.users` foreign keys for
RESTRICT/NO ACTION and SET-NULL/nullability contradictions.

## Stripe / financial tables — resolved intentionally (directive item 7)

The financial-retention hold
(`private.stripe_financial_retention_required`) checks exactly three
relations: `stripe_connected_accounts`, `stripe_customers`,
`stripe_job_payment_intents` (by `adult_id` or `teen_id`). It returns `true`
(pausing deletion for human review) if **any** row exists there for the
user, regardless of whether it represents a currently-active relationship or
a fully historical/closed one — a coarse but safe gate.

The other five auth.users-referencing tables in the original 87
(`stripe_account_onboarding_sessions`, `stripe_financial_role_assignments`
`.assigned_by`, `stripe_job_payment_attempts`, `stripe_payment_resolutions`
×2) are **not** checked by the hold. None of them represent an active
provider relationship on their own:

- `stripe_account_onboarding_sessions`: an attempted, possibly-incomplete
  Connect onboarding flow. No money or live account exists from this alone.
- `stripe_job_payment_attempts`: a historical attempt record (including
  failed attempts) — reconciliation/fraud-review value, not an active
  relationship.
- `stripe_payment_resolutions.financial_operator_id` /`.reviewer_id`: staff
  actor columns on a resolution record, not the affected user.
- `stripe_financial_role_assignments.assigned_by`: staff actor column.

None of these need the hold extended to cover them — they're historical/actor
records, not live financial relationships — so `SET NULL` (class B) is
correct and sufficient. Given MORT does not currently process or escrow
real-world job payments (`mort_payments_disabled_zero_fee.sql`), none of this
dormant Stripe sandbox architecture is being given retention weight beyond
"a factual historical record, deidentified" — no blanket permanent retention
was applied merely because the tables have "financial" in the name.

## `LEGAL_REVIEW_REQUIRED` items

Two families are marked for external legal determination rather than
resolved unilaterally, per the instruction not to invent legal requirements:

1. **`legal_acceptances`, `legal_declines`, `legal_reacceptance_requirements`,
   `legal_acceptance_audit_events`** (all `user_id`). What SET NULL retains:
   `document_id`, `document_version_id`, `content_hash`, `role`, `age_band`,
   `effective_date`, `accepted_at`, `platform`, `app_version`,
   `affirmative_checkbox`, `active`/`withdrawn_at`. What it loses: which
   specific (now-deleted) account performed the acceptance. **Open
   question**: does MORT need to be able to prove, after a specific
   individual's account is deleted, that *that specific person* accepted a
   specific policy version (e.g., in response to a legal claim from a former
   user or their guardian)? If yes, a private, restricted pseudonymous key
   (e.g., a one-way hash of the original account ID, stored only in a
   locked-down table with no ordinary read path) may be warranted instead of
   plain SET NULL. If the retained content_hash + timestamp + role/age-band
   context is legally sufficient to demonstrate the acceptance flow was
   correctly presented and used, SET NULL is sufficient as implemented. This
   session did not have a legal opinion available and is not qualified to
   resolve it — flagging rather than deciding.
2. **`payment_disputes` (+ `_appeals`, `_statements`) `poster_id`/`worker_id`/
   `opened_by`/`appellant_id`/`author_id`**. Same shape of question for
   financial dispute evidence: does resolving a real-world payment
   disagreement ever need to re-identify a party after their account is
   deleted (e.g., a lifted `poster_payment_restrictions` appeal, or a
   reopened dispute)? SET NULL retains the dispute's factual content (job
   scope references, amounts, timeline, statements) but severs identity.
   Flagging for the same reason as above.

Both are implemented as `SET NULL` in the corrected migration (the safer
default that never blocks deletion and never over-retains PII), with this
explicit flag that a future legal review could determine a different,
more restrictive-but-still-deletion-compatible pattern (e.g., pseudonymous
keys) is required. **This is not a decision to leave the defect unfixed** —
account deletion must not remain broken while waiting on a legal opinion;
it's a decision that today's SET NULL is deletion-safe and privacy-minimizing,
and could be *tightened* later without reintroducing the RESTRICT defect.
