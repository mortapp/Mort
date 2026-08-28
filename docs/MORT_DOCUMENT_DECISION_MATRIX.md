# MORT Document Decision Matrix

Status: decision-language draft. Collection is disabled and no row authorizes a live upload.

| Evidence and completed validation | Maximum supported result | Must not claim | Escalation |
| --- | --- | --- | --- |
| Email confirmation link | Email ownership confirmed | Legal identity, age, safety | Account recovery anomalies |
| Phone challenge | Phone ownership confirmed | Legal identity, age, stable ownership | Recycled/changed number |
| Approved school/program signal | School affiliation confirmed | Government identity | Conflicting affiliation |
| Authorized partner attestation | Exact attested fact | Facts outside staff authority | Revocation or conflict |
| Visual document inspection | MORT document reviewed | Authenticity or legal identity automatically | Mismatch, unusual format |
| Evidence supports age band | Age evidence reviewed | Full identity | Boundary/exception case |
| Official business registry match | Business registration matched | Representative identity or safety | Inactive/conflicting registry |
| Cryptographic government credential with issuer validation | Government digital credential verified | Safety or future validity | Issuer/revocation failure |
| Approved identity provider result | Provider-backed identity verified | Guarantee beyond provider assurance | Provider error or mismatch |

## Outcome states

Use `document_uploaded`, `document_review_pending`, `document_reviewed`, `age_evidence_reviewed`, `affiliation_reviewed`, `authenticity_not_authoritatively_validated`, `additional_information_required`, `rejected`, `appeal_pending`, or `expired` as appropriate. Public copy must remain narrower than internal observations.

## Two-person cases

Unusual government documents, identity mismatches, suspected forgery, account sharing, teen manual exceptions, alternative evidence for a youth without conventional documents, rejection with marketplace consequences, and permanent identity-based restriction require reviewer A and independent reviewer B. Reviewer B cannot be reviewer A.
