# MORT Safety And Guardian State Machine

Updated: 2026-07-29

## Operating Boundary

MORT provides software safety workflows. It does not monitor continuously,
dispatch emergency services, guarantee a human response, or physically
intervene. Emergency guidance is loaded from hosted jurisdiction configuration;
the current US/Indiana configuration directs immediate danger to `tel:911`.

## Safety Actions

Every report, block, unblock, Safety Ping, and active-job check-in mutation is
authenticated, server-authorized, request-idempotent, and payload-bound. Direct
authenticated writes to the underlying action tables are denied.

| Action | Allowed transition | Required boundary | Result |
|---|---|---|---|
| Report | new request -> case created | bounded details, supported target/category, caller context | private report, preservation marker, triage band, staff alert for high/critical risk |
| Block | unblocked -> blocked | caller cannot target self; stable request/payload | contact and visibility restrictions applied |
| Unblock | blocked -> unblocked | block must belong to caller | active block removed without deleting its audit history |
| Safety Ping | new request -> sent | bounded non-address note; optional authorized job; routine or immediate | recipient-scoped event and narrow Guardian delivery when explicitly authorized |
| Check-in | scheduled -> completed | assigned participant, active job, unexpired request | immutable completion time |
| Missed check-in | scheduled -> missed -> escalated | server worker after due/grace time | private incident signal and authorized safety-staff alert |

Routine and urgent safety budgets are separate. Retrying an identical request
does not consume a second allowance or create a duplicate record. Reusing a
request ID with changed content fails closed.

## Deterministic Triage

The server classifies bounded text into `routine`, `concern`, `serious`, or
`urgent`. Active physical danger, child exploitation indicators, credible
weapons threats, and self-harm emergency language bypass ordinary chatbot
handling and create a human safety case. Contextual rules avoid escalating
benign phrases such as ordinary kitchen-knife use or a staple gun used for a
job. Triage is routing support, not a diagnosis or final allegation finding.

## Active Job Check-ins

Successful start-PIN confirmation creates a default 60-minute check-in cadence
when a job has no explicit cadence. Participants can list only their authorized
job check-ins, complete a due check-in idempotently, or schedule the next
bounded check-in. The server worker marks overdue rows missed and creates one
escalation. Canceled or completed jobs cannot receive new check-ins.

## Guardian Mode

Guardian Mode is optional and never automatically enabled. A connection moves
through `invited -> active -> revoked` using explicit invitation and acceptance.
The teen controls narrow per-link sharing preferences and can unlink without
losing ordinary account access. The server records invite, acceptance,
preference, revocation, and age-transition audit events.

An active link can expose only approved safety information. It does not expose
ordinary job chat, private Support conversations, report evidence, exact
location, identity documents, or administrative data. Guardian status never
grants staff or admin privileges. At age 18, visibility stops immediately and
the age-transition worker revokes and audits the stale link.

## Evidence And Privacy

Reported-message evidence remains preserved after participant visibility is
restricted. Exact street addresses are rejected from Safety Ping notes and are
not copied into staff alerts. Alerts contain stable record identifiers and safe
codes, not raw private messages or evidence. `pilot_job_reviews` remains a
service-only operational boundary with no authenticated table grant or user RLS
path.

## Verified Coverage

- report and ping replay, payload substitution, routine caps, and urgent budget
- block/unblock ownership and replay
- message-report evidence preservation and outsider denial
- start-PIN default cadence, completion, replay, isolation, missed escalation,
  late completion, terminal cancellation, and direct-write denial
- Guardian skip, invite, acceptance, preferences, unlink, unrelated access
  denial, age transition, audit history, and Support/chat denial
- deterministic routine/concern/serious/urgent false-positive and false-negative
  cases
- authorized staff alerting without claims of physical response

