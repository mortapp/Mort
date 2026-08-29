# Data Retention Registry — 2026-08-29

Purpose-based retention (no invented fixed day-counts beyond what the schema
already encodes, e.g. `account_ban_appeals.expires_at` default `+30 days`).
Cross-references `docs/ACCOUNT_DELETION_FK_MATRIX.md` for the exact per-column
deletion/deidentification mechanism — this registry summarizes by data
category; the matrix is the authoritative per-column source.

| DATA | PURPOSE | ACTIVE_ACCOUNT_RETENTION | POST_DELETE_ACTION | LEGAL_OR_SAFETY_EXCEPTION | IMPLEMENTATION | OWNER |
|---|---|---|---|---|---|---|
| Account identity (email, display name, DOB, role, user ID) | Authentication, eligibility enforcement | Until account deletion | Deleted (`auth.users` hard delete cascades to `profiles`) | None — this is the one category with no retention exception | `auth.admin.deleteUser()`; `profiles_id_fkey` CASCADE | Engineering |
| Profile content (avatar, bio, preferences, availability, transportation) | Marketplace functionality | Until account deletion or user edits it | Deleted (CASCADE, or storage object removed by the deletion worker) | None | Deletion worker `removeOwnedStorage`; `profiles` cascade | Engineering |
| Jobs, applications, contracts | Marketplace functionality | Indefinite while active; historical record after completion | **Deidentified, not deleted** — the shared record (scope, terms, timestamps, status) survives for the counterparty; only the deleted party's identity link is severed | Shared-participant retention: deleting one party must not destroy the other's legitimate history | `jobs.poster_id`/`applications.teen_id` SET NULL with close-out (unfinished work closed/terminalized first) | Engineering |
| Messages | Job-context communication, safety evidence | Per `support_user_preferences.retention_days` where configurable; otherwise indefinite while the thread is relevant | Author identity deidentified; message content may survive if flagged as safety evidence | Safety/moderation evidence preservation | `message_safety_evidence.sender_id` SET NULL | Engineering |
| Reviews | Trust signal for other marketplace participants | Indefinite (shared record) | Author identity deidentified where the review references a still-active counterparty's history | Shared marketplace history | Same pattern as jobs/applications | Engineering |
| Reports, blocks, moderation actions | Trust & safety enforcement | Indefinite | **Deidentified subject, content retained** — a report/action record surviving deidentified enables pattern detection (repeat-offender signals) without retaining an ordinary user pointer | Safety/moderation evidence | `incident_actions.actor_id`, `appearance_review_*`, etc. — all class B in the FK matrix | Trust & Safety |
| Legal acceptances (policy type, version, hash, timestamp) | Prove what was presented/accepted and when | Indefinite | Content retained; acceptor identity deidentified | `LEGAL_REVIEW_REQUIRED` — see the FK matrix's dedicated section on whether a pseudonymous continuity key is needed | `legal_acceptances.user_id` SET NULL | Legal (pending review) |
| Payment disputes and evidence | Resolve real-world payment disagreements MORT records but does not process | Indefinite (dispute/financial record) | Content retained; party identity deidentified | `LEGAL_REVIEW_REQUIRED` — same open question as legal acceptances | `payment_disputes.*` SET NULL | Legal (pending review) |
| Stripe-linked records (connected account, customer, payment intent) | Would support future real payment processing; currently dormant sandbox foundation | Until account deletion, gated by the financial-retention hold | **Hold** — deletion is paused (not attempted) while any of these three tables has a row for the user, until a human/financial process clears it; SET NULL is the fallback once cleared | Active financial exposure requires human review before deletion proceeds | `service_check_account_deletion_financial_retention` in the deletion worker | Finance/Engineering |
| Active staff/team role assignments | Live authorization to perform staff actions | Until revoked or the account is deleted | **Deleted with the account** (CASCADE) — a live grant must not survive as an orphaned row | None — authorization cannot outlive the account holder | `team_role_assignments.user_id` CASCADE, matching `support_staff_assignments`/`stripe_financial_role_assignments` precedent | Engineering |
| Historical staff access audit | Security audit trail (who accessed what, when) | Indefinite | Content retained; actor identity deidentified | Security audit value outlives the individual staff member's tenure | `team_access_audit_events.user_id` SET NULL | Security |
| Guardian connections (active) | Guardian oversight authorization for a teen account | Until either party deletes their account or the link is unlinked | **Deleted with either account** (CASCADE) | None — guardian authorization cannot outlive either participant | `guardian_connections.teen_id`/`.guardian_id` CASCADE | Engineering |
| Guardian connection history/audit | Historical record that a guardian relationship existed | Indefinite | Content retained; teen identity deidentified | Same class as other historical audit trails | `guardian_connection_audit_events.teen_id` SET NULL | Engineering |
| Storage objects (avatars, proof, evidence) | Feature functionality, dispute/safety evidence | Until account deletion | **Deleted directly** (not just DB-cascaded) — explicit `storage.remove()` before `deleteUser()` | Evidence-classified uploads follow the same evidence-preservation logic as their referencing record, not a blanket delete | `service_list_account_deletion_storage_objects` + `storage.remove()` | Engineering |
| Push notification tokens | Notification delivery (currently dormant — `RemotePushEnabled=false`) | Until revoked, token rotation, or account deletion | Deleted with the account | None | `push_tokens` CASCADE | Engineering |
| Diagnostics/crash data | Not currently collected (`CrashReportingEnabled=false`) | N/A | N/A | N/A | N/A — re-populate this row when crash reporting activates | Engineering |
| Legacy onboarding compatibility snapshot | Preserve pre-v2 completion status for historically completed accounts | Until account deletion | Deleted with the account (CASCADE) | None | `private.onboarding_v2_legacy_completion_compatibility` CASCADE, verified two-hop (`auth.users → profiles → snapshot`) | Engineering |

## What this registry deliberately does not do

- **No invented fixed retention periods.** Where the schema doesn't encode an
  exact duration (e.g., "reports are kept 7 years"), this registry describes
  purpose-based retention ("until account deletion," "indefinite as shared
  history") rather than fabricating a number no one has actually approved.
- **No blanket "safety table = keep forever."** Every safety/moderation/legal
  row above still loses its identity link on deletion (class B in the FK
  matrix) unless a specific, named reason (the financial hold; live
  authorization) requires otherwise.
