# MORT Verification Privacy Model

Status: implemented minimization and authorization model with legal and vendor review still required.

## Data Classes

- Public-safe: server-derived trust badge, eligible age band, coarse verification status, and expiration/recheck indicator.
- Account-private: selected route, status history, decision code, appeal state, and marketplace eligibility.
- Restricted: identity evidence metadata, hashes, address-validation result, risk signals, referee request, and reviewer audit history.
- Highly restricted object data: document images, ownership/selfie evidence, address documents, and incident evidence in private Storage.

## Access Model

Users can see their own verification summary but cannot list raw provider records or evidence rows. Other marketplace users, linked guardians, ordinary admins, and support agents cannot access identity objects. Verification reviewers and senior safety moderators receive a metadata-only manifest. Access to a specific object requires a reasoned, short-lived grant and creates an audit event.

## Address Model

MORT stores address-validation outcomes separately from public profile and job-feed data. Exact job locations live in `job_private_locations`, not the public `jobs` payload, and release only to an accepted participant after both sides confirm the current safety agreement. Changing a private location invalidates prior confirmation without hashing or copying the exact address into the agreement snapshot.

MORT must not use a residence to let staff or users personally track someone. Disclosure is limited to documented legal or emergency processes reviewed by authorized staff.

## Storage Controls

- `identity-evidence` and `incident-evidence` are private buckets with MIME and size limits.
- Upload paths begin with the authenticated user ID and the permitted verification or incident ID.
- Registered identity and incident objects cannot be user-deleted through Storage RLS.
- Metadata registration checks Storage ownership before creating the database record.
- Signed URLs are short lived and require an active evidence-specific grant.

## Logging And Minimization

Sensitive access logs record actor, purpose, evidence reference, expiration, and outcome. They do not copy raw document content. Analytics must exclude exact location, private messages, document paths, ID numbers, and sensitive evidence. Client logs and crash reports must never include signed URLs, Storage paths, hashes, tokens, or document text.

## User Rights And Limits

Users receive status, correction, appeal, account-access, and deletion-request paths. Deletion is not immediate when safety preservation, legal hold, fraud prevention, or another documented legal duty applies. The retention draft must be approved before real-user evidence collection.

## Remaining Privacy Work

- Complete a DPIA/PIA and youth privacy review.
- Contractually define provider subprocessors, breach duties, deletion, regional processing, and biometric handling.
- Confirm state, federal, international, school-record, and biometric laws for launch jurisdictions.
- Implement scheduled deletion and evidence disposal verification before collecting real documents at scale.
