# MORT First-Party Document Review Standard

Status: future operational draft. Real-person document collection is disabled. This standard does not authorize uploads or constitute legal approval.

## Truth rule

Encryption protects data; it does not prove authenticity. Visual review does not by itself prove legal identity, account ownership, or issuer validity. A reviewed item receives only the label supported by the evidence, such as `MORT document reviewed`, `Age evidence reviewed`, or `Affiliation reviewed`.

`Government identity verified` requires documented authoritative issuing-source validation, a cryptographically verifiable government digital credential, an approved authoritative data source, or another reviewed high-assurance method. School affiliation and device biometrics do not meet that standard.

## Preconditions

No real upload may begin unless every readiness gate passes and server policy explicitly enables collection. Clients cannot enable it. Reviewers must be trained, assigned to a case, conflict-checked, least-privileged, and operating under written privacy, retention, deletion, incident, appeal, and access procedures.

## Review flow

1. Create a case with purpose, evidence category, environment, decision impact, and retention basis.
2. Store evidence in the separate private vault using a random object identifier and no original filename.
3. Record hash, MIME type, size, retention-delete date, preservation status, and audit event without copying evidence into public records or logs.
4. Assign reviewer A; require a conflict check before access.
5. Reviewer A records observations, established fact, non-established fact, recommendation, reason, and limitations.
6. High-impact cases require reviewer B's independent decision. Self-approval is blocked.
7. Publish only the precise outcome label and limitation, never raw evidence.
8. Provide an appeal path and preserve evidence only as allowed by the retention policy.

## Neutral treatment

Possible forgery, mismatch, or account sharing is a review condition, not an automatic accusation of a crime. Request only the minimum additional information needed and avoid collecting unrelated sensitive details.

## Current state

The hosted upload RPC returns `real_document_collection_disabled`; readiness reports collection false and client enablement false. QA uses synthetic metadata only. No real IDs, selfies, passports, school IDs, or sensitive documents belong in fixtures, logs, source archives, or support tickets.
