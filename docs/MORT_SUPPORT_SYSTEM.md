# MORT Support System

Status: implemented for closed testing with deterministic fallback and a real
human-operations queue. The queue is not staffed and no response time is
guaranteed.

- Searchable approved help articles and guided categories.
- Private support conversations, messages, links, expiring staff assignments,
  queue ownership, status events, audit records, appeals, feedback, and
  attachments.
- Case references use the `MORT-CASE-...` format.
- Requesters cannot assign themselves, impersonate staff, or mutate staff-owned state.
- Support evidence uses a private bucket, ownership checks, manifests, short-lived signed URLs, and server rate limits.
- Email fallback opens a draft to `mortapp.help@gmail.com`, includes the case reference and account context, warns against sending secrets, and never claims receipt or automatic attachment import.
- Safety-critical language diverts to the Safety Center/emergency guidance and a human-support route.
- Admin support access is assignment- and role-authorized; an ordinary admin
  does not inherit Support access.
- Serious and urgent safety cases require a Support manager or safety reviewer.
- Internal notes are private, forced-RLS records and do not appear in requester
  ticket payloads.
- Service-only aging creates deduplicated backlog alerts; manager metrics are
  aggregate and exclude message/evidence content.
- Automated and human replies are labeled distinctly. Requesters may reopen an
  eligible case or create one linked appeal.
- Structured assistant handoffs store category, intent, safety band, and counts
  without copying the raw conversation into queue metadata.

External AI is disabled. Support remains functional through deterministic FAQ
search, guided help, case creation, evidence upload, and queue escalation. See
`MORT_SUPPORT_OPERATIONS_RUNBOOK.md`,
`MORT_SUPPORT_STAFFING_READINESS_CHECKLIST.md`, and
`MORT_EXTERNAL_AI_ACTIVATION_GUIDE.md`.
