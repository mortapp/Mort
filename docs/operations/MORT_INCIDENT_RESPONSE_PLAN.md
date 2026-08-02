# MORT Incident Response Plan

This plan supplements `docs/MORT_INCIDENT_RUNBOOK.md`. Technical containment
paths exist; named on-call, legal, privacy, communications, and trained
child-safety owners are `CODE-COMPLETE / STAFFING REQUIRED`.

## Declare And Contain

1. Record UTC time, release profile/version, reporter, and a redacted correlation ID.
2. Protect people first; never ask a teen to investigate, confront, or preserve new evidence.
3. Close the smallest affected capability. Public marketplace remains closed by default.
4. Preserve audit records and object metadata under least privilege; do not paste message, location, ID, proof, or token content into normal channels.
5. Revoke exposed credentials, invalidate sessions where justified, and keep a chain of custody.
6. Assign incident commander, safety, security, privacy/legal, communications, and scribe roles. Require two-person review for high-impact actions.

## Severity

- SEV-0: immediate danger, child sexual safety event, or active credential/data exfiltration.
- SEV-1: cross-user access, Auth/RLS bypass, takeover, unsafe public activation.
- SEV-2: safety/support/deletion backlog, push outage, elevated errors.
- SEV-3: isolated non-safety issue with a workaround.

Response targets in documentation are proposals until staffing and paging are
verified. MORT must never claim emergency dispatch or continuous monitoring.

## Recover

Recovery requires reproduction with synthetic accounts, additive repair,
focused regression, complete RLS/backend regression, signed artifact checks,
privacy/safety review, and a recorded go/no-go decision. Public/provider gates
remain closed during uncertainty.

