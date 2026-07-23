# MORT Operational Runbooks 0.9.4

Date: 2026-07-23

These runbooks are code-controlled preparation. No staffed incident exercise or
database restore drill was performed in this sprint. For imminent danger or a
missing person, users and operators must contact local emergency services; MORT
is not an emergency service.

## First response for every incident

1. Open an incident record with UTC timestamps and a correlation ID.
2. Protect people first. Use the narrowest emergency controls that contain risk:
   maintenance, payments disabled, AI disabled, publishing disabled, and public
   marketplace closed.
3. Restrict affected accounts/sessions through authorized server paths. Do not
   change roles or evidence directly from a client.
4. Preserve immutable audit events and authorized evidence. Do not copy raw
   teen data, identity media, exact locations, PINs, messages, or secrets into
   chat, email, tickets, or screenshots.
5. Assign incident, teen-safety, security, privacy, legal, communications, and
   service owners as applicable. Record every decision and rollback condition.

## Suspected data breach

- Detect: unusual cross-user reads, Storage access, service-role use, export,
  advisor change, or user report.
- Contain: maintenance mode; revoke affected sessions and operator grants;
  rotate exposed credentials; preserve database, Storage, Auth, and function logs.
- Recover: patch authorization, rerun isolation and history scans, notify only
  under qualified legal/privacy direction, and reopen no feature before approval.

## Exposed secret

- Revoke/rotate the credential at its provider before editing documentation.
- Search current files, Git history, archives, CI/EAS/Supabase settings, logs,
  screenshots, and distributed artifacts without printing the value.
- Redeploy affected server functions and rerun secret, authorization, and abuse
  tests. Mobile-bundled server secrets require a new signed build and takedown.

## Supabase outage

- Enable maintenance and publishing/payment circuit breakers if server control
  is reachable; otherwise use provider status/controls and public status notice.
- Do not fall back to local authority, cached roles, client prices, or offline
  mutations. Preserve retry intent only for idempotent user actions.
- After recovery, verify migration parity, Auth, RLS, Storage, Realtime, RPCs,
  queues, and delayed notifications before clearing maintenance.

## Stripe outage or payment duplication

- Keep payments disabled. Do not retry capture/refund/transfer manually from the
  app and do not promise settlement.
- Freeze affected payment/transfer records, preserve webhook hashes and provider
  IDs privately, and reconcile through idempotent server operations.
- Require separate factual reviewer and financial operator for resolution. For
  suspected duplication, confirm provider truth before any compensating action.

## Failed or restricted payout

- Keep work, safety, and dispute records separate from provider eligibility.
- Add a redacted payout-restriction alert; show the user a truthful action-needed
  state without exposing provider internals.
- Only an authorized operator may retry after requirements and legal/guardian
  representation are confirmed in test-approved or production-approved mode.

## AI provider outage or unsafe output

- Set AI provider disabled. Deterministic help and human support remain free and
  available; never synthesize a fake AI reply.
- Preserve redacted category/latency/failure records, not prompts containing
  private cases. Review moderation, quotas, tool boundaries, and provider budget
  before controlled re-enable.

## Unsafe job or abusive adult

- Pause the job, prevent new applications/messages as authorized, preserve
  participant evidence, and route to trained safety review.
- Keep reporter identity and exact teen location private. Apply restrictions by
  reasoned server action with appeal; do not treat verification as a safety guarantee.
- Escalate imminent danger to emergency services under approved policy.

## Fraudulent teen or account abuse

- Restrict the account through the same documented, appealable process used for
  adults. Do not disclose a minor's allegation publicly or apply collective penalties.
- Preserve job/payment facts, separate safety exit from reputation effects, and
  route financial decisions through role-separated review.

## Missing teen or missed safety check-in

- Treat as safety-critical and follow the user's approved Safety Circle grants.
- Attempt authorized contact without revealing exact location to unapproved users.
- Escalate to emergency services according to trained policy; record every contact,
  disclosure basis, and recipient. MORT must not promise location or rescue capability.

## Account takeover

- Revoke sessions, require secure password reset/email verification, review
  account security events, and temporarily restrict high-impact actions.
- Reverse no job/payment decision solely from a client claim. Restore access only
  after ownership and safety review; notify affected participants with minimal data.

## Evidence access incident

- Revoke grants/signed URLs where possible, suspend evidence access roles, and
  preserve Storage/audit logs. Never download more evidence to investigate access.
- Determine object, actor, purpose, time, and recipient; rotate related secrets;
  follow qualified privacy/legal notification guidance.

## Emergency marketplace shutdown

- Set maintenance as needed, payments disabled, publishing disabled, AI disabled,
  and confirm public marketplace closed. Existing safety/report/support paths
  should remain reachable unless the outage itself makes them unsafe.
- Verify ordinary users cannot change controls, new jobs fail with a safe code,
  operator acknowledgement is audited, and status copy is truthful.

## Rollback

- Never use destructive Git reset or reverse a migration without reviewed SQL and
  a current backup. Prefer forward fixes.
- Capture current migration/function versions, backup/checksum, affected records,
  and rollback approval. Keep marketplace and providers disabled through QA.
- Rerun schema lint, migration parity, 30-check isolation, Storage, rate-limit,
  payment boundary, moderation, deletion, Flutter, and artifact scans.

## Database restore

Use `docs/MORT_RESTORE_DRILL_GUIDE.md`. Restore only into an isolated approved
target, validate checksums and migration order, keep all provider/public controls
off, and do not call preparation a successful drill.

## Closure requirements

Record root cause, affected scope, user-safety outcome, evidence authorization,
notifications, control changes, tests, owner approvals, follow-up deadlines, and
the exact criteria used to reopen. Complete `docs/MORT_INCIDENT_EXERCISE_TEMPLATE.md`
only for an actual dated exercise or incident.
