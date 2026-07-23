# MORT Mutual Identity Verification Architecture

Status: provider-safe trust architecture implemented. Actual production provider verification is not connected. Real identity collection is disabled. Sandbox verification is isolated QA only. Guardian Mode is optional. The public marketplace remains closed wherever production verification is mandatory.

This document is not a claim that verification guarantees safety or that MORT is production-ready.

## Product Boundary

- A current production verification result is required before public users can perform marketplace actions that require identity assurance.
- Guardian Mode is optional and independent from identity verification.
- Business verification supplements, but does not replace, the business owner's personal identity verification.
- Safety education, reporting, blocking, Safety Ping, appeals, and emergency guidance are not verification or payment gated.
- A local upload, pending evidence, sandbox simulation, expired result, or manually altered row never produces a production badge.

## Server-Controlled Modes

The private `identity_verification_control` singleton accepts `disabled`, `sandbox`, or `production`. It is not exposed to `anon` or `authenticated` roles.

- `disabled`: current hosted mode. Public submissions and all direct identity-document uploads are rejected.
- `sandbox`: only `is_test_account=true` QA users may create document-free simulated sessions. Every record is labeled `environment=sandbox` and cannot satisfy production eligibility.
- `production`: blocked by a database constraint unless provider configuration, signed webhook, approved workflow, retention policy, legal approval, operational readiness, and trained-reviewer readiness are all true.

Flutter, Swift, ordinary admins, and client table writes cannot switch the mode.

## Provider Boundary

Both clients define `IdentityVerificationProvider`, `VerificationSession`, `VerificationResult`, `VerificationEnvironment`, `VerificationEvidenceType`, `VerificationDecision`, and `VerificationFailureReason`.

Implemented providers:

- `DisabledVerificationProvider`
- `SandboxVerificationProvider`
- `ProductionVerificationProvider` interface with an unavailable implementation

There is no connected production vendor. A production result can only be accepted through the server-only provider-result RPC after the signed webhook validates the provider, production environment, account binding, decision, age band, level, expiry, timestamp, event ID, and payload hash.

## Verification Records

`identity_verifications` records include environment, provider, provider reference, decision source, verification level, status, creation time, verified time, and expiry. Existing legacy/manual rows were classified as sandbox and marked production-ineligible.

Production eligibility requires all of the following:

- `environment=production`
- `status=verified`
- a non-null `verified_at`
- a current, nonexpired result
- `decision_source=provider_webhook` or a separately approved manual-exception process
- a non-local provider

No approved manual-exception process is active in the hosted configuration.

## Evidence And Storage

MORT currently collects no government ID, school ID, passport, selfie/liveness image, address document, or student number for identity verification.

- Direct identity-evidence RPC registration is fail-closed.
- The private `identity-evidence` bucket has no authenticated insert, update, copy, move, delete, or list path.
- Sandbox sessions are simulations and create no document object.
- Guardians and ordinary admins cannot access raw identity evidence.
- Specialized production reviewer access remains unavailable because production readiness and trained-reviewer records are absent.

Job proof and incident evidence are separate product data classes and retain their existing private Storage controls; they are not identity verification.

## Marketplace Enforcement

`private.has_current_production_identity` is the authority for production eligibility. Public marketplace feed policies and action RPCs require a current production result. Isolated QA jobs remain visible only to eligible test accounts and never appear in ordinary production feeds.

`get_public_trust_badges` requires authentication, returns only minimized trust state, and has no anonymous execution grant. It returns no document path, identity metadata, student identifier, government identifier, or residential address.

## Client States

Disabled clients display:

> Identity verification is not accepting public submissions yet.

> MORT is still preparing its secure verification system. Do not upload an ID or personal document.

Eligible sandbox QA clients display:

> Test verification - do not use real documents.

Production UI remains unavailable until the backend reports a ready approved provider session.

## Remaining Gates

- Select and contract an approved age/identity provider.
- Complete youth, biometric/privacy, employment, retention, deletion, and jurisdiction-specific legal review.
- Approve a verification workflow and provider data-processing terms.
- Configure a production webhook secret only in the Supabase server environment.
- Establish trained reviewer procedures, access recertification, incident response, quality review, and deletion operations.
- Complete App Store privacy disclosures, TestFlight validation, Xcode compilation, and physical-iPhone testing.

