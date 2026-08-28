# MORT Moderation Operations

Updated: 2026-08-01

Status: code-controlled architecture and targeted hosted QA verified; real
staffing, training completion, legal approval, named public contacts, incident
on-call coverage, and production verification provider are not connected.

## Launch boundary

- Trust/safety architecture: implemented.
- Actual identity provider verification: not connected.
- Real ID collection: disabled.
- Sandbox verification: QA only.
- Guardian Mode: optional.
- Public marketplace: closed until production verification and operations evidence exists.

## Roles and separation

| Role | Allowed scope | Prohibited scope |
|---|---|---|
| Intake moderator | triage reports, restrict ordinary content/account access | raw identity evidence, irreversible financial/security actions |
| Safety specialist | child-safety escalation and bounded evidence review | self-approve appeals or preservation release |
| Identity reviewer | provider/manual exception review with reason codes | platform/security administration |
| Appeals reviewer | independent appeal review | review their original decision |
| Security operator | incidents, access revocation, credential response | decide content/identity case outcome alone |
| Admin | operational queue and audited authorized actions | generic service-role access from a client dashboard |

New role assignments must include an expiry between one hour and 30 days.
Legacy unbounded assignments are a hard public-activation blocker. The old
client grant path can revoke roles but cannot create new assignments or grant
super-admin. Staff sessions still require ordinary Supabase Auth; no role can
be created from an untrusted mobile client.

## Queue coverage

Existing restricted queues cover user/job/message reports, urgent safety,
harassment, grooming/sexual safety, scam/fraud, prohibited jobs, identity
exceptions, evidence, disputes, support tickets and AI-response reports,
appeals, deletion failures, payment incidents, and technical/operational
incidents. Queue schemas differ by domain so evidence and financial data do not
flow into a generic client-admin table.

Shared operational capabilities include scoped assignment, status, priority,
bounded internal notes, restricted evidence previews, redaction or minimized
projections, related entity history, audit trails, reason-coded enforcement,
assignment expiry, appeals, aging alerts, and aggregate dashboards. Available
code does not prove that any human is watching these queues.

## Coded moderation actions

- Job moderation uses `admin_moderate_job`; allowed actions and reason codes are
  checked by the server and recorded in the audit log.
- Review moderation uses `admin_moderate_review`; direct client update is not an
  enforcement path.
- Sensitive case detail uses `admin_get_moderation_record` and records an
  access event before returning the least-privilege projection.
- Bans cannot be restored by the ordinary status RPC. A user submits an appeal,
  a specialized independent reviewer claims it with a two-hour assignment, and
  only that active assignee can approve reversal or deny it.
- The original banning actor cannot claim or decide the reversal.
- Suspensions require a supported reason code and bounded expiry.

Founder/developer status does not grant unrestricted evidence or service-role access.

## Queue priorities

| Priority | Examples | Proposed target |
|---|---|---|
| P0 immediate safety | credible imminent harm, sexual exploitation signal, doxxing/exact-address exposure | immediate staffed escalation |
| P1 severe abuse | adult-minor boundary violation, threats, coercion, account takeover | 15 minutes once coverage exists |
| P2 marketplace safety | unsafe job, harassment, repeated off-platform pressure | 4 hours once coverage exists |
| P3 quality/policy | spam, misleading listing, ordinary appeal | 1 business day |

Targets are proposals, not evidence of current staffing.

## Decision procedure

1. Validate authorization and conflict status.
2. Minimize evidence access; open only what is necessary.
3. Record structured reason code and a neutral factual note.
4. Restrict contact/content while investigating when authorized and proportionate.
5. Require a second qualified reviewer for high-impact identity, safety, preservation, or permanent-account actions.
6. Notify the user only with approved, non-sensitive language and preserve appeal access.
7. Record the audit event and retention/preservation basis.

Do not label a person a criminal, infer guilt from an automated signal, or let AI approve identity, disputes, compensation, law-enforcement disclosure, or permanent bans.

## Before public activation

- Hire or contract enough trained staff for shift coverage, separation of duties, appeals, and leave.
- Complete scenario assessments and time-bounded access approvals.
- Approve youth-safety, mandated-reporting, emergency disclosure, evidence, appeals, and bias-review policies with qualified counsel.
- Connect the production identity provider and validate expiry, rejection, exception, and appeal flows.
- Exercise SEV-0/SEV-1 runbooks and measure queue/alert delivery.
- Obtain executive/legal sign-off through an audited reversible activation control.

The database now enforces this boundary. Public activation also requires
approved document versions and hashes, Indiana/US legal entries, named contacts,
moderation staffing, incident on-call, Play declarations, production identity,
production-public policy, and zero unbounded active staff assignments. The
ordinary app and admin RPC surface cannot set those approvals. All remain false.
