# MORT Verification Retention Policy Draft

Status: draft for counsel, privacy, security, and trust-and-safety approval. It is not a final legal retention schedule.

## Current Technical Defaults

- Identity evidence metadata receives a default `retention_delete_at` of 30 days after registration.
- Incident evidence metadata receives a default `retention_delete_at` of 180 days.
- Serious incidents can set `preserved_until`; a legal hold can extend it through a documented preservation order.
- Verification decisions, minimal result codes, expiration, appeals, and audit events persist separately from raw evidence so the service can explain eligibility and access history.

The database has retention timestamps and indexes, but an approved scheduled deletion worker and disposal attestation process are still required. A timestamp alone does not delete an object.

## Proposed Schedule

| Record | Proposed baseline | Hold/exception | Disposal requirement |
| --- | --- | --- | --- |
| Unregistered failed upload | Immediate cleanup or short orphan window | Security investigation | Delete Storage object and record outcome |
| Identity document/selfie object | Delete after review plus approved short challenge window, targeting no more than 30 days | Active appeal, fraud investigation, safety preservation, or lawful hold | Delete private object and verify deletion |
| Identity evidence metadata/hash | Minimum period needed for integrity, duplicate review, and audit | Appeal, fraud, legal duty | Delete or irreversibly minimize under approved schedule |
| Verification status/result | Account life plus approved audit period | Litigation, regulator, or safety hold | Remove unnecessary result detail; retain only justified record |
| Address document | Same or shorter than identity evidence | Active dispute or legal hold | Delete object; retain only validation result if justified |
| Verification audit event | Approved security/audit period | Investigation or legal hold | Retain purpose and actor without raw evidence |
| Incident evidence | 180-day baseline is configured | Serious-safety preservation or legal hold | Controlled deletion with chain-of-custody event |

## Hold Rules

Only incident managers or legal-request reviewers may place preservation holds. A hold requires legal basis, bounded scope, start, expiration, and an audit event. Holds are not permanent by default. Release requires authorized review and must never silently delete evidence that remains subject to another hold.

## User Requests

Account deletion requests trigger identity verification of the requester, dependency review, and a record-by-record retention decision. MORT should explain what was deleted, what was retained, the category of reason, and the next review date without exposing investigative details.

## Required Before Real Users

- Counsel-approved schedule by jurisdiction and record type.
- Scheduled Storage and database deletion worker with idempotency and failure alerts.
- Backup expiration alignment and subprocessor deletion obligations.
- Disposal logs that avoid recreating sensitive content.
- Periodic sample audit proving expired, unheld evidence is actually removed.
