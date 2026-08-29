# Child Safety Response Runbook — 2026-08-29

Procedural text only. No explicit abuse evidence, real incidents, or
identifying details belong in this document — it describes the process, not
any specific case.

## Scope

Applies to reports or signals involving: suspected CSAE/CSAM, grooming,
sexual solicitation of a minor, sextortion, trafficking, sexual jobs,
adult-minor sexual conduct, attempts to bypass safety controls, retaliation
against a reporter, or repeat contact after a block/restriction.

## 1. Intake

Reports arrive via: in-app Report (on a profile, job, message, or user),
in-app Block, Safety Ping, the Safety Center, or the public contact address
`mortapp.help@gmail.com`. All in-app paths are free and available without a
paid membership tier (Phase 61 — safety is never premium).

## 2. Triage

An authorized adult reviewer (see
`CHILD_SAFETY_OPERATIONAL_ESCALATION.md` for who qualifies) classifies
severity using the same triage bands already implemented in
`private.support_classify_message` and the incident-severity model
(`safety_incidents.severity`, `priority`). Immediate-danger signals
(`immediate_danger = true`) get priority handling; MORT is not an emergency
service and does not replace contacting local emergency services.

## 3. Immediate danger

If a report indicates a minor is in immediate danger: the reviewer's first
action is to advise the reporter/subject to contact local emergency services
directly — MORT is not continuously monitored and cannot dispatch help.
Internal account restriction and evidence preservation proceed in parallel,
not instead of that advice.

## 4. Account restriction

An authorized adult can restrict an account's marketplace access pending
review (`account_status`, `poster_payment_restrictions`, existing
moderation tooling). Restriction does not require proving guilt first — it
is a precautionary safety measure, reversible on appeal.

## 5. Evidence handling

- Do not ask a reporter (especially a minor) to resend or re-describe
  explicit material as "proof" — this itself risks creating/distributing
  CSAM. Written description of context is sufficient for triage.
- Suspected CSAM is never emailed, forwarded, downloaded to a personal
  device, or pasted into a support ticket, chat log, or AI tool. If evidence
  already exists in the product's own storage (e.g., an uploaded image
  flagged by a report), it stays in the product's restricted storage — an
  authorized adult reviews it there under the product's existing
  access-restricted evidence flow (`AUTHORIZED_ADULT_ACTION`), not by
  copying it elsewhere.
- `evidence_registration_idempotency_and_lint.sql`,
  `protect_registered_incident_evidence_objects.sql`, and the
  `incident_preservation_orders` table are the existing technical
  preservation mechanisms — use them, don't build a parallel one.

## 6. Legal reporting decision

Whether a specific report triggers a mandatory legal reporting obligation
(e.g., to NCMEC or law enforcement, depending on jurisdiction) is a
`LEGAL_REVIEW_REQUIRED` decision for an authorized adult with actual legal
authority to make — this runbook does not pre-decide it, and this session
did not fabricate or claim an existing NCMEC reporting relationship. MORT
does not currently have a verified operational NCMEC reporting pipeline;
until `CHILD_SAFETY_OPERATIONAL_ESCALATION.md`'s `DESIGNATED_ADULT_CHILD_SAFETY_CONTACT`
gap is closed, this is an active `EXTERNAL_BLOCKER`, not a solved process.

## 7. Retention

Preservation-classified evidence follows `incident_preservation_orders`
(`legal_hold` flag on `safety_incidents`) — retained as long as a legal or
safety hold requires, independent of whether the reported/subject account is
later deleted (see the FK matrix: incident/safety tables deidentify the
person link on deletion but retain the record).

## 8. Appeal boundaries

An account subject to a safety restriction can appeal
(`account_ban_appeals`, `appearance_review_*`). Appeal review is by a
different authorized reviewer where practical. Appeal does not automatically
restore access — a reviewer decision is required. Appeals do not reopen or
require re-disclosure of the underlying evidence to the appellant if doing
so would itself create a safety risk (e.g., identifying a minor reporter).
