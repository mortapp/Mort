# MORT Phase 11 Report

Updated: 2026-07-30

## Result

The provider-neutral adult identity-verification architecture is implemented,
deployed, and verified against the hosted Supabase project
`rakjydmgwwgtdislanbt`. Production verification remains disabled and no real
identity documents were collected.

## Applied Migrations

1. `20260730110000_identity_provider_neutral_completion.sql`
2. `20260730111500_identity_fail_closed_lint_hardening.sql`

Both migrations passed hosted transaction dry runs before application. Local
and remote migration history align through `20260730111500`; post-apply dry run
reports the database up to date.

## Deployed Functions

- `identity-verification-session` version 1, ACTIVE, JWT verification enabled
- `identity-verification-webhook` version 11, ACTIVE, provider-signed webhook
  authentication, JWT verification intentionally disabled

All identity-provider configuration/secrets are absent. The functions fail
closed with HTTP 401 for an unauthenticated session and HTTP 503 for the
disabled webhook path.

## Verified Behavior

- Server-authorized adult/guardian session requests with bounded retry and
  idempotency
- Short-lived HTTPS handoff with exact-host and userinfo rejection
- URL fingerprint storage rather than provider URL persistence
- Signed, timestamped, payload-bound webhook validation
- Normalized statuses and bounded safe failure codes
- Exact webhook replay returns idempotent success; payload substitution fails
- Account/provider/session binding and adult-only verified state
- Private session, webhook, and retention metadata
- Closed direct identity/business document uploads
- Closed generic admin and client verification approval
- Honest Flutter status, privacy, retry, support, and external handoff UI
- Sandbox remains QA-only, document-free, and never marketplace eligible
- Public marketplace and production verification remain disabled

## Verification

| Gate | Result |
|---|---|
| Provider-neutral hosted QA | PASS |
| Legacy business provider-required QA | PASS |
| Legacy verification suites | PASS, 12/12 |
| Flutter provider tests | PASS, 5/5 |
| Flutter analyze | PASS, no issues |
| Database lint | PASS, no schema errors |
| Migration parity | PASS, aligned through `20260730111500` |
| Session endpoint without JWT | PASS, HTTP 401 |
| Webhook while disabled | PASS, HTTP 503 |

## Bugs Found And Fixed

1. The session Edge Function persisted but did not return the opaque request ID;
   the response now includes it for safe correlation.
2. Duplicate signed webhook delivery previously returned an error; exact replay
   now returns idempotent success while conflicting payload hashes fail closed.
3. The historical business flow still accepted direct documents in MORT
   Storage; new uploads and legacy submission/approval paths are closed.
4. The first synthetic QA used multiple SQL commands in one prepared statement;
   commands are now executed separately.
5. The QA cleanup assertion queried an intentionally unexposed private schema
   through PostgREST; it now verifies the control row through the database QA
   channel.
6. Database lint found unused compatibility-stub inputs. A forward migration
   explicitly consumes those legacy arguments without opening their fail-closed
   behavior; final lint is clear.

## External Gates

- Provider selection, use-case approval, contract, pricing, and credentials
- Legal, privacy, biometric, child-safety, and retention review
- Business/KYB workflow decision
- Sandbox provider and real-device capture testing
- Reviewer staffing, training, and incident drill
- Production approval and separate public-marketplace decision

This phase implements and verifies the code-controlled boundary. It does not
claim live provider verification or production readiness.
