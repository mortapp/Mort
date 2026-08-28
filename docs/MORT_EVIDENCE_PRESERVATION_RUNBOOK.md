# MORT Evidence Preservation Runbook

Status: implemented technical foundation with operational and legal approval still required.

## When To Preserve

Preserve a bounded record set for serious threats, sexual or child-safety concerns, abduction/person mismatch, assault, coercion, blackmail, stalking, active fraud, account sharing, evidence tampering, or a validated legal preservation request. Do not preserve everything by default merely because a routine support issue exists.

## Immediate Steps

1. Confirm or create the restricted `safety_incidents` case.
2. Identify report, message, attachment, job, application, participant, location-release, arrival, check-in, block, and notification records relevant to the event.
3. Register uploaded evidence with object owner, content type, size, SHA-256, submitter, incident, and retention metadata.
4. Ensure the underlying Storage object remains private and user deletion is denied after registration.
5. Record a restricted timeline event describing scope, not raw content.

## Formal Hold

An incident manager or legal-request reviewer uses `place_incident_preservation_hold` with legal basis, scope, and future expiration. The RPC marks the incident, extends evidence preservation, and records the action. A hold must be reviewed before expiration and released only through an approved process.

## Access

Start with `get_incident_evidence_manifest`, which omits Storage paths. A reviewer states a case-specific reason in `authorize_incident_evidence_access`; the short-lived grant and access event are recorded before the path can be used. Do not download to unmanaged devices or copy evidence to ordinary tickets, chat, email, analytics, or model-training systems.

## Integrity

Recalculate and compare the stored hash after export or transfer. A hash proves byte consistency only; it does not prove who created the material, when the depicted event occurred, or that content is authentic. Record tool, operator, source, destination, timestamp, and result.

## Release And Disposal

Before release, check for overlapping incident, appeal, child-safety, litigation, regulator, or legal-request holds. On authorized disposal, delete the object and eligible metadata in a controlled transaction/job, record outcome without reproducing content, verify backup/subprocessor expiration, and alert on partial failure.

## QA Evidence

`scripts/qa-evidence-preservation.mjs` verifies that a serious report produces preserved metadata, a submitting user cannot remove the registered Storage object, unprivileged users cannot read it, and reviewer access requires a logged grant.

## Remaining Operations Work

Assign 24/7 ownership, approve hold/release forms, train reviewers, integrate secure export/transfer, implement scheduled disposal, test restore/backups, and run legal/safety tabletop exercises before real-user evidence collection.
