# MORT Data Retention and Deletion Matrix

Status: engineering implementation matrix requiring legal/privacy approval before real users.

The account-deletion processor suspends the profile, revokes sessions, removes objects owned by the Auth user, deletes the Auth identity, and relies on foreign keys/cascades for ordinary account data. Safety, fraud, dispute, and audit records may remain only under an approved de-identification/legal-retention rule.

| Data class | Examples | Deletion action | Proposed retention | Approval/status |
|---|---|---|---|---|
| Auth identity/sessions | Auth user, refresh sessions | Revoke immediately; delete Auth user | At processing | Implemented and QA verified |
| Public/private profile | name, DOB-derived role, bio, preferences | Delete by Auth cascade; de-identify retained references | At processing | Implemented technically; legal review needed |
| Device/push state | tokens, notification preferences | Delete/revoke | At processing | Data path exists; remote push not production-connected |
| Owned storage | avatars, proof, report/support uploads | Server lists and deletes user-owned objects | At processing unless preservation hold | Implemented and QA verified |
| Drafts/saved jobs/applications | user-scoped marketplace state | Delete by ownership/cascade where applicable | At processing | Schema behavior QA required per release |
| Messages/conversations | message body and participant rows | Delete or de-identify where legally permitted; preserve only under approved safety hold | Undefined until legal approval | BLOCKED-EXTERNAL |
| Jobs/contracts/completion | work terms, lifecycle history | De-identify account identifiers; retain minimum needed for disputes/legal duty | Undefined | BLOCKED-EXTERNAL |
| Reports/blocks/safety pings | safety and abuse records | Preserve minimally with user identifiers pseudonymized when possible | Undefined | BLOCKED-EXTERNAL |
| Evidence/disputes | proof, nonpayment, incident evidence | Delete unless active preservation/legal duty; access logged | Undefined | BLOCKED-EXTERNAL |
| Guardian links | invitations, approvals, linkage | Delete/unlink | At processing | Technical cascade must remain covered by regression |
| Support records | tickets and attachments | Delete or redact, except active legal/safety matter | Undefined | BLOCKED-EXTERNAL |
| Admin/audit/security logs | actions, auth/security signals | Pseudonymize; retain minimum immutable record | Undefined | BLOCKED-EXTERNAL |
| Payment schema | obligations/provider event records | No launch processing; retain only test/future compatibility records | No real-user data allowed in closed test | Payments disabled |
| Account deletion request | status, attempts, redacted error, summary | Retain de-identified completion record | Proposed 2 years | Legal approval required |

## Processor controls

- Service-role RPCs are not executable by anon/authenticated clients.
- Worker invocation uses a separate high-entropy server-only secret and constant-time comparison.
- Processing locks claims, revokes sessions first, retries stale work, caps attempts at five, and records redacted error codes.
- Storage removal is bucket/path based and batched.
- QA proves unauthorized rejection and actual Auth/storage/profile removal.

## Required decisions before real users

- Approve exact periods by jurisdiction and record type.
- Define preservation holds, appeal rights, emergency disclosure, litigation hold, tax/labor requirements, and deletion exceptions.
- Validate every foreign-key cascade and retained identifier against the approved matrix.
- Add queue-age monitoring, named operator ownership, and data-subject response procedures.
