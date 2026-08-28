# MORT Identity Provider Comparison

Updated: 2026-07-30

## Decision

No provider is selected or activated. Stripe Identity is the technical
evaluation front-runner for an initial US adult-only pilot because MORT already
has a server-side Stripe boundary, Stripe documents hosted verification
sessions, idempotency, webhook outcomes, short-lived client handoff, and
redaction. MORT must obtain written provider/use-case approval before relying on
that fit. The current Stripe use-case page restricts some employment-related
and minor verification uses, so MORT cannot infer eligibility from API access.

## Comparison

| Provider | Integration fit | Cost signal on official site | Material gate |
|---|---|---|---|
| Stripe Identity | Hosted sessions, server creation, idempotency, webhook events, retry statuses, redaction | Pay-as-you-go/custom pricing is advertised; exact account pricing must be checked at activation | Written confirmation that MORT's local-hustle marketplace and adult-only trust use are supported |
| Veriff | API sessions, hosted page, HMAC/webhooks, sandbox, broad document geography | Essential currently advertises $0.80 per verification with a $49 monthly minimum; higher tiers add hybrid review and deletion controls | Retention/deletion tier, human-review model, teen-marketplace use, and contract review |
| Persona | Hosted inquiries, configurable flows, webhooks, KYB and case tooling | Essential currently starts at $250/month with a 12-month minimum; startup program terms vary | Cost, retention/redaction configuration, account eligibility, and youth-marketplace approval |

Prices and availability are observations, not contracts. Recheck official
dashboard/account terms immediately before any purchase.

## Security Fit Required From Any Provider

- Server-created sessions and server-only credentials
- One-time or short-lived handoff for the authenticated account owner
- Raw-body webhook authentication with rotation support
- Stable event IDs, retry semantics, and replay-safe reconciliation
- Provider-side document capture; no raw ID in MORT Storage
- Restricted staff access and access logs
- Configurable retention, deletion, and data-subject-request process
- Adult-only workflow and a separate approved business/KYB workflow
- Sandbox that cannot create marketplace eligibility
- Accessibility, mobile Safari/Android support, and recovery for failed capture
- Written confirmation of supported geography, use case, and age boundary

## Official Sources

- Stripe Identity overview: https://docs.stripe.com/identity
- Stripe supported use cases and locations: https://docs.stripe.com/identity/use-cases
- Stripe Verification Sessions: https://docs.stripe.com/identity/verification-sessions
- Stripe go-live guidance: https://docs.stripe.com/identity/before-going-live
- Persona pricing: https://withpersona.com/pricing
- Persona inquiry sessions: https://docs.withpersona.com/api-reference/inquiries/create-an-inquiry
- Persona webhooks: https://docs.withpersona.com/webhooks
- Veriff self-serve plans: https://www.veriff.com/plans/self-serve
- Veriff session API: https://devdocs.veriff.com/apidocs/v1sessions
- Veriff HMAC security: https://devdocs.veriff.com/docs/hmac-authentication-and-endpoint-security
- Veriff webhooks: https://devdocs.veriff.com/docs/webhooks-guide

## Selection Rule

Provider selection requires an owner-approved comparison using current written
terms, an attorney/privacy/child-safety review, provider confirmation of the
use case, a documented retention choice, and a sandbox pilot. No pricing page,
SDK availability, or existing payment relationship is enough by itself.

