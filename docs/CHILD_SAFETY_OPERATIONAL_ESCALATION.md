# Child Safety Operational Escalation — 2026-08-29

## Who can review sensitive CSAE/CSAM-adjacent evidence

**Permanent production rule, no exceptions**: a person under 18 must never
be assigned to review suspected CSAM, graphic sexual evidence involving
minors, sexual-abuse evidence, or similar exploitation material on behalf of
MORT — in production, testing, support, moderation, or internal QA. This
session's own QA work followed that rule: every fixture used in
`qa-account-deletion-*.mjs` and elsewhere is synthetic (`'This is a synthetic
QA test appeal reason...'`-style placeholder text), never real evidence of
any kind.

## Designated adult child-safety contact

`mortapp.help@gmail.com` is the **public** contact address. Whether a
specific, verifiably-adult individual is designated as the operational
reviewer authorized to receive and act on escalated child-safety incidents
was **not verifiable from this repository** — there is no staff-role table
entry, org chart, or onboarding record in the codebase that names a specific
adult in that capacity.

```
EXTERNAL_BLOCKER: DESIGNATED_ADULT_CHILD_SAFETY_CONTACT
```

This does not block engineering work that can still be completed safely
(the technical reporting/blocking/evidence-preservation mechanisms already
exist and are tested — see `CHILD_SAFETY_RESPONSE_RUNBOOK.md`). It does
block any claim that a verified adult-staffed escalation process is fully
operational today. Do not fabricate a name, role assignment, or verification
record to close this gap.

## Adult safety operator verification process

Similarly, whether there's a verification process confirming a staff
member's age/identity before granting them `team_role_assignments` access to
sensitive evidence categories was not found as an implemented control in the
schema — `team_role_assignments` records *that* a role was granted and by
whom, but nothing in the migrations enforces "the grantee is a verified
adult" as a precondition.

```
EXTERNAL_BLOCKER: ADULT_SAFETY_OPERATOR_VERIFICATION_PROCESS
```

Recommended (not implemented here, since it's an operational/HR decision,
not a code defect): require age/identity attestation as part of the
`team_role_assignments` approval flow (`approved_by`, `approval_reason`
columns already exist and could carry this) before granting any role whose
`role_key` implies sensitive-evidence access.

## What this session did verify is real

- The technical reporting, blocking, and evidence-preservation mechanisms
  described in `CHILD_SAFETY_RESPONSE_RUNBOOK.md` (report/block RPCs,
  `incident_preservation_orders`, restricted storage access) — these are
  implemented and tested, not aspirational.
- Core safety features (Report, Block, Safety Ping, Safety Center, basic
  Guardian oversight) are free and not gated behind any membership tier —
  verified against the actual RLS/RPC grants, not just policy copy.
- No NCMEC registration, no fake incident, no fake report was created or
  claimed anywhere in this session's work.
