# MORT Phase 8 Report

Updated: 2026-07-29

## Result

Phase 8 code-controlled Support operations are implemented and deployed to the
closed-test backend. Human staffing, staffed hours, guaranteed response times,
resolved real cases, and production external AI are not claimed.

## Delivered

- Expiring, role-separated Support assignments without broad admin inheritance.
- Queue claiming, manager assignment, release, and safety-review boundaries.
- Hosted service status with truthful `Not staffed yet` copy and targets marked
  as non-commitments.
- First-response and urgent-escalation test targets plus service-only backlog
  aging and deduplicated alerts.
- Private forced-RLS internal notes with audited, idempotent writes.
- Requester reopen and one independent linked appeal route.
- Staff-visible audit history and explicit automated-versus-human labels.
- Privacy-minimized structured handoff summaries without raw conversation copy.
- Aggregate-only manager metrics.
- Operations runbook, staffing checklist, and external-AI activation guide.

## Applied Migrations

1. `20260730080000_support_human_operations.sql`
2. `20260730081000_structured_support_handoff_summary.sql`

Both migrations passed a hosted transaction dry run before application. All
149 local migrations align with hosted history through `20260730081000`; a
post-apply dry run reports the remote database up to date.

## Verified Hosted Behavior

- Ordinary admins do not inherit Support access.
- Staff claim/release and manager assignment honor queue and safety roles.
- Internal notes are not requester-readable and are payload-bound.
- Human replies are idempotent and record the first human response.
- Resolved cases can be appealed once through a separately linked case.
- Urgent safety tickets reject ordinary Support-agent ownership.
- Backlog processing is service-only and creates expected aging alerts.
- Manager metrics expose aggregate counts, not private case content.
- Chatbot handoff stores category, classified intent, safety band, message
  count, and summary length while explicitly recording that raw conversation
  content was not copied.

## External Boundaries

- No human Support or safety team is staffed.
- No response target is a public or operational commitment.
- External AI remains disabled and fail-closed.
- Real-case staffing drills, physical-device Support journeys, legal review,
  privacy review, child-safety review, and public-marketplace approval remain
  external gates.

## Verification

| Gate | Result |
|---|---|
| Support chatbot hosted QA | PASS, including structured handoff privacy |
| Support human-operations hosted QA | PASS |
| Canonical hosted regression | PASS, 41/41 scripts in 287.8 seconds |
| Flutter format | PASS, 186 files / 0 changed |
| Flutter analyze | PASS, no issues |
| Flutter test | PASS, 249 passed / 2 expected skips / 0 failed |
| Migration parity | PASS, 149 aligned / 0 mismatches |
| Migration dry run | PASS, remote up to date |
| Database lint | PASS; only disabled identity-provider stub warnings remain |
| Source secret scan | PASS |
| Sensitive-file scan | PASS, 1,744 files / 52 media / 10 protected values |

## Bugs Found And Fixed

1. Every active admin inherited every Support role. Access now requires a
   specific, active, expiring Support assignment or narrowly mapped admin role.
2. The staff screen used an unsupported `enabled` argument on `MortButton`; the
   disabled state now uses the component's null-callback contract.
3. An aging-alert QA fixture changed priority and due time in one update, so the
   response-target trigger correctly replaced the fixture due time. The test
   now performs the state changes in their real order.
4. The handoff QA conflated ticket category `job_application` with classifier
   intent `jobs_or_applications`. It now verifies both independently.
5. Hosted TLS resets could terminate the long canonical run after fixtures had
   cleaned up. The runner now retries only recognized transport failures at the
   isolated script boundary; assertion and authorization failures still stop.
