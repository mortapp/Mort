# Account Deletion Implementation Audit — 2026-08-29

## Pipeline (as implemented, verified against code)

1. **Client**: Settings → Account → Delete account (Flutter; entry point in
   `flutter_mort/lib` Settings screen) calls a request-creation RPC that
   inserts a row into `public.account_deletion_requests` (`status='requested'`).
2. **State machine** (`supabase/migrations/20260728222202_account_deletion_processor_state_machine.sql`):
   `service_claim_account_deletion_request` / `service_complete_account_deletion_request`
   / `service_fail_account_deletion_request` — all `service_role`-only, with
   `for update skip locked` claiming, a 15-minute stale-processing timeout, and
   a 5-attempt cap before permanent `failed` status.
3. **Worker** (`supabase/functions/account-deletion-processor/index.ts`),
   invoked with a shared-secret header (`x-mort-deletion-secret`), constant-time
   compared:
   - Claims a request.
   - Calls `service_check_account_deletion_financial_retention` →
     `private.stripe_financial_retention_required`, which holds the deletion
     (`status='requested'` effectively re-queued via
     `service_hold_account_deletion_for_financial_retention`, no destructive
     action taken) if the user has *any* row in `stripe_connected_accounts`,
     `stripe_customers`, or `stripe_job_payment_intents` — regardless of
     whether that row represents an active obligation. This is a coarse but
     safe gate: it never lets a Stripe-linked account proceed to the next step
     until a human/financial process clears it.
   - Removes every storage object the user owns
     (`service_list_account_deletion_storage_objects`, paginated, then
     `storage.remove()` per bucket).
   - Calls `supabase.auth.admin.deleteUser(userId, false)` — a **hard** delete
     of `auth.users`. `public.profiles.id` references `auth.users(id) on
     delete cascade`, so this is also where the profile, and everything that
     cascades from the profile, is actually destroyed.
   - Marks the request `completed` with a retention summary.

## Critical finding (fixed this session): RESTRICT was silently blocking deletion

`auth.admin.deleteUser()` is a hard delete. Postgres will refuse it if *any*
foreign key pointing at the row (directly at `auth.users`, or transitively at
`public.profiles` via the cascade) is `ON DELETE RESTRICT` and a matching
child row exists.

A live query against the hosted database (`pg_constraint`, `confdeltype`)
found **87 such foreign keys** — every one of them at Postgres's implicit
default (no `ON DELETE` clause was ever written for them; this is not a
deliberate "block deletion" design). They span:

- **Legal**: `legal_acceptances`, `legal_declines`, `legal_reacceptance_requirements`, `legal_acceptance_audit_events`
- **Trust & safety review**: `appearance_review_assignments/cases/decisions`, `document_review_assignments/decisions`, `document_capture_sessions`, `document_web_reuse_requests`, `identity_verification_evidence`, `live_presence_challenges`, `incident_actions/assignments/contact_attempts/outcomes/preservation_orders`, `message_safety_evidence`, `safety_cancellations`, `teen_abandonment_reports`
- **Financial/dispute**: `payment_disputes` (+ `_appeals`, `_assignments`, `_decisions`, `_evidence`, `_statements`, `_timeline`), `payment_confirmation_records`, `payment_evidence_export_events`, `poster_payment_restrictions`, `job_payment_obligations`, `job_contracts` (+ `_versions`, `_change_requests`, `_change_acceptances`, `_acceptances`), `job_completion_assertions`, `job_execution_cancellations`, `completion_evidence_records`
- **Support/moderation**: `support_attachments`, `support_evidence_attachments`, `support_internal_notes`, `support_ticket_appeals`, `account_ban_appeals`
- **Staff/partner**: `team_role_assignments`, `team_access_audit_events`, `team_confidentiality_acknowledgements`, `team_conflict_disclosures`, `team_device_compliance`, `team_training_completions`, `partner_invite_codes`, `partner_permissions`, `document_vault_access_grants`, `first_party_trust_control`
- **Stripe/financial identity** (referencing `auth.users` directly): `stripe_account_onboarding_sessions`, `stripe_connected_accounts`, `stripe_customers`, `stripe_financial_role_assignments`, `stripe_job_payment_attempts`, `stripe_job_payment_intents`, `stripe_payment_resolutions`, `support_staff_assignments`, `identity_verification_webhook_events`

**Why this was invisible before today**: the product has not launched yet —
`legal_acceptances` alone would have blocked essentially every real user
(everyone who ever accepts terms gets a row there), but as of this audit it
has **zero rows across 32 profiles** (no legal-policy versions are published
yet — the same `HOSTED_V2_FINISH_BLOCKER=LEGAL_POLICY_PUBLICATION` recorded
elsewhere). `account_deletion_requests` itself has never reached `completed`
or `failed` status hosted (only `requested`/`cancelled`) — no real deletion
has ever actually been attempted against a populated account.

**Fix**: `supabase/migrations/20260829010000_account_deletion_retention_deidentification.sql`
classifies all 87 individually. It converts 86 to `ON DELETE SET NULL`
(relaxing `NOT NULL` first where needed) and converts the active holder edge
`team_role_assignments.user_id` to CASCADE. This matches the deletion
worker's own summary text, which already
claimed this behavior: *"Legally required safety, fraud, and audit records
may remain de-identified under the retention matrix."* The financial
retention hold (above) is unaffected — it still runs first and still pauses
deletion for human review whenever a Stripe-linked row exists, regardless of
this FK change.

Two `stripe_*` tables specifically were checked against the actual hold logic
(`private.stripe_financial_retention_required`) to confirm the hold doesn't
already cover every Stripe table: it only checks `stripe_connected_accounts`,
`stripe_customers`, and `stripe_job_payment_intents`. `stripe_account_onboarding_sessions`,
`stripe_financial_role_assignments`, `stripe_job_payment_attempts`,
`stripe_payment_resolutions`, and `support_staff_assignments` were **not**
covered by the hold and would have hit the RESTRICT wall unprotected — so all
eight needed explicit classification, not just the three the hold checks.

The end-to-end test also exposed three pre-existing CASCADE edges that did
not block deletion but destroyed shared history: `jobs.poster_id`,
`applications.teen_id`, and `guardian_connection_audit_events.teen_id`.
They now SET NULL. Unfinished poster-owned jobs are closed and their
non-terminal applications terminalized before deidentification; completed
evidence is preserved. Active `guardian_connections` still CASCADE when
either participant disappears, so guardian authorization cannot survive.
The marketplace identity trigger permits nulling only in the exact
UUID-bound `supabase_auth_admin` deletion transaction. Direct PostgREST
UPDATE/UPSERT remains denied, including with a service key.

### Verification (local Docker stack, not hosted)

- Fresh `supabase db reset --local --yes` replayed all 195 migrations from
  an empty database with no ordering/dependency failures.
- Post-reset direct-user FK audit: 336 links checked; 149 CASCADE, 187 SET
  NULL, 0 RESTRICT/NO ACTION, and 0 SET-NULL/NOT-NULL contradictions. The
  exact disposition contract passes for all 99 pinned relationships.
- The real `auth.admin.deleteUser()` functional regression passes for active
  team authorization, historical team audit, active incident assignment
  close-out, legal acceptance, ban appeal, shared job/application history,
  active guardian authorization removal, guardian audit retention, duplicate
  deletion behavior, and unrelated-user isolation.
- Hostile service-key PostgREST attempts to write `jobs.poster_id=NULL` and
  `applications.teen_id=NULL` are denied at the database boundary.
- Worker-state regression proves authenticated callers cannot claim jobs,
  concurrent claims have exactly one winner, malformed locks are denied,
  valid completion occurs once, replay cannot produce a second transition,
  and a completed request cannot be reclaimed.
- Deleting a poster closes the unfinished job, terminalizes the pending
  application, preserves both rows, and nulls only the poster identity.
  Deleting the surviving applicant afterward preserves the same application
  and nulls only the applicant identity.
- `qa:migration-reconciliation-parity` (hosted, read-only) still passes —
  this migration doesn't touch any of the seven hash-tracked canonical
  migrations.
- `qa-rls.mjs` (local, full suite) still passes after the FK change — RLS
  policies are independent of FK actions and were unaffected.

### Deletion vs. deidentification, by data class

| Class | Behavior | Mechanism |
|---|---|---|
| Purely personal/owned records with no independent retention need (e.g. `account_security_events`, `account_security_preferences`, `account_trust_appeals`, most `*_preferences` tables, ad frequency caps) | **DELETE** (cascades away with the profile) | Direct-user `ON DELETE CASCADE` (149 after the three shared-history corrections) |
| Legal acceptance/decline records, shared marketplace history, safety/trust/moderation evidence and decisions, payment disputes and their evidence/timeline, historical staff records, Stripe identity links | **RETAIN, DEIDENTIFY** (record survives, person-link severed) | Direct-user `ON DELETE SET NULL` (187 after the 86 blocker fixes and three shared-history corrections) |
| Active staff/team/partner/guardian authorization | **DELETE** | Holder/link CASCADE, pinned by the exact FK contract; audit/actor rows are separate and deidentified |
| Any Stripe-linked account with a connected account, customer record, or job payment intent | **HOLD** (deletion paused, not attempted) until financial review clears it | `private.stripe_financial_retention_required` gate in the worker, ahead of any DB-level action |
| Storage objects owned by the user (avatars, proof uploads, evidence) | **DELETE** | `service_list_account_deletion_storage_objects` + `storage.remove()` in the worker, before `deleteUser()` |
| Legacy onboarding compatibility snapshot (`private.onboarding_v2_legacy_completion_compatibility`) | **DELETE** (cascades away with the profile) | `ON DELETE CASCADE` on `user_id → profiles(id)`, set in the compatibility migration itself; verified via a two-hop cascade check (`auth.users → profiles → compatibility table`) during the 2026-08-28 Stage 1 pass |
| `auth.users` row itself, and `public.profiles` | **DELETE** | `supabase.auth.admin.deleteUser()`; cascade via `profiles_id_fkey` |

This satisfies the directive's "minimum necessary retention... do not destroy
legitimate safety/dispute evidence" requirement: nothing in the fix deletes
evidence — it only removes the now-orphaned identity pointer on records that
must survive for legal/safety/financial reasons.

## Not yet deployed to hosted

This migration has been validated **locally only**. Per explicit instruction
during this session, it has not been pushed to the hosted project
(`rakjydmgwwgtdislanbt`) and no `supabase db push` / hosted mutation has been
performed. Hosted deployment requires a separate, explicit authorization step
(see the continuation ledger).

## Remaining external legal determination

The migration implements privacy-minimizing SET NULL semantics for legal
acceptance and payment-dispute identity links so deletion works without
retaining an ordinary user pointer. The decision matrix marks those rows
`LEGAL_REVIEW_REQUIRED`: qualified counsel may later require a private
pseudonymous continuity key for post-deletion evidentiary needs. No such key
was invented here, no public legal version was published, and this unresolved
external decision does not reintroduce a deletion blocker.
