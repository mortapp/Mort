# MORT Identity Verification Architecture

Updated: 2026-07-30

## Current Status

The provider-neutral adult identity architecture is implemented and hosted.
Production verification is disabled. No provider is selected, no provider
credentials are configured, MORT does not accept ID uploads, and the public
marketplace remains closed.

Guardian Mode remains optional. Identity verification is a separate adult trust
control and does not turn a guardian into a verifier.

## Trust Boundary

1. An authenticated adult or guardian asks MORT for a production session with a
   client-generated UUID.
2. The database verifies role, DOB, retry budget, idempotency, and the complete
   production-readiness gate before creating a private request.
3. The JWT-protected session Edge Function calls an approved server-side broker.
   Provider credentials never enter Flutter.
4. The broker returns an opaque provider reference and a short-lived HTTPS URL
   on an exact host allowlist.
5. MORT stores only a SHA-256 URL fingerprint and returns the URL once to its
   authenticated owner. The URL is not persisted, logged, emailed, or placed in
   analytics.
6. The provider captures documents on its own hosted surface.
7. The webhook receives the raw body, verifies timestamp and HMAC, normalizes
   status/failure codes, and calls a service-only database function.
8. The database binds provider reference to account, rejects conflicting event
   hashes, treats exact replay as idempotent, updates the trust state, and writes
   a restricted audit event.

No client or ordinary admin can set a verified state. AI is not an identity
decision maker.

## Status Model

The client-facing statuses are:

- `not_started`
- `pending`
- `needs_input`
- `under_review`
- `verified`
- `failed`
- `expired`
- `suspended`

Provider-specific values are mapped server-side. Public status output contains
retry eligibility, a safe failure code, support escalation state, expiration,
and privacy-notice version. It excludes provider references and raw evidence.

## Failure And Retry

- Session attempts are bounded per verification and per time window.
- Client request UUIDs provide payload-bound idempotency.
- Handoff URLs expire within the configured limit and are exact-host checked.
- Safe failure codes cover unavailable providers, rate limits, unreadable or
  expired documents, mismatch, canceled sessions, and unknown failures.
- Provider `requires_input` maps to `needs_input`; processing/manual states map
  to `under_review`; a verified event is accepted only for an adult-bound
  production session.
- Repeated webhook event IDs with the same payload hash return idempotent
  success. The same ID with another hash fails closed.

## Data Minimization And Retention

MORT stores opaque references, normalized state, attempts, timestamps, safe
failure codes, fingerprints, and audit metadata. It does not store raw ID
images, selfies, document numbers, extracted names, provider URLs, or provider
response bodies in ordinary tables.

Private session and webhook metadata have 90-day deletion timestamps. A
service-only retention function removes expired metadata and redacts expired
provider references. Provider-side redaction/deletion must be configured in the
selected vendor before production activation. Financial/legal hold decisions
must be approved before shortening or extending retention.

The historical `verification-uploads` bucket is closed to new authenticated
uploads. Existing objects remain private for controlled retention and owner or
restricted-reviewer access. Legacy business-verification submission is also
closed until the provider-backed path is approved.

## Business Verification

Business verification uses the same server/provider boundary but needs its own
approved provider workflow. The database contains a readiness gate for that
workflow. Direct business document collection and generic admin approval are
disabled. Business identity/KYB is not claimed as implemented by a live vendor.

## Hosted State

- `identity-verification-session`: ACTIVE, JWT verification enabled
- `identity-verification-webhook`: ACTIVE, JWT verification disabled because
  providers authenticate with the signed raw-body webhook contract
- Identity provider secrets: absent
- Runtime mode: disabled by absence/default
- Unauthenticated session request: HTTP 401
- Disabled webhook request: HTTP 503
- Database migrations: aligned through `20260730111500`
- Database lint: no schema errors

## Verification Evidence

The hosted QA proves HTTPS/exact-host handoff validation, signed status mapping,
adult-only session authorization, teen denial, storage closure, private-table
denial, service-only processing, exact replay idempotency, conflicting-payload
rejection, normalized verified state, sandbox isolation, production fail-closed
behavior, expiration, and mutual marketplace trust enforcement.

This is a code-controlled architecture, not a live identity-verification claim.

