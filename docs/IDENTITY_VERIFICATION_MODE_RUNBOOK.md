# Identity Verification Mode Runbook

## Current Hosted State

Mode is `disabled`. Provider configuration, signed webhook, legal approval, retention readiness, operational readiness, and trained-reviewer readiness are false. Production readiness is false.

Keep this state until every production prerequisite has written approval.

## Disabled

- Public identity submissions remain unavailable.
- Do not request or collect government ID, school ID, passport, selfie/liveness, address document, or student number.
- Direct Storage upload, table insert, and evidence-registration RPC paths remain denied.
- Public marketplace actions requiring identity verification remain closed.
- Existing isolated QA data cannot become production eligibility.

Client copy must remain:

> Identity verification is not accepting public submissions yet.

> MORT is still preparing its secure verification system. Do not upload an ID or personal document.

## Sandbox

Sandbox may be enabled only for a controlled QA window by an authorized server operator. It is not a document test environment.

- Only accounts explicitly marked as test accounts can create a simulation.
- Display `TEST MODE` and `Test verification - do not use real documents.`
- Do not create Storage objects.
- Confirm all records have `environment=sandbox` and `production_eligible=false`.
- Confirm sandbox users/jobs are invisible to ordinary accounts.
- Restore hosted mode to `disabled` when QA ends.

## Production Entry Gate

Do not enable production until all items are complete:

1. Approved provider contract and production SDK/API configuration.
2. Signed provider webhook secret installed server-side only.
3. Approved age/identity workflow and account-binding design.
4. Documented retention, deletion, preservation, and data-subject request process.
5. Youth, biometric/privacy, employment, and jurisdiction-specific legal approval.
6. Operational monitoring, incident response, provider outage, replay, and reconciliation procedures.
7. Trained reviewers, least-privilege assignments, access recertification, and audit review.
8. Physical-device, TestFlight, accessibility, recovery, and adverse-result testing.
9. App Store privacy disclosures and user-facing consent/deletion language.

Production requires both Edge Function configuration and the private database readiness constraint. Flutter, Swift, ordinary admins, and client-issued SQL/RPC calls must never be used to change this mode.

## Emergency Disable

If provider integrity, webhook validation, privacy handling, or operations are in doubt, authorized server operators must return both controls to `disabled`, preserve relevant audit events, stop new verification sessions, and investigate before reactivation. Existing production status must be reviewed for revocation or expiry based on the approved incident procedure.

