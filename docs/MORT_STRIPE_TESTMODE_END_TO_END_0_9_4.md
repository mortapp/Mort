# MORT Stripe Test-Mode End-to-End Report 0.9.4

Date: 2026-07-23

## Honest status

Stripe functions are bundled and deployed, but this run did not have the
server-side Stripe test secret, publishable key, webhook secret, operations
secret, or an enabled Stripe mode. The server runtime reports payments disabled.
No Stripe provider request, charge, capture, refund, transfer, payout, onboarding
session, chargeback, or live transaction was created in this sprint.

This is a verified application/database boundary with a fail-closed provider
state. It is not Stripe end-to-end completion and is not live-payment readiness.

## Deployed functions

- `stripe-config`
- `stripe-create-connected-account`
- `stripe-create-job-payment-intent`
- `stripe-create-job-refund`
- `stripe-create-job-transfer`
- `stripe-create-onboarding-link`
- `stripe-get-connected-account-status`
- `stripe-resolve-job-payment`
- `stripe-webhook`

Every function rechecks server runtime controls. Mobile input cannot select an
authoritative amount, currency, destination, transfer, refund, environment, or
entitlement. Errors use safe codes and correlation IDs.

## Verified scenarios

| Scenario | Actual result | Status |
|---|---|---|
| Client amount forgery | Amount derived from accepted server obligation | PASS |
| Payment idempotency | Database claim plus provider idempotency contract | PASS |
| Saved-payment consent | Versioned, caller-bound, revocable consent | PASS |
| Webhook raw-body signature contract | Verified before dispatch | PASS |
| Duplicate/replayed webhook | Event ID and payload hash prevent mutation | PASS |
| Invalid signature | Rejected by function contract | PASS |
| Refund boundary | Service-only, bounded, idempotent | PASS |
| Transfer eligibility | Requires funded completion and eligible payout state | PASS |
| Transfer duplication | One transfer plus provider idempotency | PASS |
| Transfer reversal representation | Webhook-only reconciliation | PASS |
| Resolution role separation | Reviewer and financial operator separated | PASS |
| Connect status privacy | Provider IDs excluded from public profile/status | PASS |
| Flutter safe disabled state | Payments-disabled status shown; provider action blocked | PASS |

The complete static/remote boundary suite passed 25/25 files. Payment resolution
and financial-queue boundaries also passed in the hosted regression.

## Provider scenarios not run

The following remain `BLOCKED_NOT_RUN`: SetupIntent, 3DS/authentication-required,
authorization, full capture, partial capture, cancellation, provider refund,
webhook retry from Stripe CLI, Connect onboarding, payout restriction, dispute
or chargeback event, and transfer reversal event. No event IDs exist for this
run because creating fake IDs would be misleading.

## Required owner actions

1. Configure Stripe test-mode credentials only as Supabase Edge Function secrets.
2. Keep `MORT_STRIPE_MODE=test`; never put secrets in Flutter, Expo, `.env.local`,
   Git, screenshots, archives, or shell transcripts.
3. Configure the test webhook endpoint and exact event allowlist.
4. Enable payments only in a dedicated isolated test window.
5. Run every blocked scenario with Stripe test cards and Stripe CLI; record real
   redacted event IDs, database transitions, UI states, retries, and reversals.
6. Disable payments again, revoke temporary operator roles, and rerun the 25-file
   boundary suite plus secret scans.

Live mode remains prohibited pending provider approval, legal/tax/privacy review,
real-device QA, operational staffing, incident exercises, and explicit owner
authorization.
