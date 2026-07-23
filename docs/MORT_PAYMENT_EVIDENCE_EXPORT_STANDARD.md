# MORT Payment Evidence Export Standard

> **DRAFT — NOT ATTORNEY REVIEWED OR LEGALLY APPROVED**

## Authorized scope

Only a contract party or specifically authorized reviewer may request an export. The server calculates scope from the authenticated user, contract, dispute, and access grants; a client cannot select another user's records.

## Included records

- immutable job contract versions and party confirmations
- approved change requests and confirmations
- amount, due time, preference, and obligation status
- completion assertions, checklist, and authorized proof metadata
- authorized job messages and payment reminders
- payment confirmations and dispute timeline
- decision and appeal status
- evidence hashes, timestamps, source roles, and policy versions
- plain-language classification and legal-information warning

## Exclusions and redaction

Exclude raw IDs, document numbers, face data, unrelated incidents, residential addresses, precise coordinates, other users' private data, reviewer personal data, secrets, internal risk rules, and records outside the requester's authorization. Allegations remain labeled as allegations; platform decisions are not court judgments.

## Integrity

Exports receive a generated timestamp, schema version, record manifest, per-record hashes where available, and overall manifest hash. Export events are audited and cannot modify source records.
