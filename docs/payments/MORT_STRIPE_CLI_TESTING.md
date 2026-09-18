# Stripe CLI Testing

Task 31 uses Stripe **test/sandbox mode only**. It does not authorize live payments, live credentials, real card data, or ordinary CI provider mutations.

## Before any provider action

Run the ordered Task 30 gate first:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stripe-pre-provider-test-gate.ps1 -WhatIf
```

The gate must pass before any provider mutation is attempted. MORT's sandbox mutation flags remain deliberately fail-closed until an approved QA window; the Task 31 runner does not enable them.

## Webhook layout

The deployed test webhook is:

```text
https://rakjydmgwwgtdislanbt.supabase.co/functions/v1/stripe-webhook
```

MORT intentionally keeps platform and Connect event subscriptions separate even though they target the same URL.

Platform payment/money-movement events include:

- `payment_intent.succeeded`
- `payment_intent.processing`
- `payment_intent.requires_action`
- `payment_intent.payment_failed`
- `payment_intent.canceled`
- dispute, transfer, and refund events used by MORT

Connect events include:

- `account.updated`
- payout lifecycle events used by MORT

The webhook verifies the appropriate platform or Connect signing secret before routing the event. A browser return, client callback, or PaymentSheet completion is never provider truth.

## Stripe CLI diagnostics

`scripts/stripe-listen-test.ps1` and `scripts/stripe-trigger-test-events.ps1` are **diagnostic helpers only**.

Both are fail-closed by default. Add `-Execute` only in an approved sandbox diagnostic session.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stripe-listen-test.ps1
powershell -ExecutionPolicy Bypass -File scripts/stripe-trigger-test-events.ps1
```

Generic CLI fixtures may omit MORT contract, quote, settlement, participant, or tip metadata. Therefore a generic `stripe trigger` result can demonstrate signature/routing behavior, but it **cannot count as a passing MORT Task 31 end-to-end scenario**.

The listener can display a temporary webhook signing credential. Keep that only in a protected sandbox shell or secret store and never redirect listener output into evidence, source control, screenshots, or logs.

## Payment test inputs

Automated payment tests use Stripe-provided **test PaymentMethod identifiers**, not card numbers.

Examples used for scenario planning:

- `pm_card_visa` — successful card path
- `pm_card_visa_chargeDeclined` — declined card path
- `pm_card_chargeCustomerFail` — decline path suitable when the PaymentMethod must attach to a Customer
- `pm_card_authenticationRequired` — authentication / requires-action path

These are test-only identifiers. The Task 31 evidence file never stores PaymentIntent client secrets, card numbers, full provider object IDs, API credentials, or raw provider payloads.

## Controlled Task 31 runner

The controlled runner is:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stripe-sandbox-e2e.ps1
```

Without explicit provider execution, the runner records that provider E2E was not run. With provider execution enabled, it requires:

1. a passing Task 30 pre-provider gate;
2. sandbox/test environment only;
3. evidence generated from MORT-created sandbox objects rather than generic CLI fixtures;
4. one passing evidence row for every required Task 31 scenario;
5. zero unreconciled provider objects;
6. zero live objects, live credentials, or real card data.

Evidence is minimized to safe result codes plus short request/trace/provider-object suffixes. Full provider IDs and credentials are rejected.

## Required Task 31 scenario set

Task 31 is not complete until sanitized provider-backed evidence exists for all of these:

- successful capture
- decline
- requires action
- processing/pending where supported
- network ambiguity and status-before-retry
- duplicate submission
- duplicate webhook
- out-of-order webhook
- webhook lease retry
- full refund
- partial refund
- exact transfer
- transfer reversal
- reversal failure/recovery
- successful tip
- failed tip
- dispute won
- dispute lost
- payout-state separation
- minor account restricted
- minor account ready
- cross-user authorization denial

If the Task 30 gate is closed, Task 31 must remain **blocked**, not simulated as complete.
