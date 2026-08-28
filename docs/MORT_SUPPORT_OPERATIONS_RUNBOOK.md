# MORT Support Operations Runbook

Updated: 2026-07-29

## Current Operating State

MORT Support is implemented for closed testing, but it is not staffed and no
human response time is guaranteed. The hosted service-status RPC returns the
configured hours label `Not staffed yet` and states that response targets are
not commitments. The automated assistant remains available through the
deterministic, approved-knowledge path. It does not dispatch emergency services
or make moderation, identity, hiring, payment, legal, or medical decisions.

## Queue Ownership

- `support`: ordinary account, profile, marketplace, and how-to cases.
- `billing`: payment-preference, MORT Plus, and store-billing questions.
- `privacy`: deletion and privacy requests.
- `trust_safety`: reports and serious or urgent safety handoffs.

Staff access requires an active, unexpired assignment in
`private.support_staff_assignments` or a narrowly mapped active
`admin_role_assignments` row. A generic `profiles.role = 'admin'` value grants
no Support access. Only a Support manager can assign another worker. Urgent
safety cases require a Support manager or safety reviewer.

## Case Procedure

1. Sign in with an individually assigned staff account. Never share accounts.
2. Open the staff queue and claim an eligible unassigned case, or receive a
   manager assignment. Confirm the queue and safety priority before reading.
3. Review the privacy-minimized handoff summary, requester-visible messages,
   authorized attachments, and audit history. Do not copy unrelated user data
   into notes.
4. Add internal notes only when operationally necessary. Notes are staff-only,
   audited, request-idempotent, and must not contain secrets, job PINs, identity
   documents, or unsupported conclusions.
5. Post a clearly human-labeled reply. Use only facts visible in the authorized
   case and approved policy. Never claim emergency dispatch or guaranteed
   resolution.
6. Move the case through `open`, `pending`, `resolved`, or `closed` only when
   the recorded action supports the transition. Release ownership when another
   queue or specialist must take over.
7. A requester may reopen an eligible case or create one appeal. Appeals are a
   separate case linked to the original and require independent review.

## Safety Escalation

- Immediate danger: show the hosted emergency guidance and advise the user to
  contact local emergency services or a trusted nearby adult. MORT does not
  claim to call or dispatch help.
- Serious or urgent safety: route to `trust_safety`; only a manager or safety
  reviewer may own the case.
- Preserve authorized evidence and the audit trail. Do not delete or alter
  evidence to make a queue cleaner.
- A human safety owner, on-call schedule, legal escalation policy, and real
  response commitments are external launch gates and do not exist yet.

## Backlog And Aging

`support_process_backlog_aging` is service-role-only and runs from the hosted
`mort-support-backlog-aging` cron every five minutes. It creates deduplicated
alerts for overdue first responses, overdue urgent escalations, and cases that
have waited on staff for 24 hours. Staff clients cannot invoke the worker.

The manager dashboard returns aggregate queue, priority, aging, and alert
counts. It intentionally does not return message bodies, evidence paths, user
identifiers, or raw conversations. Targets in the current policy are internal
test thresholds, not promises, while `targets_are_commitments` is false.

## Incident Procedure

1. Stop unsafe staff access by expiring or disabling the assignment; do not
   change a user's profile role as a substitute.
2. Preserve ticket events, action audit, internal-note hashes, attachments, and
   relevant correlation IDs.
3. Disable external AI provider use if its output, privacy, budget, or
   availability boundary is in doubt. Deterministic fallback must remain live.
4. Record the affected queue, time window, safe symptoms, and containment. Do
   not place raw user content in shared incident channels.
5. Notify the named privacy, safety, or engineering owner once those people
   have formally accepted the role.
6. Repair through additive migrations or reviewed Edge Function changes, run
   the canonical hosted regression, and document the result.

## Shift Handoff

No shift process is active because staffing is not established. Before any
staffed pilot, require named incoming and outgoing owners to review aggregate
overdue counts, urgent cases, unassigned cases, open appeals, provider status,
and active incidents. Handoffs belong in private audited notes, not requester
messages or external chat tools.

