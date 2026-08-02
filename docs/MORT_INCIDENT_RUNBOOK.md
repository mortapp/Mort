# MORT Incident Runbook

Status: technical procedure. Named on-call owners, legal counsel, trained child-safety staff, and notification channels are BLOCKED-EXTERNAL.

## Severity

| Severity | Examples | Initial action target |
|---|---|---|
| SEV-0 | credible immediate danger, child sexual safety event, active credential exfiltration | close affected capability immediately; contact trained emergency/legal owner |
| SEV-1 | cross-user data access, Auth/RLS bypass, active account takeover, unsafe public activation | contain within 15 minutes once staffed |
| SEV-2 | deletion backlog, moderation backlog, push outage, elevated errors, failed safety workflow | contain within 4 hours once staffed |
| SEV-3 | isolated non-safety defect with workaround | triage next business day |

Targets are proposed and are not evidence of staffed coverage.

## First response

1. Record UTC/local time, reporter, affected environment/version, and a redacted correlation ID.
2. Protect people first. Do not ask a teen to confront another participant or gather more evidence.
3. Close the smallest affected capability using reviewed kill switches or account restrictions.
4. Preserve relevant audit rows and object metadata; never paste messages, addresses, IDs, tokens, or evidence URLs into ordinary chat/log channels.
5. Rotate compromised provider/server credentials. Do not rotate the upload key unless its private material is compromised.
6. Assign incident commander, safety lead, security lead, communications/legal lead, and scribe. One person must not approve their own sensitive action.

## Scenario actions

### Suspected RLS or data exposure

- Close public marketplace and affected endpoint/function.
- Reproduce with synthetic accounts only.
- Export minimal schema/policy evidence and query affected audit logs.
- Patch additively, back up first, and rerun the complete isolation suite.
- Determine notification obligations with qualified counsel before contacting users.

### Teen safety or grooming signal

- Restrict the reported account and prevent further direct contact when authorized.
- Preserve evidence under least privilege and chain-of-custody controls.
- Escalate to trained child-safety/legal owners; do not make criminal findings in product labels.
- Keep guardian contact contextual and follow emergency disclosure/mandated-reporting policy after approval.

### Immediate danger or urgent Safety Ping

- Show the hosted jurisdiction emergency action and state clearly that MORT has
  not contacted or dispatched emergency services.
- Create one idempotent urgent case and one privacy-minimized alert for an
  authorized safety role; never include exact location or raw message content
  in the alert payload.
- Keep ordinary chatbot quota and ordinary support backlog from blocking the
  urgent path.
- Do not promise monitoring, a response time, rescue, or physical intervention.

### Missed active-job check-in

- Confirm the server worker marked a scheduled row missed only after its due and
  grace window and created no duplicate escalation.
- Review the job state and narrow authorized status record. Do not ask another
  participant or guardian to confront anyone or travel to the location.
- If the available facts indicate immediate danger, use the urgent procedure;
  otherwise route to trained safety review when staffing exists.
- Preserve the check-in and alert audit rows. Do not copy exact locations into
  ordinary tickets, logs, or chat channels.

### Account deletion failure

- Inspect redacted `last_error_code`, attempt count, and queue age.
- Confirm the worker secret and function deployment without revealing either.
- Retry through the idempotent worker; never delete database rows manually as a shortcut.
- Escalate requests at five attempts for least-privilege operator review.

### Credential or signing exposure

- Revoke the affected Supabase/provider credential immediately and audit use.
- Secret-scan source, archives, logs, CI, and release artifacts.
- For upload-key compromise, use Play Console key-reset procedures and preserve certificate evidence.

## Recovery

Recovery requires the original failing journey, focused regression, full RLS/backend regression, signed artifact verification where applicable, and a recorded owner decision. Public features stay closed during uncertainty.

## Post-incident

Within five business days after staffed operation, document impact, timeline, root cause, control failures, remediation owner/date, evidence retention, user/legal decisions, and follow-up tests. Use synthetic/redacted evidence in engineering records.
