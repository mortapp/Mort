# MORT Verify threat model

Last audited: 2026-09-20

## Assets

The highest-sensitivity assets are raw school-ID images/PDFs, school email addresses, age evidence, reviewer access, and verification decisions.

## Adversarial cases and controls

| Threat | Control |
|---|---|
| Cross-user upload path | Storage path must start with the authenticated user ID and reference that user's live session. |
| Path traversal / malformed path | Exact four-segment path shape, UUID checks, extension allowlist, and traversal rejection. |
| MIME or extension spoofing | Server downloads the uploaded object and validates magic bytes, detected MIME, extension, size, and SHA-256 before registration. |
| Reading another teen's raw ID | No general authenticated SELECT policy on canonical evidence. |
| Reviewer role revoked after assignment | Raw-document service helper re-checks the reviewer's current safety role at signed-URL request time. |
| Stale reviewer assignment | Assignment must be unrevoked and unexpired; review decisions require the same. |
| Verification-code database leak | Only an HMAC-SHA256 digest of the eight-digit code is stored; raw code is generated/delivered server-side. |
| Online code guessing | Challenge expiry, attempt cap, resend cooldown, and hourly issuance cap. |
| School email treated as age proof | School-email verification only advances to school-ID collection; final age proof requires independent reviewer evidence. |
| Ordinary reviewer uses age exception | `manual_exception` requires a current senior safety moderator role. |
| Approval without evidence | School/age approval requires a verified school email, active front document, current reviewer role, and active assignment. |
| Accidental production activation | Canonical control row defaults disabled with all collection/review gates false. |
| Legacy bypass | Superseded authenticated RPCs are revoked and legacy Storage policies are removed. |
| Raw evidence retained indefinitely | Canonical and legacy buckets are covered by service-only scheduled retention cleanup with preservation/active-review exclusions. |
| Migration drift | Hosted canonical migration history was reconciled to the source migration timestamps after byte-equivalence verification. |

## Deliberate limitations

MORT Verify does not perform liveness, biometric face matching, or government-identity proofing. It must not be represented as proving legal identity.

Email delivery depends on protected provider configuration. Production collection is intentionally off until that operational dependency and the external legal/privacy/reviewer gates are approved.

A real authenticated-device upload/review exercise remains a release-validation activity; static controls are designed to fail closed if the provider or activation prerequisites are missing.
