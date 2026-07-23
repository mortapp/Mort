# MORT Operational Readiness Gates

Status: server-aligned gate register. Current hosted result is not ready and real document collection is false.

## Server authority

`get_document_collection_readiness` reports required, passed, and remaining gates. `private.document_collection_operationally_ready()` is server-owned. Clients cannot set gates or enable collection. The case trigger rejects real-person evidence while readiness is false.

## Required gates

1. Trustworthy adult operating entity
2. Trained reviewers
3. Reviewer background and access policies
4. Written review procedure
5. Written privacy policy
6. Retention schedule
7. Tested deletion procedure
8. Breach-response process
9. Appeal process
10. Two-person approval
11. Storage and RLS QA
12. Legal and privacy review
13. Child-safety review
14. Incident-response staffing
15. Production monitoring
16. Production audit logging
17. Founder/developer raw-document restriction
18. Approved pilot partners

## Evidence to pass a gate

A checkbox is insufficient. Each gate needs an accountable owner, dated evidence reference, environment, scope, approver, expiration/review date, and reversal procedure. Technical tests can support storage/RLS, logging, and two-person enforcement gates; they cannot prove staffing, legal approval, training quality, or trustworthy operations.

## Change control

Any code or dashboard workflow that makes a client capable of enabling collection is a release blocker. Gate changes need separation of duties and immutable audit events. Failure of a continuing condition must disable collection and access promptly.

## Current decision

Keep real identity-document upload, review, and delivery disabled. Do not deploy the prepared vault Edge Function for real evidence, seed real documents, or ask users to send documents through another channel.
