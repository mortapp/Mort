# Stripe Gap Matrix and QA Plan

**Date:** 2026-11-24  
**Branch:** `feature/compact-onboarding-and-screen-polish`  
**HEAD:** `3d18236937206ae4b34b2103c913ee8a9e3fa44e`  
**Scope:** Local code, migration, and documentation review only. No hosted Supabase, Stripe dashboard/CLI, provider sandbox/live QA, secrets configuration, deployment, or production verification was performed.

## Evidence reviewed

### Edge functions
- [supabase/functions/_shared/stripe.ts](/C:/Users/micha/Mort/supabase/functions/_shared/stripe.ts)
- [supabase/functions/stripe-config/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-config/index.ts)
- [supabase/functions/stripe-create-connected-account/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-create-connected-account/index.ts)
- [supabase/functions/stripe-create-onboarding-link/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-create-onboarding-link/index.ts)
- [supabase/functions/stripe-get-connected-account-status/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-get-connected-account-status/index.ts)
- [supabase/functions/stripe-create-job-payment-intent/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-create-job-payment-intent/index.ts)
- [supabase/functions/stripe-create-job-transfer/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-create-job-transfer/index.ts)
- [supabase/functions/stripe-create-job-refund/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-create-job-refund/index.ts)
- [supabase/functions/stripe-resolve-job-payment/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-resolve-job-payment/index.ts)
- [supabase/functions/stripe-resolve-job-payment/resolution_operations.ts](/C:/Users/micha/Mort/supabase/functions/stripe-resolve-job-payment/resolution_operations.ts)
- [supabase/functions/stripe-webhook/index.ts](/C:/Users/micha/Mort/supabase/functions/stripe-webhook/index.ts)

### Existing tests (not executed in this review)
- [supabase/functions/_tests/stripe_resolution_test.ts](/C:/Users/micha/Mort/supabase/functions/_tests/stripe_resolution_test.ts)
- [supabase/functions/_tests/webhook_concurrency_stress_test.ts](/C:/Users/micha/Mort/supabase/functions/_tests/webhook_concurrency_stress_test.ts) — clones a local disposable Postgres DB and exercises concurrent webhook claim fencing; requires local Docker/Postgres environment.

### Key migrations/docs
- [20260722032907_stripe_connect_sandbox_foundation.sql](/C:/Users/micha/Mort/supabase/migrations/20260722032907_stripe_connect_sandbox_foundation.sql)
- [20260722034445_stripe_webhook_completion_rpc.sql](/C:/Users/micha/Mort/supabase/migrations/20260722034445_stripe_webhook_completion_rpc.sql)
- [20260722213243_mort_0_9_3_refund_webhook_reconciliation.sql](/C:/Users/micha/Mort/supabase/migrations/20260722213243_mort_0_9_3_refund_webhook_reconciliation.sql)
- [20260730060000_dispute_statements_and_appeals.sql](/C:/Users/micha/Mort/supabase/migrations/20260730060000_dispute_statements_and_appeals.sql)
- [20260730120000_financial_operations_completion.sql](/C:/Users/micha/Mort/supabase/migrations/20260730120000_financial_operations_completion.sql)
- [20261025012531_mort_financial_integrity_and_webhook_fencing.sql](/C:/Users/micha/Mort/supabase/migrations/20261025012531_mort_financial_integrity_and_webhook_fencing.sql)
- [docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md](/C:/Users/micha/Mort/docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md)
- [docs/payments/MORT_STRIPE_CONNECT_ARCHITECTURE.md](/C:/Users/micha/Mort/docs/payments/MORT_STRIPE_CONNECT_ARCHITECTURE.md)
- [docs/payments/MORT_STRIPE_SANDBOX_SETUP.md](/C:/Users/micha/Mort/docs/payments/MORT_STRIPE_SANDBOX_SETUP.md)
- [docs/payments/MORT_STRIPE_LIVE_READINESS.md](/C:/Users/micha/Mort/docs/payments/MORT_STRIPE_LIVE_READINESS.md)
- [docs/payments/MORT_STRIPE_WEBHOOKS.md](/C:/Users/micha/Mort/docs/payments/MORT_STRIPE_WEBHOOKS.md)
- [docs/payments/MORT_STRIPE_RECONCILIATION.md](/C:/Users/micha/Mort/docs/payments/MORT_STRIPE_RECONCILIATION.md)

## Function inventory

| Function | Auth/rate limit | Server controls | Stripe/provider calls | DB RPCs / behavior | Gap notes |
| --- | --- | --- | --- | --- | --- |
| `stripe-config` | Authenticated | `runtime()` enforces mode/keys/feature flags/payments/live gate | None (returns publishable key/runtime status) | `get_stripe_runtime_status` | Depends on hosted runtime controls; no provider QA evidence. |
| `stripe-create-connected-account` | Authenticated + `stripe_connected_account_create` | `runtime()` | `stripe.accounts.create({ type: "express", capabilities.transfers.requested })` with idempotency key `${env}:connected-account:${user}` | `stripe_server_prepare_connected_account`, `stripe_server_record_connected_account` | **Not Accounts v2**; Express v1-style account creation only. |
| `stripe-create-onboarding-link` | Authenticated + `stripe_onboarding_link` | `runtime()`, validated HTTPS redirect origins | `stripe.accountLinks.create(type: "account_onboarding")` | `stripe_server_prepare_connected_account`, `stripe_server_record_onboarding_session` | Single-use hosted onboarding flow exists; no QA proof. |
| `stripe-get-connected-account-status` | Authenticated + `stripe_connected_account_status` | `runtime()` | `stripe.accounts.retrieve(...)` | prepare, `stripe_server_record_connected_account_status`, `get_my_stripe_payout_status` | Maps requirements/capabilities/guardian requirement heuristics; not provider-verified in QA. |
| `stripe-create-job-payment-intent` | Authenticated + `stripe_job_payment_intent` | `runtime()`, saved-payment consent validation | `customers.create`, `paymentIntents.retrieve/create`, `ephemeralKeys.create` | `stripe_server_validate_saved_payment_consent`, prepare/record customer/payment intent RPCs | Amount/currency/customer/binding server-prepared; end-to-end PaymentSheet/device QA missing. |
| `stripe-create-job-transfer` | Authenticated + `x-mort-operations-secret` required | `runtime()` | `stripe.transfers.create(amount,currency,destination,source_transaction,transfer_group)` with server idempotency key | `stripe_server_prepare_transfer`, `stripe_server_record_transfer` | Operational/ops-secret path; no provider QA. No explicit transfer-reversal API function found. |
| `stripe-create-job-refund` | Authenticated + `x-mort-operations-secret` required | `runtime()` | `stripe.refunds.create(payment_intent,amount)` with server idempotency key | `stripe_server_prepare_refund`, `stripe_server_record_refund` | Returns `transfer_reversal_review_required` from prepared state; actual reversal execution path not evident as a Stripe API call in reviewed functions. |
| `stripe-resolve-job-payment` | Authenticated + `stripe_job_resolution` | `runtime()`, **test environment only** (`stripe_live_disabled` otherwise) | transfer/refund creation via `resolution_operations` | dispute/completion prepare/load/record RPCs, operation result/finalize RPCs | Useful for controlled test flows but not a live-capable resolution endpoint; QA coverage unknown. |
| `stripe-webhook` | Unauthenticated endpoint by design, **signature-verified** | `webhookRuntime()` requires webhook secret/mode/key match, raw-body size cap, livemode/environment check | `constructEventAsync(rawBody, Stripe-Signature, secret)`, retrievals for charge/refund normalization as needed | claim/apply/fail RPCs with lease token (`stripe_server_claim_webhook_event`, `stripe_server_apply_webhook_event`, `stripe_server_fail_webhook_event_fenced`) | Strong idempotency/fencing design in code; actual endpoint registration and signed delivery QA not verified. |

## Webhook handler coverage

`stripe-webhook/index.ts` normalizes and routes:
- Payment intents: `payment_intent.succeeded|processing|payment_failed|canceled`
- Connected accounts: `account.updated`
- Disputes: `charge.dispute.created|updated|closed`
- Transfers: `transfer.created|updated|reversed`
- Payouts: `payout.created|updated|paid|failed|canceled`
- Refunds: `refund.created|updated|failed`, `charge.refunded` (expands/refetches as needed)

Routing in `stripe_server_apply_webhook_event` (per integrity migration search): payment events, account status recording, dispute events, transfer events including `transfer.reversed`, payout events, and refund events (including `charge.refunded` arrays). Signed verification, payload SHA-256, lease/epoch fencing, livemode mismatch rejection, and fenced failure recording are present in code.

## Migration / RPC signals

`rg` found ~115 Stripe/runtime RPC definitions/references across migrations. Representative foundations include:
- Runtime/controls/status: `get_stripe_runtime_status`, `get_my_stripe_payout_status`, `stripe_server_update_controls`
- Connected accounts/onboarding: prepare/record account/status/onboarding session RPCs
- Payments: prepare/record job payment, customer, payment intent, saved-payment consent validation
- Webhooks: claim/apply/fail/fenced-fail/complete RPCs; `stripe_server_apply_payment_event`, `stripe_server_apply_refund_event`, transfer/dispute/payout apply RPCs
- Transfers/refunds: prepare/record transfer/refund RPCs; transfer status supports reversed/partially_reversed states in foundation migration; refund records return `transfer_reversal_review_required`
- Disputes: dispute event apply RPC and dispute statement/appeal migrations
- Resolution: prepare/load/record dispute/completion resolution RPCs and `stripe_server_record_resolution_operation_result`
- Reconciliation/operations: `stripe_reconciliation_runs`, `stripe_server_record_reconciliation`, reconciliation/financial operations flags in later migrations

The DB-side logic is extensive but cannot be validated here as deployed/production-correct without hosted migration state, RPC signatures, advisor results, and provider QA.

## Gap matrix

| Requested blocker | Status (local evidence) | Missing/incomplete or unverified | Required QA / owner actions |
| --- | --- | --- | --- |
| **Accounts v2 connected-account creation and onboarding** | **Not satisfied as stated.** Connected account creation uses Express (`accounts.create type:"express"`). Hosted onboarding links and account status sync exist. | No Stripe Accounts v2 (`v2/core/accounts`, controller-based) implementation found. Country/capability/guardian/minor model not verified against Stripe’s intended product configuration. | Confirm required Stripe account model with Stripe/policy/legal owners. If Accounts v2 is required, implement migration/creation/status/onboarding contract changes, DB schema updates, and regression tests. Run sandbox account creation + onboarding + requirements refresh for representative teen/guardian cases. |
| **Signed Connect webhooks in QA** | **Code-level implemented, QA unverified.** Signature verification, env/livemode checks, idempotent claim/lease, and fenced failure handling exist. | No evidence of registered endpoint, subscribed events, secret rotation drills, or successful Stripe CLI/dashboard deliveries against deployed functions. | Configure test secrets, deploy webhook endpoint, register events per `MORT_STRIPE_WEBHOOKS.md`, verify signed deliveries for each handled event family, replay/duplicate tests, failure/recovery tests, and dashboard/CLI evidence capture. |
| **Transfers** | **Partially implemented, QA unverified.** Ops-secret transfer function, server prepare/record/idempotency, webhook transfer event handling including `transfer.reversed`. | No evidence of executed sandbox transfers from funded jobs to eligible connected accounts. No separate automatic transfer-on-completion trigger observed in edge functions (appears operational/manual/test-resolution driven). | Verify eligibility gates, source transaction/transfer group correctness, single-transfer idempotency, failure/retry behavior, and destination account outcomes in Stripe test mode. |
| **Payouts** | **Partially implemented, QA unverified.** Payout events ingested/stored and payout status surfaced; runtime control `payouts_approved`/`payouts_enabled` gates exist. | No payout-creation function found (may be provider-managed on connected accounts); no provider payout lifecycle QA, arrival/failure handling proof, or teen payout receipt evidence. | Validate payout timing/method behavior for representative connected accounts, webhook reconciliation for `payout.*`, and UI/status accuracy. Document who controls payout schedule and failure recovery. |
| **Refunds** | **Implemented in code paths, QA unverified.** Refund creation function, server prepare/record, idempotency, webhook reconciliation for `refund.*` and `charge.refunded`, partial/full status transitions. | Provider refund outcomes, partial refunds, dispute-related refunds, and post-transfer refund implications not QA-verified. | Execute full/partial refunds in sandbox, verify amounts/currency/status transitions, webhook replay/idempotency, and ledger/payment resolution state. |
| **Disputes** | **Partially implemented, QA unverified.** Dispute webhook handling and DB apply paths exist; dispute statement/appeal migrations exist; dispute resolution preparation/execution path exists in test-only resolver. | No Stripe dispute simulation evidence, evidence-submission workflow QA, or fund-hold/reversal operational verification. | Use Stripe test disputes, verify `charge.dispute.*` ingestion, deadlines/evidence flows, operational hold behavior, and downstream financial effects. |
| **Reversals** | **Incomplete/unclear as a complete operational capability.** `transfer.reversed` is handled; refund responses indicate `transfer_reversal_review_required`; financial ops categories include transfer reversal/reconciliation mismatch. | No `stripe.transfers.createReversal` (or equivalent) implementation found in reviewed functions. Reversal execution, authorization, idempotency, and reconciliation path for post-transfer refunds/disputes are not demonstrated. | Define reversal policy (automatic vs manual review), implement explicit reversal operation if required, record provider reversal IDs/outcomes, and QA reversal scenarios end-to-end. |
| **Payment-to-teen-payout testing** | **Unverified / likely blocked by policy and provider setup.** Connected account preparation requires teen role, active account, DOB age 13–17; guardian requirement status is tracked. | No evidence teen/minor payout model is approved/configured in Stripe for target countries, nor any successful funded job → transfer → payout to teen-representative account. | Confirm Stripe minor/guardian/representative requirements per market, complete sandbox onboarding for teen-representative personas, fund jobs, transfer funds, observe payout eligibility/failure states, and document legal/compliance constraints. |
| **Idempotency, ledger reconciliation and recovery** | **Strong code/migration foundations, QA/ops unverified.** Stripe API idempotency keys, server prepare/record patterns, webhook payload hash + lease/epoch fencing, fail-closed runtime controls, reconciliation tables/RPC/flags, and webhook concurrency stress test exist. | No live-like reconciliation runs against provider truth, no incident/recovery drills, no stale-record/backfill evidence, and local stress test not executed in this review. `stripe-resolve-job-payment` records operations before provider call in some branches but finalizes as processing on unknown outcomes (needs careful operational review). | Run webhook replay/duplicate/out-of-order tests, execute reconciliation against Stripe objects, simulate downtime/retries/partial failures, verify no double transfer/refund/reversal, and document recovery runbooks with owner sign-off. |

## Additional technical observations

- **Accounts model mismatch:** requested “Accounts v2” is not reflected in current function code; this is a primary architectural gap, not just QA.
- **Operations protection:** transfer/refund endpoints require `x-mort-operations-secret`; resolution endpoint is test-only but relies on authenticated/rate-limited access rather than the operations secret.
- **Client/provider boundary:** docs and shared runtime indicate secrets/config stay server-side and Flutter should only use publishable/client-safe values; no claim made here that all client surfaces are fully audited.
- **State of readiness docs:** [MORT_STRIPE_IMPLEMENTATION_RESULTS.md](/C:/Users/micha/Mort/docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md) and [MORT_STRIPE_LIVE_READINESS.md](/C:/Users/micha/Mort/docs/payments/MORT_STRIPE_LIVE_READINESS.md) already describe the system as sandbox-architecture/fail-closed but not provider-QA/live ready. This review is consistent with that.

## QA plan (ordered)

### Phase 0 — Preconditions (owner/ops)
1. Confirm approved Stripe product model (Express vs Accounts v2/controller requirements, minor/guardian eligibility, countries, payout timing, dispute/refund policy).
2. Provision sandbox secrets in Supabase only: `MORT_STRIPE_MODE=sandbox`, test publishable/secret/webhook keys, `MORT_STRIPE_OPERATIONS_SECRET`, redirect allowlist.
3. Deploy all `stripe-*` functions to the target project; configure webhook endpoint/JWT/signature behavior per deployment standards.
4. Enable only the minimum DB runtime flags needed per QA window; keep live flags off.
5. Prepare synthetic QA users/contracts/jobs (teen/adult/guardian-representative personas as policy allows), never production data.

### Phase 1 — Static/contract verification (local/CI where possible)
1. Run existing Deno tests where environment supports them: [stripe_resolution_test.ts](/C:/Users/micha/Mort/supabase/functions/_tests/stripe_resolution_test.ts), [webhook_concurrency_stress_test.ts](/C:/Users/micha/Mort/supabase/functions/_tests/webhook_concurrency_stress_test.ts) (Docker/local clone required).
2. Run hosted DB/contract suites referenced by docs (`qa-stripe-*.mjs`, payment/dispute/financial-operations suites) against a non-production environment if credentials and safe fixtures exist.
3. Verify migration alignment and RPC signatures on the deployed QA database before provider tests.

### Phase 2 — Connect/onboarding QA
1. Create connected account for eligible teen persona; capture provider account ID, requirements, capabilities, and DB state.
2. Generate onboarding link; validate redirect allowlist behavior and link expiry handling.
3. Complete Stripe-hosted onboarding in sandbox; verify `account.updated` webhooks and status sync.
4. Exercise currently_due/past_due/disabled/payouts-disabled cases and guardian requirement states.
5. Exit criteria: account reaches required transfers/payouts capability state or fails closed with accurate, auditable status.

### Phase 3 — Funding and webhook QA
1. Create PaymentIntent via server-calculated flow; present PaymentSheet on Android/iOS test devices/builds.
2. Test success, processing, requires_action, failure, and cancellation with Stripe test payment methods.
3. Verify `stripe-webhook` receives signed events, claims once, applies correctly, and ignores/rejects duplicates, bad signatures, wrong livemode/env, oversized payloads, and stale leases.
4. Exit criteria: DB payment records, provider IDs, amounts, currency, and customer bindings match provider truth.

### Phase 4 — Transfer, payout, refund, dispute, reversal QA
1. **Transfers:** run eligible completion/dispute-clear path; verify single transfer, idempotency, source transaction/transfer group, and transfer webhook reconciliation.
2. **Payouts:** observe connected-account payout lifecycle (if provider-managed) or execute approved payout flow; reconcile `payout.*` events and UI/status.
3. **Refunds:** full and partial refunds before/after transfer scenarios as policy allows; verify refund records, payment status transitions, and `charge.refunded` reconciliation.
4. **Disputes:** simulate disputes; verify event ingestion, deadlines/statements/appeals data paths, operational holds, and financial outcomes.
5. **Reversals:** if post-transfer refund/dispute requires transfer reversal, verify explicit reversal execution/review path; if not implemented, treat as blocking gap.
6. **Teen payout path:** funded job → eligible teen connected account → transfer → payout/availability evidence for approved minor model.
7. Exit criteria: no duplicate money movements, correct ledger state transitions, and provider-truth reconciliation for every scenario.

### Phase 5 — Reconciliation, recovery, and operational readiness
1. Run reconciliation for payments, accounts, transfers, payouts, refunds, disputes, and stale webhook claims; classify matched/corrected/needs-review/failed.
2. Simulate webhook downtime, delayed delivery, duplicate delivery, out-of-order events, provider unknown outcomes, and manual recovery.
3. Verify audit trails, incident records, financial holds, and two-person review triggers for mismatches/negative-balance risk.
4. Confirm monitoring/alerting, runbooks, staffing/on-call, and incident exercises.
5. Exit criteria: repeatable evidence package with provider IDs, DB records, reconciliation results, and owner sign-off; no unresolved “needs review/failed” financial items.

## Immediate implementation gaps to resolve before claiming the blocker complete

1. **Accounts v2 requirement mismatch:** implement or formally de-scope with owner approval and update architecture/docs.
2. **Transfer reversals:** implement and QA an explicit reversal path if required by refund/dispute policy after transfer.
3. **Payout execution/ownership:** clarify and implement/verify payout creation/control expectations (provider-managed vs platform-triggered) and teen payout eligibility.
4. **Provider QA evidence:** no substitute exists for signed webhook/provider sandbox/live-ready verification.
5. **Reconciliation/recovery drills:** run and document against real provider objects, not only schema/code review.

*This report does not claim MORT is production-ready and does not assign a readiness percentage.*