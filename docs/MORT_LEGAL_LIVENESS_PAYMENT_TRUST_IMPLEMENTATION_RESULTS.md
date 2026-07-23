# MORT Legal, Payment, and First-Party Trust Implementation Results

Date: 2026-07-19  
Remote project: `rakjydmgwwgtdislanbt`

## Status boundary

This is an implemented and remotely tested foundation. It is not attorney approved, legally approved, production-ready, Mac compiled, iPhone tested, TestFlight tested, or App Store reviewed.

- Public marketplace access remains closed behind existing pilot and trust controls.
- Hosted real-person identity-document collection remains disabled.
- External document web-reuse processing remains disabled.
- Real live-presence capture remains disabled.
- Real appearance review remains disabled.
- Synthetic QA does not create authoritative identity verification.
- Guardian Mode remains optional.
- Payment is preference and evidence tracking only; MORT does not process, hold, escrow, or guarantee payment.

## Research and draft corpus

- Legal-pattern corpus: 300 distinct official URLs, 300 records, 113 organizations, and all 16 requested categories.
- Corpus validator: passed with no duplicate official URLs.
- Legal drafts: 25 of 25 requested documents exist and contain the exact `DRAFT — NOT ATTORNEY REVIEWED OR LEGALLY APPROVED` banner.
- Runbooks: missing-person, abduction, sexual-safety, nonpayment, lawful-request, and data-breach procedures exist as unapproved operational drafts.
- Team operations: role matrix, training curriculum, confidentiality, reviewer readiness, security-advisor scope, volunteer expectations, and paid-work compliance hold exist.

No claim was made that 1.9 million agreements were reviewed. The corpus uses summaries and original MORT drafting rather than copied agreement language.

## Hosted backend

Additive migrations `20260719050000` through `20260719050600` implement the legal, contract, payment, first-party trust, team, RLS, RPC, legal-catalog, and index foundations. Repair migrations add:

- `20260719061004`: validates every payment-dispute restriction input before any decision, timeline, dispute, or restriction write.
- `20260719061607`: gives only a currently assigned and ready reviewer access to the assigned synthetic web-reuse result without relying on subject-only RLS joins.
- `20260719070500`: covers the three remaining foreign keys on `poster_payment_restrictions` reported by the Performance Advisor.

The local and remote migration ledgers are aligned through `20260719070500`.

## Legal and payment behavior

- Legal acceptance is affirmative, published-version-bound, content-hash-bound, role/age-aware, and written only through a checked RPC.
- Material legal revisions create a separate reacceptance requirement.
- Every accepted job creates an immutable versioned job agreement.
- Amount, scope, hours, location, hazards, expenses, and payment timing cannot be changed by one party alone.
- Payment due, poster-marked-sent, and worker-confirmed-received remain distinct.
- A nonpayment report remains a private allegation and never creates an automatic guilt, criminal, court, lawsuit, or recovery result.
- A trained assigned reviewer may apply a private, bounded, appealable payment restriction after a qualifying evidence review.
- Evidence exports are party-authorized and exclude raw identity documents, document numbers, face data, residences, precise coordinates, unrelated incidents, other users' private data, and secrets.
- Official remedy links are conditional legal information only. MORT does not choose claims, prepare individualized pleadings, promise recovery, or provide representation.

## First-party trust behavior

- Capture-quality, web-reuse, live-presence, appearance-review, reviewer assignment, and team-access schemas and server contracts exist.
- Development and QA are synthetic-only. No real ID or real face-video fixture was created.
- A web match is only a review signal. No match does not prove a document genuine.
- A live-presence result is only a limited signal. Camera movement does not prove legal identity.
- Consequential synthetic appearance mismatches require two independent trained reviewers.
- Reviewer evidence access requires role readiness, training, confidentiality, device readiness, case assignment, purpose, and expiry.
- Founder, admin, family, friend, cybersecurity-advisor, or group-chat status alone grants no raw evidence access.

## Clients

SwiftUI source now includes legal center, teen summary, contract review/change, payment status, nonpayment/dispute/export, capture explanation, live-presence explanation/accessibility, team access, reviewer assignment, LocalAuthentication, sensitive-action gating, and app lock. Static audit passed with 105 app source files and 11 unit-test files. Xcode compilation and physical iPhone testing were not performed on Windows.

Flutter Web/PWA includes legal center/clickwrap, teen summary, contract/payment/dispute/export screens, browser-safe disabled capture, disabled liveness explanation, genuine WebAuthn capability explanation, and optional Guardian Mode copy. Format, analysis, 73 tests, and the release web build passed with IAP and ads disabled.

## Defects found and fixed

1. Payment-dispute review could validate restriction expiry after earlier writes. Validation is now atomic and occurs before writes.
2. Assigned reviewer web-reuse RLS depended on joins through subject-only policies. A narrow private assignment predicate now enforces the intended access.
3. Three `poster_payment_restrictions` foreign keys lacked covering indexes. Additive indexes removed all new-foundation unindexed-FK findings.
4. `NSFaceIDUsageDescription` used older wording. It now contains the required device-only legal-identity limitation.
5. Payment QA did not directly prove publication restriction or outsider export denial. Both assertions now run against the hosted database.

## Remaining external gates

Licensed counsel must review minor capacity, clickwrap, arbitration/class-action choices, liability, indemnity, labor classification, wage and small-claims information, privacy, biometric law, retention, law-enforcement requests, and jurisdiction-specific representation rules. Child-safety, insurance, trained reviewer, incident-response, vendor, data-processing, and accessibility reviews also remain.

Real identity collection must stay disabled until those reviews, an authoritative provider, vendor terms, retention/deletion enforcement, reviewer operations, breach response, and physical-device QA are complete. Payment restrictions must not launch for real users until legal classification, appeals, reviewer staffing, official-resource maintenance, and abuse/retaliation operations are approved.
