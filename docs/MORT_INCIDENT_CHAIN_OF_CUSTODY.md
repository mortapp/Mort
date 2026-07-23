# MORT Incident Chain Of Custody

Status: technical and operational specification. It does not certify forensic admissibility.

## Event Record

For each evidence item, maintain:

- incident and case number
- evidence UUID and type
- submitting user or system source
- private bucket and object path, visible only under authorization
- content type and byte size
- SHA-256 value when supplied/verified
- submission and registration timestamps
- retention and preservation status
- each access grant, reason, actor, start, expiration, and revocation
- each export, transfer, receipt, transformation, redaction, and disposal event

## Capture

The authenticated participant uploads to a user/incident-scoped private path. `register_incident_evidence` verifies ownership, expected path, MIME type, size, participant status, and hash format before metadata registration. The incident timeline records receipt without copying raw content.

## Review

Metadata-first review limits unnecessary exposure. Only authorized incident staff can receive a short-lived object grant, and each grant requires a reason. Reviewers must not rename, edit, annotate, or recompress the source object. Working copies, if counsel approves them, receive a new identifier and hash linked to the source.

## Transfer Manifest

A production manifest should contain evidence ID, source hash, export hash, byte count, UTC export time, exporting operator, approved legal/request reference, recipient, secure transfer method, and receipt confirmation. Secrets, signed URLs, service credentials, and unrelated records are excluded.

## Integrity Interpretation

Matching hashes show that two byte sequences match. They do not establish authorship, truth, device time, location, intent, or absence of prior manipulation. Human and legal review must avoid overstating hash evidence.

## Access Failure

If an object is missing, hash mismatches, a grant is misused, or an unauthorized copy is suspected:

1. stop further access and preserve logs
2. open a security/incident event
3. identify affected evidence and users
4. notify security, legal, and child-safety owners as applicable
5. assess breach and reporting duties
6. document correction without overwriting the original audit trail

## Disposal

Disposal requires approved retention status, absence of active holds, authorized operator, object deletion, metadata minimization/deletion as approved, backup/subprocessor handling, and a final disposal event. Ordinary users cannot delete registered preserved evidence.
