# MORT Stripe Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a sandbox-only, server-authoritative Stripe and Supabase payment backend that captures a platform charge before work, permits job start only after provider confirmation, settles authoritative compensation, sends an exact separate Connect transfer, issues component-aware refunds and immutable documents, and supports a separate post-work tip.

**Architecture:** Extend the existing MORT Payment OS and Stripe infrastructure rather than creating a parallel payment stack. Supabase private tables and caller-bound/service-only RPCs own policy, quotes, attempts, state, settlement, ledger, documents, history, and release gates; Stripe Edge Functions are thin authenticated provider adapters; Flutter renders server-owned state and presents Stripe PaymentSheet. All money movement stays sandbox-gated, USD-only, idempotent, append-only where financial facts are concerned, and disabled until the pre-provider-test gate passes.

**Tech Stack:** PostgreSQL/Supabase migrations and RLS, Supabase Edge Functions on Deno/TypeScript, Stripe SDK and Connect separate charges/transfers, Flutter/Dart with Riverpod and `flutter_stripe`, Node.js QA scripts, PowerShell release/test gates.

**Spec:** `docs/superpowers/specs/2026-09-16-mort-stripe-backend-design.md`

## Global Constraints

- Primary job funding is a pre-work platform charge/capture with `transfer_group`; never add `transfer_data.destination` or `application_fee_amount` to the primary PaymentIntent.
- A job becomes startable only after Stripe confirms capture and the backend transactionally revalidates the quote, contract, amount, currency, environment, and current job state.
- Captured base and fee amounts remain liabilities until authoritative settlement; no teen earnings or MORT revenue is recognized at funding time.
- Settlement alone computes `compensatedBaseCents`; the exact separate Connect transfer equals teen earnings, and component refunds follow `adultRefund = (base - compensatedBase) + (fee(base) - fee(compensatedBase))`.
- Tips are separate post-work PaymentIntents and transfers; 100% of a successful tip belongs to the teen, MORT charges no tip fee, and a failed tip cannot roll back base settlement.
- Sandbox fee policy is exactly 8%, minimum $1, maximum $5, integer cents, half-up basis-point rounding, and USD-only. Production pricing and production partial-compensation values stay disabled and owner-gated.
- Radar Pro is the selected Stripe fraud configuration. Its transaction cost is recorded for production unit-economics review; Radar selection is not an open decision.
- No automatic teen clawback occurs after an adult chargeback. Recovery is an audited receivable/loss process.
- Payout status is separate from transfer/earnings status. Initial payouts are standard only; instant payouts remain disabled.
- Minor Connect hosted onboarding and end-to-end US age 13–17 readiness remain release blockers. MORT never collects Stripe identity, bank, SSN, or guardian evidence.
- Every provider mutation is server-side, request-bound, idempotent, rate-limited, auditable, and sandbox-only. No live credential is read, changed, tested, or enabled by this plan.
- `STRIPE_TEST_SECRET_KEY` is owner-confirmed present in Supabase; never read or print its value. `STRIPE_TEST_PUBLISHABLE_KEY` must be confirmed, and `STRIPE_TEST_WEBHOOK_SECRET` is installed only after the TEST webhook exists.
- Before each implementation phase that touches Supabase behavior, inspect the current Supabase changelog and the exact current docs for migrations, RLS, Edge Functions, and secrets. Before Flutter SDK work, inspect the current official `flutter_stripe` installation and PaymentSheet guidance.
- Create every migration with `npx supabase migration new <slug>` after checking `npx supabase migration --help`; never hand-author a timestamp. The file references below use `supabase/migrations/*_<slug>.sql`, meaning the single CLI-generated file with that exact slug.
- Private financial tables use RLS plus forced RLS as defense in depth. Every `SECURITY DEFINER` function uses `set search_path = ''`, performs explicit caller/service-role checks, revokes `PUBLIC`/`anon`, and receives only the minimum explicit grant.
- Each task follows RED → minimal implementation → GREEN. Do not combine commit boundaries or proceed past a failed verification.
- Database changes are forward-only and additive. Do not reset hosted Supabase, rewrite hosted migration history, delete immutable records, or destructively roll back financial facts.

## Planned File Structure

### Six CLI-generated migrations

- `supabase/migrations/*_mort_stripe_policy_and_funding_v1.sql` — versioned service-fee, Fair Pay, tip, cancellation, and partial-compensation policies; immutable quotes; runtime strategy constraints.
- `supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql` — PaymentIntent/attempt extensions, normalized states, active-attempt uniqueness, captured-funding gate, status target, and monotonic reconciliation metadata.
- `supabase/migrations/*_mort_stripe_webhook_inbox_v2.sql` — durable inbox, payload-hash conflict detection, processing leases, retry schedule, terminal/retryable outcomes, event ordering.
- `supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql` — settlement decisions, ledger accounts/transactions/entries, earnings, exact transfers, component refunds, tips, disputes, recovery, and payout separation.
- `supabase/migrations/*_mort_stripe_documents_history_v1.sql` — immutable documents, line items, links, receipt/order numbers, and authorized chronological history.
- `supabase/migrations/*_mort_stripe_financial_access_and_activation_v1.sql` — final RLS/grants hardening, caller-bound reads, rate limits, audit/observability, reconciliation operations, and conjunctive production gates.

### Shared Edge Function modules

- Modify `supabase/functions/_shared/stripe.ts` — environment, auth, safe errors, provider runtime, and mutation-gate enforcement.
- Create `supabase/functions/_shared/stripe_payment_state.ts` — normalized payment state and monotonic transition rules.
- Create `supabase/functions/_shared/stripe_settlement.ts` — pure integer-cent fee/refund/settlement calculations.
- Create `supabase/functions/_shared/stripe_webhook.ts` — verified-event envelope and retry/lease result mapping.
- Create tests under `supabase/functions/_tests/` for the shared modules and handler contracts.

### Edge Functions

- Extend `stripe-config`, `stripe-create-connected-account`, `stripe-create-onboarding-link`, `stripe-get-connected-account-status`, `stripe-create-job-payment-intent`, `stripe-resolve-job-payment`, `stripe-create-job-transfer`, `stripe-create-job-refund`, and `stripe-webhook`.
- Create `stripe-create-job-funding-quote`, `stripe-get-job-payment-status`, `stripe-create-job-tip-payment-intent`, `stripe-get-financial-document`, and `stripe-list-financial-history`.
- Register every JWT-authenticated function in `supabase/config.toml`; keep only `stripe-webhook` at `verify_jwt = false`, protected by Stripe signature verification.

### QA and mobile

- Extend `scripts/stripe-qa-suites.mjs` and add focused `scripts/qa-stripe-*.mjs` entrypoints for every database/provider contract.
- Create `scripts/stripe-pre-provider-test-gate.ps1` and `scripts/qa-stripe-pre-provider-gate.mjs`.
- Extend `scripts/run-final-supabase-regression.ps1`, `scripts/secret-scan.ps1`, and `.github/workflows/mort-ci.yml`.
- Modify Flutter payment models, repositories, screens, routes, providers, config, `pubspec.yaml`, and `pubspec.lock`; add focused tests under `flutter_mort/test/features/payments`, `history`, and `receipts`.

## Reviewable Phases

| Phase | Deliverable | Tasks |
|---|---|---:|
| 1 | Versioned policy and immutable quote foundation | 1–3 |
| 2 | Payment attempts, provider-confirmed funding, and start gate | 4–6 |
| 3 | Connected-account onboarding and minor readiness | 7–8 |
| 4 | Retry-safe webhook inbox and monotonic reconciliation | 9–11 |
| 5 | Settlement, exact transfers, refunds, and ledger | 12–16 |
| 6 | Separate tips, disputes, recovery, and payout separation | 17–19 |
| 7 | Immutable documents and financial history | 20–21 |
| 8 | RLS, rate limits, audit, observability, and activation gates | 22–23 |
| 9 | Flutter Stripe SDK and Payment OS data wiring | 24–26 |
| 10 | Flutter funding, tip, document, history, and payout UI | 27–29 |
| 11 | Pre-provider gate and Stripe sandbox integration | 30–31 |
| 12 | Full regression, secret scan, and production-gate evidence | 32–33 |

---

## Phase 1 — Versioned Policy and Immutable Quote Foundation

### Task 1: Create the policy-and-quote migration contract

**Files:**
- Create via Supabase CLI: `supabase/migrations/*_mort_stripe_policy_and_funding_v1.sql`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-policy-versioning.mjs`
- Create: `scripts/qa-stripe-funding-quote.mjs`

**Interfaces:**
- Consumes: existing `public.job_contracts`, `public.job_contract_versions`, `public.job_payment_obligations`, `private.stripe_runtime_controls`.
- Produces: `private.stripe_financial_policy_versions`, `private.stripe_job_funding_quotes`, `stripe_server_create_job_funding_quote_v1(uuid,uuid,text)`, and immutable policy/quote identifiers used by all later tasks.

- [ ] **Step 1: Write the failing QA scenarios**

Add `policy-versioning` and `funding-quote` cases to `scripts/stripe-qa-suites.mjs`. Assert that policies are append-only, only one active version exists per `(environment, policy_kind, currency_code, scope_key)`, production policy rows default inactive, quotes bind the adult/contract/version/obligation/policy/environment, quote cents are immutable, expired quotes are rejected, and no RPC accepts client-supplied price or fee cents. Each new entrypoint should contain:

```js
import { runStripeQa } from "./stripe-qa-suites.mjs";
await runStripeQa("stripe-policy-versioning", "policy-versioning");
```

- [ ] **Step 2: Run the tests to verify RED**

Run: `node scripts/qa-stripe-policy-versioning.mjs; node scripts/qa-stripe-funding-quote.mjs`

Expected RED: PostgreSQL reports `relation "private.stripe_financial_policy_versions" does not exist` or the QA assertion reports the missing `stripe_server_create_job_funding_quote_v1` function.

- [ ] **Step 3: Generate and write the migration**

Run `npx supabase migration --help`, then `npx supabase migration new mort_stripe_policy_and_funding_v1`. In the emitted migration create the two private tables with explicit checks. The policy row stores `policy_kind`, `scope_key`, `environment`, `currency_code`, semantic `version`, `effective_at`, `retired_at`, `configuration jsonb`, and audit timestamps. The quote row stores the exact contract/version/obligation/adult/teen IDs, policy IDs, base/service-fee/total cents, currency, `expires_at`, `consumed_at`, `state`, `request_id`, and a canonical input hash.

Seed sandbox-only policies with these exact configurations:

```json
{"service_fee":{"basis_points":800,"minimum_cents":100,"maximum_cents":500,"rounding":"half_up"},"tip":{"mort_fee_basis_points":0,"teen_share_basis_points":10000},"currency":"USD"}
```

Implement `private.calculate_mort_service_fee_v1(base_cents, policy_id)` with integer arithmetic `floor((base_cents * basis_points + 5000) / 10000)` followed by min/max clamping. Implement `stripe_server_create_job_funding_quote_v1` as service-only, server-derived, USD-only, and transactionally bound to the active contract and obligation. Do not recognize earnings or revenue.

- [ ] **Step 4: Apply locally and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-stripe-policy-versioning.mjs; node scripts/qa-stripe-funding-quote.mjs`

Expected GREEN: both QA scripts exit 0; repeated quote requests with the same request/contract inputs return the same quote, changed inputs conflict, and every fee boundary fixture returns the exact expected cents.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_policy_and_funding_v1.sql scripts/stripe-qa-suites.mjs scripts/qa-stripe-policy-versioning.mjs scripts/qa-stripe-funding-quote.mjs
git commit -m "feat(payments): add versioned funding policies and quotes"
```

### Task 2: Add versioned Fair Pay, cancellation, and partial-compensation policy evaluation

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_policy_and_funding_v1.sql`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-settlement-policy.mjs`

**Interfaces:**
- Consumes: `private.stripe_financial_policy_versions` and existing job type, contract, and evidence records.
- Produces: `private.evaluate_fair_pay_v1`, `private.evaluate_cancellation_v1`, and `private.evaluate_partial_compensation_v1`, each returning policy version plus server-derived cents/reason codes.

- [ ] **Step 1: Write the failing policy tests**

Add fixtures for green/yellow/red Fair Pay, adult cancellation before/after funding, teen cancellation, no-show, full completion, and sandbox partial-compensation bands. Assert policy evaluation reads job/contract facts, not a client percentage; returned `compensated_base_cents` is between zero and quoted base; and no production partial-compensation policy is active.

- [ ] **Step 2: Run the test to verify RED**

Run: `node scripts/qa-stripe-settlement-policy.mjs`

Expected RED: QA reports `private.evaluate_partial_compensation_v1` is missing.

- [ ] **Step 3: Add the minimal policy engines**

In the same phase migration file, add sandbox policy rows and pure private evaluators with this return contract:

```sql
returns table (
  policy_version_id uuid,
  outcome_code text,
  compensated_base_cents integer,
  explanation_code text
)
```

The generic engine supports ordered evidence predicates and fixed basis-point/fixed-cent awards stored in policy JSON. Only sandbox fixtures receive values. Production rows remain inactive, so evaluation fails closed with `production_partial_compensation_policy_unapproved`.

- [ ] **Step 4: Reapply locally and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-stripe-settlement-policy.mjs`

Expected GREEN: all fixtures select the expected policy version and exact compensated base; forged client percentages have no effect; production evaluation is rejected.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_policy_and_funding_v1.sql scripts/stripe-qa-suites.mjs scripts/qa-stripe-settlement-policy.mjs
git commit -m "feat(payments): add versioned settlement policy engine"
```

### Task 3: Expose an authenticated funding-quote adapter

**Files:**
- Create: `supabase/functions/stripe-create-job-funding-quote/index.ts`
- Modify: `supabase/config.toml`
- Modify: `supabase/functions/_shared/stripe.ts`
- Create: `supabase/functions/_tests/stripe_funding_quote_test.ts`

**Interfaces:**
- Consumes: authenticated adult, `{contract_id, request_id}`, `stripe_server_create_job_funding_quote_v1`.
- Produces: `{ok, quote_id, base_cents, service_fee_cents, total_cents, currency_code, expires_at, policy_version}` with no provider mutation.

- [ ] **Step 1: Write the failing handler test**

Use a stubbed authenticated context and RPC adapter. Assert missing auth is 401, invalid UUID is 400, cross-adult access is denied by the RPC, and the response contains server amounts but no provider IDs, secrets, or mutable policy input.

- [ ] **Step 2: Run the test to verify RED**

Run: `deno test --allow-read supabase/functions/_tests/stripe_funding_quote_test.ts`

Expected RED: module resolution fails because `stripe-create-job-funding-quote/index.ts` does not exist.

- [ ] **Step 3: Implement the quote handler**

Register `[functions.stripe-create-job-funding-quote] verify_jwt = true`. Authenticate, enforce `requireRateLimit(context, "stripe_job_funding_quote")`, validate UUIDs, call only the service RPC with `context.user.id`, and return the minimized quote contract. Do not call Stripe and do not require a provider secret.

- [ ] **Step 4: Run focused verification**

Run: `deno test --allow-read supabase/functions/_tests/stripe_funding_quote_test.ts; node scripts/qa-stripe-funding-quote.mjs`

Expected GREEN: Deno tests pass, DB quote tests pass, and source scan finds no `stripe.paymentIntents` call in the quote function.

- [ ] **Step 5: Commit**

```bash
git add supabase/config.toml supabase/functions/_shared/stripe.ts supabase/functions/stripe-create-job-funding-quote supabase/functions/_tests/stripe_funding_quote_test.ts
git commit -m "feat(payments): expose immutable funding quotes"
```

## Phase 2 — Payment Attempts, Provider-Confirmed Funding, and Start Gate

### Task 4: Normalize PaymentAttempt and payment-state persistence

**Files:**
- Create via Supabase CLI: `supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql`
- Create: `supabase/functions/_shared/stripe_payment_state.ts`
- Create: `supabase/functions/_tests/stripe_payment_state_test.ts`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-payment-state-v2.mjs`

**Interfaces:**
- Consumes: `private.stripe_job_payment_intents`, `private.stripe_job_payment_attempts`, and funding quotes.
- Produces: normalized states `READY`, `PROCESSING`, `REQUIRES_ACTION`, `PENDING`, `SUCCEEDED`, `DECLINED`, `FAILED`, `CANCELLED`, `UNKNOWN`, `PROVIDER_UNAVAILABLE`, `DUPLICATE_BLOCKED`; `stripe_server_record_payment_intent_v2`; one active attempt per obligation/environment.

- [ ] **Step 1: Write failing state and idempotency tests**

Create table-driven Deno tests for every legal/illegal state transition and QA fixtures for: same request/same payload replay, same request/different payload conflict, a second active attempt, provider timeout yielding `UNKNOWN`, and a retry blocked until server status reconciliation runs.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_payment_state_test.ts; node scripts/qa-stripe-payment-state-v2.mjs`

Expected RED: the shared reducer module and v2 RPC are absent.

- [ ] **Step 3: Generate the migration and implement state contracts**

Run `npx supabase migration new mort_stripe_funding_attempts_and_state_v1`. Extend, rather than replace, the existing intent/attempt tables with quote ID, operation kind, normalized state, request hash, provider timestamps, last reconciled timestamp, failure class, and row version. Add a partial unique index that permits only one nonterminal base-funding attempt per `(environment, obligation_id)`. Add `stripe_server_record_payment_intent_v2` to consume the quote exactly once and record provider metadata without setting funded state.

In `stripe_payment_state.ts`, export:

```ts
export type MortPaymentState = "READY" | "PROCESSING" | "REQUIRES_ACTION" |
  "PENDING" | "SUCCEEDED" | "DECLINED" | "FAILED" | "CANCELLED" |
  "UNKNOWN" | "PROVIDER_UNAVAILABLE" | "DUPLICATE_BLOCKED";
export function reducePaymentState(current: MortPaymentState, observed: MortPaymentState): MortPaymentState;
export function requiresStatusBeforeRetry(state: MortPaymentState): boolean;
```

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; deno test supabase/functions/_tests/stripe_payment_state_test.ts; node scripts/qa-stripe-payment-state-v2.mjs`

Expected GREEN: every legal transition passes, illegal regressions throw, duplicate requests replay safely, conflicting hashes fail, and active-attempt uniqueness holds under concurrent inserts.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql supabase/functions/_shared/stripe_payment_state.ts supabase/functions/_tests/stripe_payment_state_test.ts scripts/stripe-qa-suites.mjs scripts/qa-stripe-payment-state-v2.mjs
git commit -m "feat(payments): normalize funding attempts and states"
```

### Task 5: Convert PaymentIntent creation to quote consumption and pre-work platform capture

**Files:**
- Modify: `supabase/functions/stripe-create-job-payment-intent/index.ts`
- Modify: `supabase/functions/_shared/stripe.ts`
- Create: `supabase/functions/_tests/stripe_create_job_payment_intent_test.ts`
- Modify: `scripts/stripe-qa-suites.mjs`
- Modify: `scripts/qa-stripe-payment-amount-forgery.mjs`
- Modify: `scripts/qa-stripe-payment-idempotency.mjs`

**Interfaces:**
- Consumes: `{quote_id, request_id, save_payment_method, saved_payment_consent_version}` and `stripe_server_consume_job_funding_quote_v1`.
- Produces: platform PaymentIntent with `amount = quote.total_cents`, `currency = usd`, automatic capture, `transfer_group`, MORT metadata, and client secret; no destination charge fields.

- [ ] **Step 1: Write the failing provider-adapter tests**

Stub Stripe and assert the handler uses the consumed quote, sends one stable Stripe idempotency key, sets no `transfer_data`, `destination`, or `application_fee_amount`, and maps timeout to `UNKNOWN` without creating a second PaymentIntent on retry. Assert client-supplied amount/currency/teen IDs are ignored or rejected.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_create_job_payment_intent_test.ts`

Expected RED: current handler expects `contract_id` and does not consume an immutable `quote_id`.

- [ ] **Step 3: Implement minimal quote-bound creation**

Call the consume RPC before Stripe creation; create or reuse the customer; pass the server-issued idempotency key to Stripe; create an automatically captured platform PaymentIntent with `transfer_group`; record its provider result through `stripe_server_record_payment_intent_v2`. Return `UNKNOWN` on ambiguous transport outcome and require the status endpoint before another create attempt.

- [ ] **Step 4: Run focused GREEN checks**

Run: `deno test supabase/functions/_tests/stripe_create_job_payment_intent_test.ts; node scripts/qa-stripe-payment-amount-forgery.mjs; node scripts/qa-stripe-payment-idempotency.mjs`

Expected GREEN: provider calls are platform charges only, server amounts are authoritative, and replay/unknown handling does not duplicate a charge.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/stripe-create-job-payment-intent supabase/functions/_shared/stripe.ts supabase/functions/_tests/stripe_create_job_payment_intent_test.ts scripts/stripe-qa-suites.mjs scripts/qa-stripe-payment-amount-forgery.mjs scripts/qa-stripe-payment-idempotency.mjs
git commit -m "feat(payments): create quote-bound platform charges"
```

### Task 6: Enforce provider-confirmed funding before job start

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql`
- Modify: `scripts/qa-job-start-funding-gate.mjs`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-funded-start-race.mjs`

**Interfaces:**
- Consumes: normalized `SUCCEEDED`, captured amount/currency, current active contract/version/obligation, and existing job-start RPCs.
- Produces: `private.is_job_funded_and_startable_v1(job_id)` and transactional enforcement inside every start/arrival/active transition path.

- [ ] **Step 1: Write and extend the failing start-gate tests**

Assert `READY`, `PROCESSING`, `PENDING`, `UNKNOWN`, stale quote, amount mismatch, currency mismatch, canceled contract, and forged client status all block start. Add a two-session race where capture confirmation and contract cancellation compete; exactly one authoritative outcome may commit.

- [ ] **Step 2: Run tests to verify RED**

Run: `node scripts/qa-job-start-funding-gate.mjs; node scripts/qa-stripe-funded-start-race.mjs`

Expected RED: existing payment-status guard does not require the new captured-funding facts and race fixture.

- [ ] **Step 3: Add the transactional predicate**

Lock the active contract, obligation, payment intent, and job rows in stable order. Return true only when the provider-confirmed state is `SUCCEEDED`, captured cents/currency match the unexpired consumed quote, the contract and assignment remain active, and the job is in a legal pre-start state. Call this predicate from each existing server transition that can make work active; never accept a client funding boolean.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-job-start-funding-gate.mjs; node scripts/qa-stripe-funded-start-race.mjs`

Expected GREEN: unfunded and stale states fail closed, a valid captured charge permits one start, and the race never yields both cancellation and start.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql scripts/qa-job-start-funding-gate.mjs scripts/stripe-qa-suites.mjs scripts/qa-stripe-funded-start-race.mjs
git commit -m "feat(payments): gate job start on confirmed capture"
```

## Phase 3 — Connected-Account Onboarding and Minor Readiness

### Task 7: Make connected-account readiness explicit and fail closed

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql`
- Modify: `supabase/functions/stripe-create-connected-account/index.ts`
- Modify: `supabase/functions/stripe-get-connected-account-status/index.ts`
- Create: `supabase/functions/_tests/stripe_connected_account_test.ts`
- Modify: `scripts/qa-stripe-connected-account-isolation.mjs`
- Modify: `scripts/qa-stripe-minor-guardian-status.mjs`

**Interfaces:**
- Consumes: Stripe hosted-account response and requirements/capability state.
- Produces: minimized readiness categories `not_started`, `onboarding`, `pending_review`, `restricted`, `ready`, `disabled`; `ready` requires transfers capability active, details submitted, payouts enabled, no currently_due/past_due requirements, and supported US/USD configuration.

- [ ] **Step 1: Write failing readiness tests**

Cover each category, age/guardian requirement minimization, provider-account ID non-disclosure, non-teen denial, and a restricted account blocking settlement transfer preparation.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_connected_account_test.ts; node scripts/qa-stripe-connected-account-isolation.mjs; node scripts/qa-stripe-minor-guardian-status.mjs`

Expected RED: the current status contract lacks the complete readiness classifier.

- [ ] **Step 3: Extend existing account functions**

Persist normalized readiness and safe requirement category only. Continue Stripe-hosted onboarding; do not collect identity/bank/SSN/guardian evidence. In sandbox account creation request US country and controller properties validated for MORT's approved Connect setup; do not silently fall back to an unapproved account configuration.

- [ ] **Step 4: Verify GREEN**

Run: `deno test supabase/functions/_tests/stripe_connected_account_test.ts; node scripts/qa-stripe-connected-account-isolation.mjs; node scripts/qa-stripe-minor-guardian-status.mjs`

Expected GREEN: every readiness case is deterministic, sensitive provider fields stay server-only, and unready accounts cannot receive transfers.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql supabase/functions/stripe-create-connected-account supabase/functions/stripe-get-connected-account-status supabase/functions/_tests/stripe_connected_account_test.ts scripts/qa-stripe-connected-account-isolation.mjs scripts/qa-stripe-minor-guardian-status.mjs
git commit -m "feat(payments): enforce connected account readiness"
```

### Task 8: Harden single-use hosted onboarding links

**Files:**
- Modify: `supabase/functions/stripe-create-onboarding-link/index.ts`
- Modify: `supabase/functions/_shared/stripe.ts`
- Create: `supabase/functions/_tests/stripe_onboarding_link_test.ts`
- Modify: `scripts/qa-stripe-onboarding-link-security.mjs`

**Interfaces:**
- Consumes: authenticated teen, allowlisted HTTPS return/refresh URL, existing connected account.
- Produces: one Stripe-hosted single-use onboarding URL and expiry; no embedded WebView or reusable stored URL.

- [ ] **Step 1: Write failing redirect and replay tests**

Test non-HTTPS, unapproved origins, adult callers, missing account, replayed/superseded sessions, and response redaction. Assert links are never logged or persisted in full.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_onboarding_link_test.ts; node scripts/qa-stripe-onboarding-link-security.mjs`

Expected RED: at least the new non-persistence/replay assertions fail.

- [ ] **Step 3: Implement the hardened adapter**

Retain `validatedRedirectUrl`, add teen-role and account-state checks in the server RPC, supersede prior sessions, store only origins/provider link ID/expiry, and return the URL once to the authenticated caller.

- [ ] **Step 4: Verify GREEN**

Run: `deno test supabase/functions/_tests/stripe_onboarding_link_test.ts; node scripts/qa-stripe-onboarding-link-security.mjs`

Expected GREEN: only approved HTTPS origins work, URLs are single-use provider artifacts, and no full onboarding URL appears in database or logs.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/stripe-create-onboarding-link supabase/functions/_shared/stripe.ts supabase/functions/_tests/stripe_onboarding_link_test.ts scripts/qa-stripe-onboarding-link-security.mjs
git commit -m "fix(payments): harden hosted Connect onboarding"
```

## Phase 4 — Retry-Safe Webhook Inbox and Monotonic Reconciliation

### Task 9: Add webhook inbox leases, retry states, and integrity incidents

**Files:**
- Create via Supabase CLI: `supabase/migrations/*_mort_stripe_webhook_inbox_v2.sql`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-webhook-leases.mjs`
- Modify: `scripts/qa-stripe-webhook-replay.mjs`
- Modify: `scripts/qa-stripe-webhook-idempotency.mjs`

**Interfaces:**
- Consumes: verified Stripe event ID/type/created timestamp/livemode/payload SHA-256.
- Produces: inbox states `RECEIVED`, `PROCESSING`, `PROCESSED`, `FAILED_RETRYABLE`, `FAILED_TERMINAL`, `IGNORED`; claim/lease/complete/fail v2 RPCs; lease owner/expiry, attempt count, next attempt time, safe result code.

- [ ] **Step 1: Write failing inbox tests**

Cover first claim, duplicate matching hash, duplicate mismatched hash, concurrent lease acquisition, expired lease reclamation, retry backoff, terminal failure, and processed-event replay. Assert raw payload is not stored and hash mismatch creates a critical financial incident.

- [ ] **Step 2: Run tests to verify RED**

Run: `node scripts/qa-stripe-webhook-leases.mjs; node scripts/qa-stripe-webhook-replay.mjs; node scripts/qa-stripe-webhook-idempotency.mjs`

Expected RED: current inbox lacks lease columns and v2 RPCs.

- [ ] **Step 3: Generate and write the migration**

Run `npx supabase migration new mort_stripe_webhook_inbox_v2`. Extend the existing webhook table additively, map legacy states, add the v2 state check/index, and implement:

```sql
stripe_server_claim_webhook_event_v2(environment,event_id,event_type,provider_created_at,payload_sha256,livemode)
stripe_server_lease_webhook_event_v2(environment,event_id,worker_id,lease_seconds)
stripe_server_complete_webhook_event_v2(environment,event_id,worker_id,safe_result_code)
stripe_server_fail_webhook_event_v2(environment,event_id,worker_id,retryable,safe_failure_code)
```

Use `for update skip locked` for leasing, bounded exponential retry timestamps, and immutable `(environment, provider_event_id, payload_sha256)` integrity.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-stripe-webhook-leases.mjs; node scripts/qa-stripe-webhook-replay.mjs; node scripts/qa-stripe-webhook-idempotency.mjs`

Expected GREEN: only one worker holds a live lease, retryable failures can be reclaimed, completed events are no-ops, and mismatched hashes raise an incident without processing.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_webhook_inbox_v2.sql scripts/stripe-qa-suites.mjs scripts/qa-stripe-webhook-leases.mjs scripts/qa-stripe-webhook-replay.mjs scripts/qa-stripe-webhook-idempotency.mjs
git commit -m "feat(payments): add retry-safe webhook inbox"
```

### Task 10: Route signed webhooks through the leased monotonic reducer

**Files:**
- Create: `supabase/functions/_shared/stripe_webhook.ts`
- Modify: `supabase/functions/stripe-webhook/index.ts`
- Create: `supabase/functions/_tests/stripe_webhook_test.ts`
- Modify: `scripts/qa-stripe-webhook-signature.mjs`

**Interfaces:**
- Consumes: raw body, `Stripe-Signature`, sandbox webhook secret, and v2 inbox RPCs.
- Produces: verified event processing with lease ownership; payment/account/transfer/refund/dispute/payout facts delegated to versioned RPCs; retryable HTTP 500 vs acknowledged terminal/ignored responses.

- [ ] **Step 1: Write failing webhook handler tests**

Test invalid signature, body over limit, `livemode=true` in sandbox, lease not acquired, transient DB/provider failure, terminal contract mismatch, and successful/ignored processing. Assert no raw body, client secret, account ID, or signing secret reaches logs.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_webhook_test.ts; node scripts/qa-stripe-webhook-signature.mjs`

Expected RED: current handler uses legacy claim/complete/fail RPCs and cannot express lease/retry outcomes.

- [ ] **Step 3: Implement leased processing**

Verify the signature before parsing; reject environment/livemode mismatch; hash the raw body; claim then lease with a random worker UUID; dispatch supported events; complete only while owning the lease; mark transient failures retryable and integrity/contract failures terminal. Keep `verify_jwt = false` only for this endpoint.

- [ ] **Step 4: Verify GREEN**

Run: `deno test supabase/functions/_tests/stripe_webhook_test.ts; node scripts/qa-stripe-webhook-signature.mjs; node scripts/qa-stripe-webhook-leases.mjs`

Expected GREEN: signature and mode failures are rejected, retryable failures remain recoverable, and successful/ignored events are acknowledged exactly once.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/_shared/stripe_webhook.ts supabase/functions/stripe-webhook supabase/functions/_tests/stripe_webhook_test.ts scripts/qa-stripe-webhook-signature.mjs
git commit -m "feat(payments): process Stripe webhooks with leases"
```

### Task 11: Add status-before-retry and monotonic provider reconciliation

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql`
- Create: `supabase/functions/stripe-get-job-payment-status/index.ts`
- Modify: `supabase/config.toml`
- Create: `supabase/functions/_tests/stripe_payment_status_test.ts`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-monotonic-reconciliation.mjs`

**Interfaces:**
- Consumes: authenticated participant/operations caller, payment or contract ID, current DB state, Stripe PaymentIntent retrieval.
- Produces: `stripe_server_get_payment_status_target_v1`, `stripe_server_apply_payment_event_v2`, and minimized `get_my_job_payment_status_v1` response.

- [ ] **Step 1: Write failing reconciliation tests**

Cover `UNKNOWN → SUCCEEDED`, `PROCESSING → SUCCEEDED`, out-of-order `payment_failed` after success, duplicate success, amount/currency mismatch, unauthorized contract enumeration, and reconciliation of a timed-out create before allowing retry.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_payment_status_test.ts; node scripts/qa-stripe-monotonic-reconciliation.mjs`

Expected RED: status function and v2 monotonic apply RPC are absent.

- [ ] **Step 3: Implement reconciliation**

Register the JWT-authenticated function, authorize a contract participant or financial operator, rate-limit, retrieve only the server-stored provider ID, validate environment/amount/currency/metadata, reduce state monotonically, and return a caller-safe status. Record stale or mismatched provider facts as incidents; never regress `SUCCEEDED` because of an older event.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; deno test supabase/functions/_tests/stripe_payment_status_test.ts; node scripts/qa-stripe-monotonic-reconciliation.mjs`

Expected GREEN: out-of-order events cannot regress state, unknown outcomes reconcile before retry, and cross-user status lookup is denied without revealing existence.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_funding_attempts_and_state_v1.sql supabase/config.toml supabase/functions/stripe-get-job-payment-status supabase/functions/_tests/stripe_payment_status_test.ts scripts/stripe-qa-suites.mjs scripts/qa-stripe-monotonic-reconciliation.mjs
git commit -m "feat(payments): reconcile payment state monotonically"
```

## Phase 5 — Settlement, Exact Transfers, Refunds, and Ledger

### Task 12: Create the balanced double-entry ledger

**Files:**
- Create via Supabase CLI: `supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-ledger-balance.mjs`

**Interfaces:**
- Consumes: authoritative payment, settlement, transfer, refund, tip, dispute, payout, and provider-fee facts.
- Produces: `private.stripe_ledger_accounts`, `private.stripe_ledger_transactions`, `private.stripe_ledger_entries`, `private.stripe_provider_costs`, `private.post_stripe_ledger_transaction_v1`, `stripe_server_record_provider_cost_v1`, source-event idempotency, and deferred balance enforcement.

- [ ] **Step 1: Write failing ledger tests**

Assert each transaction has at least two entries, debits equal credits per currency, cents are positive integers, source keys are unique, posted rows are immutable, cross-environment account use is rejected, duplicate source replay returns the existing transaction without new entries, a provider-confirmed capture posts cash against captured-funds liability without earnings/revenue, and Stripe/Radar Pro/Connect/payout/refund-retained/dispute/tip provider costs are source-idempotent.

- [ ] **Step 2: Run the test to verify RED**

Run: `node scripts/qa-stripe-ledger-balance.mjs`

Expected RED: ledger relations and posting function do not exist.

- [ ] **Step 3: Generate and write the ledger migration**

Run `npx supabase migration new mort_stripe_settlement_ledger_v1`. Seed per-environment USD accounts for Stripe cash/clearing, captured job funds liability, refund payable, teen earnings payable, tip payable, MORT service-fee revenue, Stripe processing expense, Radar Pro expense, Connect routing expense, payout expense, chargeback loss, recovery receivable, and unrecovered loss/reserve. Use transaction-level deferred validation so an unbalanced posting cannot commit. Replace `stripe_server_apply_payment_event_v2` additively so first provider-confirmed capture posts the gross liability exactly once. Store provider-cost facts by provider balance-transaction/event source and post each expense against clearing without inferring cost from the MORT fee.

The private posting interface accepts one canonical JSON entry array:

```json
{"source_type":"funding_capture","source_id":"uuid","currency":"USD","entries":[{"account_key":"stripe_cash_clearing","side":"debit","amount_cents":10800},{"account_key":"captured_job_funds_liability","side":"credit","amount_cents":10800}]}
```

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-stripe-ledger-balance.mjs`

Expected GREEN: balanced/idempotent postings commit; unbalanced, mutable, cross-environment, negative, and duplicate-conflict fixtures fail atomically.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql scripts/stripe-qa-suites.mjs scripts/qa-stripe-ledger-balance.mjs
git commit -m "feat(payments): add balanced Stripe ledger"
```

### Task 13: Add authoritative settlement and compensated-base calculation

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql`
- Create: `supabase/functions/_shared/stripe_settlement.ts`
- Create: `supabase/functions/_tests/stripe_settlement_test.ts`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-settlement.mjs`

**Interfaces:**
- Consumes: completed/canceled/disputed job facts, selected versioned policy, captured funding liability, and authorized settlement decision.
- Produces: `private.stripe_job_settlements`, `stripe_server_prepare_settlement_v1`, `stripe_server_finalize_settlement_v1`, exact teen earnings/service fee/adult refund components, and settlement ledger postings.

- [ ] **Step 1: Write failing integer-math and authorization tests**

Use table fixtures for zero, partial, and full compensation, plus fee minimum/cap/rounding boundaries. Assert:

```text
teenTransfer = compensatedBase
adultBaseRefund = quotedBase - compensatedBase
adultFeeRefund = fee(quotedBase) - fee(compensatedBase)
adultRefund = adultBaseRefund + adultFeeRefund
MORTFee = fee(compensatedBase)
```

Also assert only an authoritative terminal job/cancellation/dispute path and properly separated reviewer/operator can prepare/finalize settlement.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_settlement_test.ts; node scripts/qa-stripe-settlement.mjs`

Expected RED: settlement module, table, and v1 RPCs are missing.

- [ ] **Step 3: Implement minimal settlement**

Export pure `calculateServiceFeeCents` and `calculateSettlement` functions using integer cents. The prepare RPC locks job/payment/policy rows, derives `compensated_base_cents` server-side, snapshots every component and policy ID, and creates one pending settlement. Finalize recognizes teen payable and MORT fee revenue only once, retains refund payable for refundable components, and posts a balanced ledger transaction. Captured funding by itself creates no earnings/revenue.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; deno test supabase/functions/_tests/stripe_settlement_test.ts; node scripts/qa-stripe-settlement.mjs; node scripts/qa-stripe-ledger-balance.mjs`

Expected GREEN: exact fixtures pass, settlement is idempotent, earnings appear only after finalization, and every settlement posting balances.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql supabase/functions/_shared/stripe_settlement.ts supabase/functions/_tests/stripe_settlement_test.ts scripts/stripe-qa-suites.mjs scripts/qa-stripe-settlement.mjs
git commit -m "feat(payments): settle authoritative compensation"
```

### Task 14: Execute the exact separate Connect transfer

**Files:**
- Modify: `supabase/functions/stripe-create-job-transfer/index.ts`
- Modify: `supabase/functions/stripe-resolve-job-payment/index.ts`
- Create: `supabase/functions/_tests/stripe_transfer_test.ts`
- Modify: `scripts/qa-stripe-transfer-eligibility.mjs`
- Modify: `scripts/qa-stripe-transfer-duplication.mjs`

**Interfaces:**
- Consumes: finalized settlement, ready connected account, exact teen earnings payable, transfer runtime gate.
- Produces: `stripe_server_prepare_transfer_v2`, a Stripe Transfer with settlement amount/destination/transfer group/source transaction where applicable, and `stripe_server_record_transfer_v2`.

- [ ] **Step 1: Write failing transfer tests**

Assert no transfer before settlement, no transfer to unready/minor-incomplete account, amount equals `compensated_base_cents`, destination comes only from the server, one stable idempotency key is used, and retries cannot create a second transfer.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_transfer_test.ts; node scripts/qa-stripe-transfer-eligibility.mjs; node scripts/qa-stripe-transfer-duplication.mjs`

Expected RED: existing transfer path prepares the legacy earnings amount and lacks settlement-v2 binding.

- [ ] **Step 3: Implement exact transfer execution**

Extend the existing resolver/action boundary; do not create another general operations endpoint. The prepare RPC locks settlement/account/payment, returns exact cents/currency/destination/transfer group/idempotency key, and refuses instant-payout parameters. Record provider transfer success/failure and post clearing-to-teen-payable movement without marking bank payout complete.

- [ ] **Step 4: Verify GREEN**

Run: `deno test supabase/functions/_tests/stripe_transfer_test.ts; node scripts/qa-stripe-transfer-eligibility.mjs; node scripts/qa-stripe-transfer-duplication.mjs; node scripts/qa-stripe-ledger-balance.mjs`

Expected GREEN: one exact separate transfer is prepared/recorded per settlement, and no destination-charge field exists in the primary charge flow.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/stripe-create-job-transfer supabase/functions/stripe-resolve-job-payment supabase/functions/_tests/stripe_transfer_test.ts scripts/qa-stripe-transfer-eligibility.mjs scripts/qa-stripe-transfer-duplication.mjs
git commit -m "feat(payments): transfer exact settled earnings"
```

### Task 15: Add component-aware refunds

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql`
- Modify: `supabase/functions/stripe-create-job-refund/index.ts`
- Create: `supabase/functions/_tests/stripe_refund_test.ts`
- Modify: `scripts/qa-stripe-refund.mjs`
- Modify: `scripts/qa-stripe-refund-webhook-reconciliation.mjs`

**Interfaces:**
- Consumes: finalized settlement refund components and original platform charge.
- Produces: `private.stripe_refund_components`, `stripe_server_prepare_component_refund_v1`, `stripe_server_record_refund_v2`, one provider refund for the sum of authorized remaining components, and component ledger postings.

- [ ] **Step 1: Write failing component tests**

Cover full refund, base-only remainder, fee-only difference, mixed partial refund, duplicate request, provider partial success/pending/failure, over-refund attempt, and a forged client amount. Assert each component references its settlement/policy source and total refunded never exceeds captured gross.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_refund_test.ts; node scripts/qa-stripe-refund.mjs; node scripts/qa-stripe-refund-webhook-reconciliation.mjs`

Expected RED: legacy refund preparation has no component table or v1 component RPC.

- [ ] **Step 3: Implement component-aware refunding**

Prepare server-side components `uncompensated_base` and `unearned_service_fee`, sum only unrefunded authorized cents, call Stripe with a stable idempotency key and original PaymentIntent/charge, then record status through v2. Post refund-payable/clearing entries only from provider-confirmed facts; pending/failed states do not fabricate completion.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; deno test supabase/functions/_tests/stripe_refund_test.ts; node scripts/qa-stripe-refund.mjs; node scripts/qa-stripe-refund-webhook-reconciliation.mjs; node scripts/qa-stripe-ledger-balance.mjs`

Expected GREEN: exact component totals pass, duplicate calls are safe, webhook reconciliation is monotonic, and over-refunds are impossible.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql supabase/functions/stripe-create-job-refund supabase/functions/_tests/stripe_refund_test.ts scripts/qa-stripe-refund.mjs scripts/qa-stripe-refund-webhook-reconciliation.mjs
git commit -m "feat(payments): add component-aware refunds"
```

### Task 16: Add transfer reversal and platform recovery handling

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql`
- Modify: `supabase/functions/stripe-resolve-job-payment/index.ts`
- Modify: `supabase/functions/stripe-webhook/index.ts`
- Create: `supabase/functions/_tests/stripe_transfer_reversal_test.ts`
- Modify: `scripts/qa-stripe-transfer-reversal.mjs`
- Create: `scripts/qa-stripe-recovery-loss.mjs`

**Interfaces:**
- Consumes: authorized reversal/recovery decision, prior transfer, Stripe reversal/provider events.
- Produces: exact bounded reversal, recovery receivable or platform loss/reserve posting, financial incident, and no automatic teen debt/clawback.

- [ ] **Step 1: Write failing reversal/recovery tests**

Cover reversal before transfer, exact/full/partial reversal, duplicate reversal, reversal above unreversed amount, insufficient connected balance, adult chargeback after teen transfer, and provider reversal failure. Assert no teen profile balance is debited and no future earnings offset is created automatically.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_transfer_reversal_test.ts; node scripts/qa-stripe-transfer-reversal.mjs; node scripts/qa-stripe-recovery-loss.mjs`

Expected RED: recovery/loss ledger outcomes and no-clawback assertions are absent.

- [ ] **Step 3: Implement bounded recovery**

Require an audited operator decision, cap reversal to unreversed transfer cents, call Stripe with a stable idempotency key, and record provider state monotonically. If reversal cannot recover funds, post a recovery receivable when a separate lawful recovery process is approved; otherwise post unrecovered platform loss/reserve. Never mutate teen earnings payable or create an automatic offset.

- [ ] **Step 4: Verify GREEN**

Run: `deno test supabase/functions/_tests/stripe_transfer_reversal_test.ts; node scripts/qa-stripe-transfer-reversal.mjs; node scripts/qa-stripe-recovery-loss.mjs; node scripts/qa-stripe-ledger-balance.mjs`

Expected GREEN: reversal totals are bounded/idempotent, failure creates an incident and balanced loss/recovery posting, and teen clawback remains absent.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql supabase/functions/stripe-resolve-job-payment supabase/functions/stripe-webhook supabase/functions/_tests/stripe_transfer_reversal_test.ts scripts/qa-stripe-transfer-reversal.mjs scripts/qa-stripe-recovery-loss.mjs
git commit -m "feat(payments): handle transfer reversal recovery"
```

## Phase 6 — Separate Tips, Disputes, Recovery, and Payout Separation

### Task 17: Build the separate post-work tip flow

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql`
- Create: `supabase/functions/stripe-create-job-tip-payment-intent/index.ts`
- Modify: `supabase/config.toml`
- Create: `supabase/functions/_tests/stripe_tip_payment_test.ts`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-tip-payment.mjs`

**Interfaces:**
- Consumes: authenticated adult, settled job ID, server-validated tip cents, request ID, ready teen account.
- Produces: `stripe_server_prepare_tip_payment_v1`, separate platform PaymentIntent/attempt, `stripe_server_finalize_tip_v1`, 100% teen tip payable, and separate Connect transfer.

- [ ] **Step 1: Write failing tip tests**

Test contemporaneous and later tips, uncompleted job, wrong adult, zero/negative/over-limit cents, client fee injection, duplicate request, failed/unknown tip, and successful tip. Assert MORT fee is zero, Fair Pay excludes tips, base settlement is unchanged, and teen tip payable equals captured tip cents.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_tip_payment_test.ts; node scripts/qa-stripe-tip-payment.mjs`

Expected RED: tip RPC and Edge Function do not exist.

- [ ] **Step 3: Implement separate tip payment and transfer**

Persist a tip operation linked to the settled job but not its base PaymentIntent. Create a separate platform PaymentIntent with its own transfer group/idempotency key, finalize only after provider success, post 100% to tip payable, record MORT-absorbed provider cost, and create a separate exact transfer to the ready connected account. A tip failure remains a tip-only terminal state.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; deno test supabase/functions/_tests/stripe_tip_payment_test.ts; node scripts/qa-stripe-tip-payment.mjs; node scripts/qa-stripe-ledger-balance.mjs`

Expected GREEN: tip and base lifecycles are independent, 100% of successful tip principal is teen-owned, and failed tips do not affect settlement.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql supabase/config.toml supabase/functions/stripe-create-job-tip-payment-intent supabase/functions/_tests/stripe_tip_payment_test.ts scripts/stripe-qa-suites.mjs scripts/qa-stripe-tip-payment.mjs
git commit -m "feat(payments): add separate post-work tips"
```

### Task 18: Complete dispute and chargeback accounting

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql`
- Modify: `supabase/functions/stripe-webhook/index.ts`
- Modify: `supabase/functions/stripe-resolve-job-payment/index.ts`
- Create: `supabase/functions/_tests/stripe_dispute_test.ts`
- Modify: `scripts/qa-stripe-dispute-hold.mjs`
- Create: `scripts/qa-stripe-chargeback-accounting.mjs`

**Interfaces:**
- Consumes: Stripe dispute events, existing MORT dispute review/role separation, settlement/transfer/refund state.
- Produces: dispute liability/fee/loss postings, transfer hold before release, evidence due-date status, won/lost closure, and audited operator recovery decisions.

- [ ] **Step 1: Write failing dispute tests**

Cover dispute before settlement, dispute after settlement before transfer, dispute after transfer, partial dispute, duplicate/out-of-order events, won/lost, network fees, and chargeback with unavailable reversal. Assert reviewer/operator separation and no automatic teen clawback.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_dispute_test.ts; node scripts/qa-stripe-dispute-hold.mjs; node scripts/qa-stripe-chargeback-accounting.mjs`

Expected RED: ledger dispute outcomes and post-transfer chargeback loss cases are incomplete.

- [ ] **Step 3: Implement dispute accounting**

Hold unsettled/untransferred funds on open disputes, persist provider amount/status/reason/due date, and post chargeback principal plus provider fees from verified events. Winning reverses the temporary loss/receivable as a linked ledger transaction; losing finalizes platform loss/recovery state. Human decisions remain in the existing reviewed-resolution workflow.

- [ ] **Step 4: Verify GREEN**

Run: `deno test supabase/functions/_tests/stripe_dispute_test.ts; node scripts/qa-stripe-dispute-hold.mjs; node scripts/qa-stripe-chargeback-accounting.mjs; node scripts/qa-stripe-ledger-balance.mjs`

Expected GREEN: dispute events are monotonic/idempotent, transfer release is held where required, and won/lost accounting balances without teen auto-clawback.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql supabase/functions/stripe-webhook supabase/functions/stripe-resolve-job-payment supabase/functions/_tests/stripe_dispute_test.ts scripts/qa-stripe-dispute-hold.mjs scripts/qa-stripe-chargeback-accounting.mjs
git commit -m "feat(payments): account for disputes and chargebacks"
```

### Task 19: Preserve transfer/earnings/payout status separation

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql`
- Modify: `supabase/functions/stripe-get-connected-account-status/index.ts`
- Modify: `supabase/functions/stripe-webhook/index.ts`
- Modify: `scripts/qa-stripe-payout-status.mjs`

**Interfaces:**
- Consumes: connected-account payout events and transfer/settlement state.
- Produces: independent `earnings_status`, `transfer_status`, and `latest_payout_status`; standard-payout-only runtime constraints.

- [ ] **Step 1: Write failing separation tests**

Assert transfer success does not claim bank payout success, payout failure does not reverse earned status, unrelated payouts cannot attach to a job transfer, and instant-payout configuration/wording is absent.

- [ ] **Step 2: Run test to verify RED**

Run: `node scripts/qa-stripe-payout-status.mjs`

Expected RED: current minimized payout status lacks the three explicit independent lifecycle fields.

- [ ] **Step 3: Extend payout projections and constraints**

Store payout events as connected-account facts; link to a job only when provider balance-transaction evidence allows it, otherwise keep them account-level. Return separate statuses and standard payout cadence. Never present estimated arrival as confirmed deposit.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-stripe-payout-status.mjs`

Expected GREEN: earnings, transfer, and payout states change independently and UI-safe projections make no deposit guarantee.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_settlement_ledger_v1.sql supabase/functions/stripe-get-connected-account-status supabase/functions/stripe-webhook scripts/qa-stripe-payout-status.mjs
git commit -m "feat(payments): separate payout and earnings status"
```

## Phase 7 — Immutable Documents and Financial History

### Task 20: Create immutable financial documents and numbering

**Files:**
- Create via Supabase CLI: `supabase/migrations/*_mort_stripe_documents_history_v1.sql`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-financial-documents.mjs`

**Interfaces:**
- Consumes: finalized settlement/tip/refund/adjustment/dispute ledger facts.
- Produces: `private.stripe_financial_documents`, line items, links, environment-scoped sequences, immutable snapshots, and `get_my_financial_document_v1`.

- [ ] **Step 1: Write failing document tests**

Assert no receipt is issued for ready/processing/failed/declined/canceled/unknown funding; adult receipt appears after settlement; teen earnings receipt appears after earnings credit; tip/refund/adjustment documents are linked; numbering is unique; issued content cannot update/delete; cross-user enumeration returns the same not-found response.

- [ ] **Step 2: Run test to verify RED**

Run: `node scripts/qa-stripe-financial-documents.mjs`

Expected RED: immutable document relations and v1 lookup do not exist.

- [ ] **Step 3: Generate and write the document migration**

Run `npx supabase migration new mort_stripe_documents_history_v1`. Store document kind, number, audience user, environment, currency, issued time, source ledger transaction, counterparty-safe snapshot, and immutable line items. Use an environment/year/type numbering allocator locked in the same transaction. Replace the dynamic receipt summary only through the new caller-bound v1 contract; keep legacy RPC compatibility until Flutter switches.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-stripe-financial-documents.mjs`

Expected GREEN: documents issue exactly once from finalized facts, mutation attempts fail, numbering is collision-safe, and unauthorized lookup reveals nothing.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_documents_history_v1.sql scripts/stripe-qa-suites.mjs scripts/qa-stripe-financial-documents.mjs
git commit -m "feat(payments): issue immutable financial documents"
```

### Task 21: Add authorized financial history and document Edge adapters

**Files:**
- Create: `supabase/functions/stripe-get-financial-document/index.ts`
- Create: `supabase/functions/stripe-list-financial-history/index.ts`
- Modify: `supabase/config.toml`
- Create: `supabase/functions/_tests/stripe_financial_history_test.ts`
- Modify: `supabase/migrations/*_mort_stripe_documents_history_v1.sql`
- Create: `scripts/qa-stripe-financial-history.mjs`

**Interfaces:**
- Consumes: authenticated caller, opaque cursor, optional year/kind/search, receipt/document number.
- Produces: `get_my_financial_history_v1(cursor,limit,year,kinds,search)` and minimized Edge responses with document links only for authorized issued documents.

- [ ] **Step 1: Write failing history tests**

Cover descending stable pagination with tie-break ID, limit bounds, malformed cursor, year/kind filters, normalized search, failed attempt rows marked `no_receipt`, cross-user document number, and no provider/customer/account IDs in responses.

- [ ] **Step 2: Run tests to verify RED**

Run: `deno test supabase/functions/_tests/stripe_financial_history_test.ts; node scripts/qa-stripe-financial-history.mjs`

Expected RED: Edge adapters and history RPC are absent.

- [ ] **Step 3: Implement caller-bound reads**

Create a unioned chronological projection for funding attempts, settlements, transfers, refunds, tips, disputes, adjustments, and payouts. Bind `auth.uid()` inside the RPC, cap page size at 50, use opaque base64url `(occurred_at,id)` cursor, and search only safe display fields. Edge Functions authenticate/rate-limit and forward minimized results.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; deno test supabase/functions/_tests/stripe_financial_history_test.ts; node scripts/qa-stripe-financial-history.mjs`

Expected GREEN: pagination/filter/search are stable, failed attempts never claim receipts, and all object/document access is caller-scoped.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_documents_history_v1.sql supabase/config.toml supabase/functions/stripe-get-financial-document supabase/functions/stripe-list-financial-history supabase/functions/_tests/stripe_financial_history_test.ts scripts/qa-stripe-financial-history.mjs
git commit -m "feat(payments): expose financial documents and history"
```

## Phase 8 — RLS, Rate Limits, Audit, Observability, and Activation Gates

### Task 22: Harden all financial access boundaries

**Files:**
- Create via Supabase CLI: `supabase/migrations/*_mort_stripe_financial_access_and_activation_v1.sql`
- Modify: `scripts/stripe-qa-suites.mjs`
- Create: `scripts/qa-stripe-financial-access.mjs`
- Modify: `scripts/qa-rls-cross-user-exploit.mjs`

**Interfaces:**
- Consumes: every table/function added in Tasks 1–21 and existing MORT financial roles.
- Produces: forced RLS, explicit grants, hardened definers, caller-bound read APIs, service-only mutation wrappers, and hostile-client denial evidence.

- [ ] **Step 1: Write failing hostile-client tests**

As anon, adult A, adult B, teen A, teen B, guardian, ordinary admin, reviewer, operator, and service role, attempt direct table access, cross-user RPC reads, direct service RPC execution, role forgery, user-ID substitution, document enumeration, and ledger mutation. Require denials except the exact caller-bound/assigned-role cases.

- [ ] **Step 2: Run tests to verify RED**

Run: `node scripts/qa-stripe-financial-access.mjs; node scripts/qa-rls-cross-user-exploit.mjs`

Expected RED: new objects do not yet have the final consolidated grants and hostile-client contract.

- [ ] **Step 3: Generate and write the access migration**

Run `npx supabase migration new mort_stripe_financial_access_and_activation_v1`. Enable and force RLS on every private table, revoke all from `PUBLIC`, `anon`, and `authenticated`, grant table access only to service role as needed, and grant authenticated execution only on caller-bound read/status RPCs. Inventory every definer function, set blank search path, schema-qualify all objects, require service role or `auth.uid()` plus role assignment, and explicitly revoke default execute grants.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-stripe-financial-access.mjs; node scripts/qa-rls-cross-user-exploit.mjs; node scripts/audit-supabase-advisors.mjs`

Expected GREEN: hostile clients cannot read/mutate another user's financial data or call service mutations; authorized caller projections and assigned operations roles still work; database security advisors report no new issue.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_financial_access_and_activation_v1.sql scripts/stripe-qa-suites.mjs scripts/qa-stripe-financial-access.mjs scripts/qa-rls-cross-user-exploit.mjs
git commit -m "security(payments): harden financial access controls"
```

### Task 23: Add rate limits, audit events, reconciliation operations, and conjunctive activation gates

**Files:**
- Modify: `supabase/migrations/*_mort_stripe_financial_access_and_activation_v1.sql`
- Modify: `supabase/functions/_shared/stripe.ts`
- Modify: `supabase/functions/stripe-config/index.ts`
- Modify: `docs/payments/MORT_STRIPE_INCIDENT_RESPONSE.md`
- Modify: `docs/payments/MORT_STRIPE_RECONCILIATION.md`
- Modify: `scripts/qa-stripe-mode-isolation.mjs`
- Create: `scripts/qa-stripe-activation-gates.mjs`
- Create: `scripts/qa-stripe-observability.mjs`

**Interfaces:**
- Consumes: runtime controls, policy approvals, provider readiness, QA evidence, reconciliation incidents, operator secret.
- Produces: per-action limits, safe structured audit/metrics, reconciliation claim/resolve APIs, Radar Pro configuration record, and fail-closed sandbox/live gates.

- [ ] **Step 1: Write failing operations tests**

Test per-user funding/status/tip/document/history limits, global provider mutation budget, redacted logs, trace IDs, incident idempotency, stale-record reconciliation leases, Radar Pro selected flag, all production gates conjunctive, live-mode denial when any one gate is false, production pricing unapproved, and production partial-comp values absent.

- [ ] **Step 2: Run tests to verify RED**

Run: `node scripts/qa-stripe-activation-gates.mjs; node scripts/qa-stripe-observability.mjs; node scripts/qa-stripe-mode-isolation.mjs`

Expected RED: final activation evidence fields and reconciliation/rate-limit cases are missing.

- [ ] **Step 3: Implement final operational controls**

Extend runtime controls with evidence timestamps/actors for each production gate, selected fraud product `radar_pro`, standard-payout-only mode, production pricing approval, production partial-comp approval, and live owner approval. Update `private.stripe_live_financial_ready()` to require every gate. Add reconciliation run/lease/result audit contracts and safe metrics keyed by environment/operation/result code only. Update shared runtime to require the operation-specific sandbox gate and global budget before provider mutation. Keep `stripe-config` authenticated and return the publishable key only when sandbox/mobile gates pass, alongside explicit `mode` and `environment`; never return secret or webhook credentials. Document forward-only recovery: disable mutation gates, preserve reads/webhooks/reconciliation, reclaim leases, reconcile provider facts, repair schema with a new migration, and represent corrections as linked adjustment/reversal transactions rather than editing history.

- [ ] **Step 4: Apply and verify GREEN**

Run: `powershell -ExecutionPolicy Bypass -File scripts/local-supabase-reset.ps1; node scripts/qa-stripe-activation-gates.mjs; node scripts/qa-stripe-observability.mjs; node scripts/qa-stripe-mode-isolation.mjs`

Expected GREEN: sandbox starts disabled, Radar Pro is selected, production remains impossible without every approval, logs contain no sensitive value, and reconciliation work is leased/idempotent.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_mort_stripe_financial_access_and_activation_v1.sql supabase/functions/_shared/stripe.ts supabase/functions/stripe-config scripts/qa-stripe-activation-gates.mjs scripts/qa-stripe-observability.mjs scripts/qa-stripe-mode-isolation.mjs docs/payments/MORT_STRIPE_INCIDENT_RESPONSE.md docs/payments/MORT_STRIPE_RECONCILIATION.md
git commit -m "feat(payments): add operational and activation gates"
```

## Phase 9 — Flutter Stripe SDK and Payment OS Data Wiring

### Task 24: Add and platform-configure the Flutter Stripe SDK

**Files:**
- Modify: `flutter_mort/pubspec.yaml`
- Modify: `flutter_mort/pubspec.lock`
- Modify: `flutter_mort/android/app/src/main/kotlin/com/mortapp/mobile/MainActivity.kt`
- Modify: `flutter_mort/android/app/build.gradle.kts`
- Modify: `flutter_mort/ios/Podfile`
- Modify: `flutter_mort/ios/Runner/AppDelegate.swift`
- Modify: `flutter_mort/lib/main.dart`
- Modify: `flutter_mort/lib/core/config/app_config.dart`
- Modify: `flutter_mort/test/stripe_marketplace_contract_test.dart`
- Create: `flutter_mort/test/features/payments/stripe_sdk_configuration_test.dart`

**Interfaces:**
- Consumes: authenticated sandbox `stripe-config` response containing a test publishable key and environment metadata.
- Produces: compiled native `flutter_stripe` support, runtime initialization only for validated sandbox config, and a fail-closed unsupported/disabled path.

- [ ] **Step 1: Write failing safe-initialization tests and replace the old absence assertion**

Assert the SDK dependency is present and pinned in the lockfile, native platform requirements match current official guidance, no publishable key is hardcoded, live keys/config are rejected while live activation is false, web stays unsupported for PaymentSheet, and missing sandbox config leaves payment actions disabled.

- [ ] **Step 2: Run tests to verify RED**

Run: `cd flutter_mort; flutter test test/features/payments/stripe_sdk_configuration_test.dart test/stripe_marketplace_contract_test.dart`

Expected RED: `flutter_stripe` is absent and `nativeStripePaymentSheetCompiledIn` remains false.

- [ ] **Step 3: Add the SDK using current official requirements**

Inspect the current official package/platform guidance, run `flutter pub add flutter_stripe`, retain the resolved exact version in `pubspec.lock`, and update Android/iOS bootstrap files only as required by that version. Initialize `Stripe.publishableKey` from the authenticated `stripe-config` response after it reports `mode=sandbox`, `environment=test`, and all mobile gates true; never use a secret key or webhook secret in Flutter.

- [ ] **Step 4: Run focused GREEN checks**

Run: `cd flutter_mort; flutter pub get; dart format --output=none --set-exit-if-changed lib test; flutter analyze; flutter test test/features/payments/stripe_sdk_configuration_test.dart test/stripe_marketplace_contract_test.dart`

Expected GREEN: dependency/platform checks pass, analyzer is clean, sandbox config can initialize the SDK, and absent/live/mismatched config fails closed without exposing a key value in logs.

- [ ] **Step 5: Commit**

```bash
git add flutter_mort/pubspec.yaml flutter_mort/pubspec.lock flutter_mort/android/app/src/main/kotlin/com/mortapp/mobile/MainActivity.kt flutter_mort/android/app/build.gradle.kts flutter_mort/ios/Podfile flutter_mort/ios/Runner/AppDelegate.swift flutter_mort/lib/main.dart flutter_mort/lib/core/config/app_config.dart flutter_mort/test/stripe_marketplace_contract_test.dart flutter_mort/test/features/payments/stripe_sdk_configuration_test.dart
git commit -m "feat(mobile): configure Stripe PaymentSheet SDK"
```

### Task 25: Add typed Payment OS models for quotes, status, documents, history, and payouts

**Files:**
- Modify: `flutter_mort/lib/features/payments/models/payment_state.dart`
- Modify: `flutter_mort/lib/features/payments/models/fair_pay.dart`
- Modify: `flutter_mort/lib/features/payments/models/tipping.dart`
- Modify: `flutter_mort/lib/features/history/models/payment_history.dart`
- Modify: `flutter_mort/lib/features/receipts/models/receipt_document.dart`
- Create: `flutter_mort/lib/features/payments/models/stripe_payment_models.dart`
- Create: `flutter_mort/test/features/payments/stripe_payment_models_test.dart`

**Interfaces:**
- Consumes: v1 backend JSON contracts from Tasks 3, 11, 17, 19, 20, and 21.
- Produces: immutable Dart types `MortFundingQuote`, `MortJobPaymentStatus`, `MortTipPayment`, `MortPayoutStatus`, `MortFinancialDocument`, and `MortFinancialHistoryPage` with strict parsing.

- [ ] **Step 1: Write failing parser/state tests**

Add exact JSON fixtures for every payment state, expired quote, settlement component, failed attempt with no receipt, teen/adult documents, independent payout status, and malformed/missing fields. Assert unknown enum values map to a fail-closed display state and invalid cents/currency throw a coded error.

- [ ] **Step 2: Run test to verify RED**

Run: `cd flutter_mort; flutter test test/features/payments/stripe_payment_models_test.dart`

Expected RED: model classes and strict parsers do not exist.

- [ ] **Step 3: Implement immutable typed models**

Use `const` value objects with explicit `fromJson`, uppercase USD validation, nonnegative integer cents, ISO timestamp parsing, and server-provided capability flags. Keep `MortPaymentState` names aligned exactly with the backend normalized wire values through one `fromWire` function.

- [ ] **Step 4: Verify GREEN**

Run: `cd flutter_mort; dart format --output=none --set-exit-if-changed lib/features/payments/models lib/features/history/models lib/features/receipts/models test/features/payments/stripe_payment_models_test.dart; flutter test test/features/payments/stripe_payment_models_test.dart test/features/payments/contract_payment_state_test.dart`

Expected GREEN: all valid fixtures parse, malformed financial responses fail closed, and existing state behavior remains compatible.

- [ ] **Step 5: Commit**

```bash
git add flutter_mort/lib/features/payments/models/payment_state.dart flutter_mort/lib/features/payments/models/fair_pay.dart flutter_mort/lib/features/payments/models/tipping.dart flutter_mort/lib/features/payments/models/stripe_payment_models.dart flutter_mort/lib/features/history/models/payment_history.dart flutter_mort/lib/features/receipts/models/receipt_document.dart flutter_mort/test/features/payments/stripe_payment_models_test.dart
git commit -m "feat(mobile): model authoritative Stripe payment state"
```

### Task 26: Wire typed repositories and PaymentSheet service

**Files:**
- Modify: `flutter_mort/lib/data/repositories/stripe_marketplace_repository.dart`
- Modify: `flutter_mort/lib/data/repositories/financial_repository.dart`
- Modify: `flutter_mort/lib/data/repositories/providers.dart`
- Modify: `flutter_mort/lib/features/payments/stripe_payment_sheet_service.dart`
- Create: `flutter_mort/test/features/payments/stripe_marketplace_repository_test.dart`
- Create: `flutter_mort/test/features/payments/stripe_payment_sheet_service_test.dart`

**Interfaces:**
- Consumes: new quote/status/tip/document/history Edge Functions and `flutter_stripe` PaymentSheet.
- Produces: typed repository methods `createFundingQuote`, `createBasePaymentIntent`, `getJobPaymentStatus`, `createTipPaymentIntent`, `getFinancialDocument`, `listFinancialHistory`; injectable `StripePaymentSheetGateway`.

- [ ] **Step 1: Write failing repository/service tests**

Use fake Supabase/function clients and fake PaymentSheet gateway. Assert repository sends IDs/request IDs only, never cents for base funding, reuses a caller-generated request ID for one logical retry, status-before-retry runs for `UNKNOWN`, PaymentSheet cancellation stays non-success, and only server status can mark a job funded.

- [ ] **Step 2: Run tests to verify RED**

Run: `cd flutter_mort; flutter test test/features/payments/stripe_marketplace_repository_test.dart test/features/payments/stripe_payment_sheet_service_test.dart`

Expected RED: typed methods and injectable gateway are missing; current service always throws disabled.

- [ ] **Step 3: Implement repository and PaymentSheet boundaries**

Split invocation parsing from UI messages, keep request IDs stable per operation object, and call `Stripe.instance.initPaymentSheet`/`presentPaymentSheet` through the gateway. Treat PaymentSheet completion as “client interaction finished,” then call status; never set `SUCCEEDED` locally. Map provider/client errors to safe codes without logging secrets/client secrets.

- [ ] **Step 4: Verify GREEN**

Run: `cd flutter_mort; dart format --output=none --set-exit-if-changed lib test/features/payments; flutter analyze; flutter test test/features/payments/stripe_marketplace_repository_test.dart test/features/payments/stripe_payment_sheet_service_test.dart test/stripe_marketplace_contract_test.dart`

Expected GREEN: request bodies are server-authority-safe, status-before-retry is enforced, PaymentSheet is injectable/testable, and no mobile code contains provider secrets.

- [ ] **Step 5: Commit**

```bash
git add flutter_mort/lib/data/repositories/stripe_marketplace_repository.dart flutter_mort/lib/data/repositories/financial_repository.dart flutter_mort/lib/data/repositories/providers.dart flutter_mort/lib/features/payments/stripe_payment_sheet_service.dart flutter_mort/test/features/payments/stripe_marketplace_repository_test.dart flutter_mort/test/features/payments/stripe_payment_sheet_service_test.dart
git commit -m "feat(mobile): wire Stripe repositories and PaymentSheet"
```

## Phase 10 — Flutter Funding, Tip, Document, History, and Payout UI

### Task 27: Connect funding and job-start UI to authoritative status

**Files:**
- Modify: `flutter_mort/lib/features/payments/stripe_marketplace_screens.dart`
- Modify: `flutter_mort/lib/features/payments/widgets/payment_state_panel.dart`
- Modify: `flutter_mort/lib/features/jobs/job_progress_screen.dart`
- Modify: `flutter_mort/lib/data/repositories/job_execution_repository.dart`
- Modify: `flutter_mort/lib/core/routing/app_router.dart`
- Modify: `flutter_mort/test/features/payment_os_integration_test.dart`
- Create: `flutter_mort/test/features/payments/job_funding_flow_test.dart`

**Interfaces:**
- Consumes: typed quote, PaymentSheet result, backend payment status, server job-start denial.
- Produces: quote review/expiry refresh, state-specific actions, no local funded mutation, and a disabled start action until backend reports startable.

- [ ] **Step 1: Write failing funding-flow widget tests**

Cover quote totals/expiry, processing/requires-action/pending/unknown/declined/cancelled/succeeded displays, unknown status refresh before retry, double-tap suppression, PaymentSheet cancellation, provider outage, and job start disabled until `startable=true`. Test compact width, 200% text, semantics, and non-color status labels.

- [ ] **Step 2: Run tests to verify RED**

Run: `cd flutter_mort; flutter test test/features/payments/job_funding_flow_test.dart test/features/payment_os_integration_test.dart`

Expected RED: funding screen uses the legacy preview/map contract and job progress does not consume the new startable projection.

- [ ] **Step 3: Implement the authoritative flow**

Load/create the immutable quote, submit its ID, present PaymentSheet, then poll/refresh the status endpoint with bounded backoff while visible. Render server reason codes and permit retry only when status says it is safe. Job start continues through the existing server transition; UI availability mirrors, but never replaces, the database guard.

- [ ] **Step 4: Verify GREEN**

Run: `cd flutter_mort; dart format --output=none --set-exit-if-changed lib test/features/payments; flutter analyze; flutter test test/features/payments/job_funding_flow_test.dart test/features/payment_os_integration_test.dart test/job_progress_widget_test.dart`

Expected GREEN: all states render safely, no duplicate submission occurs, and start remains blocked until server-confirmed capture/startability.

- [ ] **Step 5: Commit**

```bash
git add flutter_mort/lib/features/payments/stripe_marketplace_screens.dart flutter_mort/lib/features/payments/widgets/payment_state_panel.dart flutter_mort/lib/features/jobs/job_progress_screen.dart flutter_mort/lib/data/repositories/job_execution_repository.dart flutter_mort/lib/core/routing/app_router.dart flutter_mort/test/features/payment_os_integration_test.dart flutter_mort/test/features/payments/job_funding_flow_test.dart
git commit -m "feat(mobile): enforce funded job start flow"
```

### Task 28: Connect post-work tip, receipts, and financial history

**Files:**
- Modify: `flutter_mort/lib/features/payments/screens/payment_review_screen.dart`
- Modify: `flutter_mort/lib/features/payments/widgets/tip_selector.dart`
- Modify: `flutter_mort/lib/features/history/screens/job_payment_history_screen.dart`
- Modify: `flutter_mort/lib/features/history/widgets/payment_history_filters.dart`
- Modify: `flutter_mort/lib/features/history/widgets/payment_history_row.dart`
- Modify: `flutter_mort/lib/features/receipts/screens/receipt_detail_screen.dart`
- Modify: `flutter_mort/lib/features/receipts/widgets/receipt_document_view.dart`
- Modify: `flutter_mort/test/features/payments/tipping_widget_test.dart`
- Modify: `flutter_mort/test/features/payments/payment_history_widget_test.dart`
- Modify: `flutter_mort/test/features/receipts/receipt_document_widget_test.dart`

**Interfaces:**
- Consumes: settled job, separate tip PaymentSheet, history cursor/filter/search, authorized immutable document.
- Produces: independent tip UX, paged server history, issued document detail, and explicit “no receipt issued” for failed attempts.

- [ ] **Step 1: Write failing end-to-end widget contract tests**

Assert tip is offered only after eligible completion, clearly says 100% goes to teen, tip failure leaves base receipt/status unchanged, history paginates and filters by year/kind/search, failed attempts display no-receipt state, document route loads by number, and unauthorized/not-found use one neutral error.

- [ ] **Step 2: Run tests to verify RED**

Run: `cd flutter_mort; flutter test test/features/payments/tipping_widget_test.dart test/features/payments/payment_history_widget_test.dart test/features/receipts/receipt_document_widget_test.dart`

Expected RED: screens still rely on local fixtures or an unavailable-backend fallback.

- [ ] **Step 3: Implement server-backed screens**

Use the typed repository, preserve filters across pagination, debounce safe search, and route only issued document numbers. Present tip as a separate charge with its own status/receipt. Never merge tip into base/Fair Pay rows, and never label funding confirmation as teen earnings.

- [ ] **Step 4: Verify GREEN**

Run: `cd flutter_mort; dart format --output=none --set-exit-if-changed lib test/features; flutter analyze; flutter test test/features/payments/tipping_widget_test.dart test/features/payments/payment_history_widget_test.dart test/features/receipts/receipt_document_test.dart test/features/receipts/receipt_document_widget_test.dart`

Expected GREEN: separate tip behavior, server history, immutable document display, authorization-safe errors, accessibility, and no-receipt semantics all pass.

- [ ] **Step 5: Commit**

```bash
git add flutter_mort/lib/features/payments/screens/payment_review_screen.dart flutter_mort/lib/features/payments/widgets/tip_selector.dart flutter_mort/lib/features/history/screens/job_payment_history_screen.dart flutter_mort/lib/features/history/widgets/payment_history_filters.dart flutter_mort/lib/features/history/widgets/payment_history_row.dart flutter_mort/lib/features/receipts/screens/receipt_detail_screen.dart flutter_mort/lib/features/receipts/widgets/receipt_document_view.dart flutter_mort/test/features/payments/tipping_widget_test.dart flutter_mort/test/features/payments/payment_history_widget_test.dart flutter_mort/test/features/receipts/receipt_document_test.dart flutter_mort/test/features/receipts/receipt_document_widget_test.dart
git commit -m "feat(mobile): show tips receipts and payment history"
```

### Task 29: Connect hosted onboarding and separate payout status to Payment OS

**Files:**
- Modify: `flutter_mort/lib/features/payments/stripe_marketplace_screens.dart`
- Modify: `flutter_mort/lib/features/financial/financial_section_screens.dart`
- Modify: `flutter_mort/lib/features/profile/activity_history_screen.dart`
- Modify: `flutter_mort/lib/core/routing/app_router.dart`
- Modify: `flutter_mort/test/features/payment_os_integration_test.dart`
- Create: `flutter_mort/test/features/payments/stripe_payout_setup_test.dart`

**Interfaces:**
- Consumes: connected-account readiness, hosted onboarding URL, earnings status, transfer status, payout status.
- Produces: teen payout setup/status UI with external hosted onboarding and no bank-deposit guarantee.

- [ ] **Step 1: Write failing payout/onboarding tests**

Cover not-started/onboarding/pending/restricted/ready/disabled, external URL launch, refresh after return, provider guardian copy separate from MORT Guardian Mode, earnings vs transfer vs payout labels, standard payout wording, and no instant payout control.

- [ ] **Step 2: Run tests to verify RED**

Run: `cd flutter_mort; flutter test test/features/payments/stripe_payout_setup_test.dart test/features/payment_os_integration_test.dart`

Expected RED: current screen lacks complete readiness and three-way status display.

- [ ] **Step 3: Implement Payment OS wiring**

Use the existing payout route and repository provider, open Stripe-hosted onboarding externally, discard the one-time URL after launch, and refresh minimized status on app resume/return. Link earnings/history/document screens through existing Payment OS navigation; do not create a second financial hub.

- [ ] **Step 4: Verify GREEN**

Run: `cd flutter_mort; dart format --output=none --set-exit-if-changed lib test/features; flutter analyze; flutter test test/features/payments/stripe_payout_setup_test.dart test/features/payment_os_integration_test.dart test/financial_screens_test.dart`

Expected GREEN: readiness and lifecycle labels are correct, onboarding stays hosted/external, minor/guardian language is accurate, and instant payout is absent.

- [ ] **Step 5: Commit**

```bash
git add flutter_mort/lib/features/payments/stripe_marketplace_screens.dart flutter_mort/lib/features/financial/financial_section_screens.dart flutter_mort/lib/features/profile/activity_history_screen.dart flutter_mort/lib/core/routing/app_router.dart flutter_mort/test/features/payment_os_integration_test.dart flutter_mort/test/features/payments/stripe_payout_setup_test.dart
git commit -m "feat(mobile): wire Connect onboarding and payout status"
```

## Phase 11 — Pre-Provider Gate and Stripe Sandbox Integration

### Task 30: Build the ordered pre-provider-test gate

**Files:**
- Create: `scripts/stripe-pre-provider-test-gate.ps1`
- Create: `scripts/qa-stripe-pre-provider-gate.mjs`
- Modify: `scripts/stripe-check-config.ps1`
- Modify: `docs/payments/MORT_STRIPE_SANDBOX_SETUP.md`
- Modify: `docs/payments/MORT_STRIPE_SUPABASE_SECRETS.md`

**Interfaces:**
- Consumes: Supabase secret-name listing, deployed TEST webhook endpoint metadata, `MORT_STRIPE_MODE`, linked project ref, runtime controls.
- Produces: a non-secret gate result/evidence file containing booleans/timestamps/project ref only; exit 0 only after all six ordered checks pass.

- [ ] **Step 1: Write failing gate tests**

Use fixture command output containing names but no values. Test missing secret key, missing publishable key, absent TEST webhook, missing webhook secret, wrong project, live mode/key-name contamination, accidental value-like output, and complete sandbox configuration. Assert the gate never invokes a Stripe mutation.

- [ ] **Step 2: Run test to verify RED**

Run: `node scripts/qa-stripe-pre-provider-gate.mjs`

Expected RED: gate script is missing and existing config check requires all names at once without ordered webhook deployment evidence.

- [ ] **Step 3: Implement the non-secret gate**

The script must perform, in order: confirm `STRIPE_TEST_SECRET_KEY` name exists; confirm `STRIPE_TEST_PUBLISHABLE_KEY` name exists; confirm the TEST webhook endpoint URL/environment is configured; confirm `STRIPE_TEST_WEBHOOK_SECRET` name exists; verify linked project/runtime/provider mode is sandbox; then confirm the operation-specific sandbox mutation-test flag is eligible. Redact all command output to allowlisted names/booleans and reject `sk_`, `pk_`, `whsec_`, `rk_`, or JWT-like values.

- [ ] **Step 4: Verify GREEN without provider mutation**

Run: `node scripts/qa-stripe-pre-provider-gate.mjs; powershell -ExecutionPolicy Bypass -File scripts/stripe-pre-provider-test-gate.ps1 -WhatIf`

Expected GREEN: fixture tests pass; `-WhatIf` reports only missing/present names and sandbox gate status, prints no values, and performs no provider call.

- [ ] **Step 5: Commit**

```bash
git add scripts/stripe-pre-provider-test-gate.ps1 scripts/qa-stripe-pre-provider-gate.mjs scripts/stripe-check-config.ps1 docs/payments/MORT_STRIPE_SANDBOX_SETUP.md docs/payments/MORT_STRIPE_SUPABASE_SECRETS.md
git commit -m "test(payments): add pre-provider sandbox gate"
```

### Task 31: Run controlled Stripe sandbox integration scenarios

**Files:**
- Modify: `scripts/stripe-listen-test.ps1`
- Modify: `scripts/stripe-trigger-test-events.ps1`
- Create: `scripts/stripe-sandbox-e2e.ps1`
- Create: `scripts/qa-stripe-sandbox-e2e-evidence.mjs`
- Modify: `docs/payments/MORT_STRIPE_CLI_TESTING.md`

**Interfaces:**
- Consumes: successful Task 30 gate, deployed TEST Edge Functions/webhook, isolated QA users/jobs, Stripe test payment methods/events.
- Produces: sanitized scenario evidence for capture, webhook retry/order, settlement, transfer, refund, reversal, tip, dispute, payout status, and no-live-money proof.

- [ ] **Step 1: Write failing orchestration/evidence tests**

Assert the runner exits before mutation if Task 30 fails; permits test IDs only; refuses `live` mode; never logs secret/client-secret/card values; captures request/trace/provider-object suffixes only; and requires evidence rows for every Section 32 scenario before marking sandbox QA complete.

- [ ] **Step 2: Run tests to verify RED**

Run: `node scripts/qa-stripe-sandbox-e2e-evidence.mjs`

Expected RED: the end-to-end runner/evidence schema is absent.

- [ ] **Step 3: Implement the controlled sandbox runner**

Have the runner call Task 30 first, deploy/configure the TEST webhook before installing its signing-secret name, then execute isolated sandbox cases: success, decline, requires action, processing/pending where supported, network ambiguity, duplicate submission, out-of-order/duplicate webhook, lease retry, full/partial refund, exact transfer/reversal/reversal failure, separate successful/failed tip, dispute won/lost, payout event separation, minor account restricted/ready, and cross-user authorization denial. Do not use live credentials, real cards, or real money.

- [ ] **Step 4: Run provider GREEN verification only after explicit implementation approval and gate success**

Run: `powershell -ExecutionPolicy Bypass -File scripts/stripe-pre-provider-test-gate.ps1; powershell -ExecutionPolicy Bypass -File scripts/stripe-sandbox-e2e.ps1; node scripts/qa-stripe-sandbox-e2e-evidence.mjs`

Expected GREEN: every required scenario has sanitized pass evidence, no unexpected provider object remains unreconciled, and live-mode detection remains zero.

- [ ] **Step 5: Commit sanitized evidence tooling and docs only**

```bash
git add scripts/stripe-listen-test.ps1 scripts/stripe-trigger-test-events.ps1 scripts/stripe-sandbox-e2e.ps1 scripts/qa-stripe-sandbox-e2e-evidence.mjs docs/payments/MORT_STRIPE_CLI_TESTING.md
git commit -m "test(payments): automate Stripe sandbox scenarios"
```

## Phase 12 — Full Regression, Secret Scan, and Production-Gate Evidence

### Task 32: Add Stripe coverage to full Supabase and Flutter regression

**Files:**
- Modify: `scripts/run-final-supabase-regression.ps1`
- Modify: `.github/workflows/mort-ci.yml`
- Create: `scripts/run-mort-stripe-regression.ps1`
- Modify: `flutter_mort/test/features/payment_os_integration_test.dart`
- Modify: `docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md`

**Interfaces:**
- Consumes: all local QA suites, Deno tests, Flutter tests/analyzer, Supabase advisors.
- Produces: one fail-fast local/CI regression entrypoint and an evidence matrix with command, commit, timestamp, result, and environment.

- [ ] **Step 1: Write a failing regression-manifest test**

Add a source-contract check in `qa-stripe-sandbox-e2e-evidence.mjs` that requires every new QA entrypoint, all Deno test directories, the six migration slugs, focused Flutter tests, full Flutter suite, analyzer, migration list, database advisors, and secret scans in the regression runner/CI workflow.

- [ ] **Step 2: Run the manifest test to verify RED**

Run: `node scripts/qa-stripe-sandbox-e2e-evidence.mjs --regression-manifest`

Expected RED: full regression scripts/workflow do not list the new Stripe coverage.

- [ ] **Step 3: Implement the regression runner and CI wiring**

Run local Supabase reset/migration list, all `qa-stripe-*` non-provider suites (including `qa-stripe-google-play-billing-boundary.mjs`), full existing Supabase regression, Deno tests, advisors, Flutter formatting/analyzer/focused tests/full suite, and secret scans. Keep provider sandbox E2E behind an explicit protected/manual job that calls Task 30; never run provider mutations on ordinary pull requests.

- [ ] **Step 4: Run full GREEN verification**

Run: `powershell -ExecutionPolicy Bypass -File scripts/run-mort-stripe-regression.ps1`

Expected GREEN: every local database/Edge/Flutter/legacy regression exits 0; CI manifest is complete; provider E2E remains excluded unless manually gated.

- [ ] **Step 5: Commit**

```bash
git add scripts/run-final-supabase-regression.ps1 scripts/run-mort-stripe-regression.ps1 .github/workflows/mort-ci.yml flutter_mort/test/features/payment_os_integration_test.dart docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md
git commit -m "test(payments): add full Stripe regression gate"
```

### Task 33: Verify secret hygiene and freeze production activation

**Files:**
- Modify: `scripts/secret-scan.ps1`
- Modify: `scripts/secret_extraction_scan.mjs`
- Modify: `scripts/secret-scan-git-history.mjs`
- Modify: `docs/MORT_PAYMENT_PRODUCTION_ACTIVATION_CHECKLIST.md`
- Modify: `docs/payments/MORT_STRIPE_LIVE_READINESS.md`
- Modify: `docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md`

**Interfaces:**
- Consumes: source tree/history/build artifacts, sandbox evidence, runtime readiness projection.
- Produces: no-secret evidence and explicit unresolved production blockers; live remains disabled.

- [ ] **Step 1: Write failing secret/activation assertions**

Extend scans to reject Stripe secret, restricted, webhook, client-secret, live publishable-key, and copied provider payload patterns outside allowlisted variable-name docs/tests. Require readiness docs/evidence to list production pricing, Radar Pro transaction cost/unit economics, provider fee payer, reserve/chart of accounts, production partial-comp values, minor Connect proof, legal/tax/privacy review, monitoring/on-call, Connect/provider pricing, and final owner approval as blocking.

- [ ] **Step 2: Run tests to verify RED**

Run: `powershell -ExecutionPolicy Bypass -File scripts/secret-scan.ps1; node scripts/secret_extraction_scan.mjs; node scripts/secret-scan-git-history.mjs; node scripts/qa-stripe-activation-gates.mjs`

Expected RED: the expanded Stripe pattern/evidence assertions are not yet present even if existing scans otherwise pass.

- [ ] **Step 3: Implement scans and readiness evidence**

Scan tracked source, git history, Flutter/Android/iOS artifacts, logs, and generated evidence while allowing secret variable names but never values. Update readiness documents with gate owner/evidence/status fields and state that Radar Pro is selected while its transaction cost remains an economics input. Keep live runtime flags, live provider mutations, instant payouts, production pricing, and production partial-comp values disabled.

- [ ] **Step 4: Run final verification**

Run: `powershell -ExecutionPolicy Bypass -File scripts/secret-scan.ps1; node scripts/secret_extraction_scan.mjs; node scripts/secret-scan-git-history.mjs; node scripts/qa-stripe-activation-gates.mjs; git diff --check; git status --short`

Expected GREEN: scans find no secret value, activation tests prove every live gate remains closed, diff check is clean, and only Task 33 files are pending before commit.

- [ ] **Step 5: Commit**

```bash
git add scripts/secret-scan.ps1 scripts/secret_extraction_scan.mjs scripts/secret-scan-git-history.mjs docs/MORT_PAYMENT_PRODUCTION_ACTIVATION_CHECKLIST.md docs/payments/MORT_STRIPE_LIVE_READINESS.md docs/payments/MORT_STRIPE_IMPLEMENTATION_RESULTS.md
git commit -m "security(payments): freeze production activation gates"
```

## Final Acceptance Checklist

- [ ] Six and only six planned migration slugs were generated by the Supabase CLI, applied locally, listed in migration history, and reviewed.
- [ ] Primary funding is a platform charge/capture before work, confirmed by Stripe, with no destination-charge fields.
- [ ] Job start is transactionally blocked until valid captured funding exists.
- [ ] Settlement computes `compensatedBaseCents`, exact teen transfer, service fee, and component refunds from versioned policy.
- [ ] Every financial transaction balances by currency and is source-idempotent; issued documents and ledger entries are immutable.
- [ ] Tips are separate, post-work, 100% teen principal, and independent of base settlement.
- [ ] Webhook signature, leases, retries, duplicate/hash conflict, and out-of-order monotonic behavior pass.
- [ ] Dispute, chargeback, reversal failure, recovery, and platform loss pass with no automatic teen clawback.
- [ ] Earnings, transfer, and payout states remain separate; only standard payouts are represented.
- [ ] Caller-bound RLS/grants/definer/rate-limit/hostile-client tests and Supabase advisors pass.
- [ ] Flutter PaymentSheet, Payment OS screens, receipts, history, tips, and payout readiness pass focused and full regression.
- [ ] The ordered pre-provider-test gate passes before any Stripe sandbox mutation; no live credential or real money is used.
- [ ] Secret scans across source/history/artifacts/evidence pass without printing any secret value.
- [ ] Minor Connect production proof, production pricing, Radar Pro economics, production partial-comp values, legal/tax/privacy, reserve/chart of accounts, monitoring/on-call, provider pricing, and final owner approval remain explicit blockers.

## Execution Stop

This plan authorizes no implementation by itself. After owner approval, begin with **Phase 1, Task 1: Create the policy-and-quote migration contract**, using the required execution skill and stopping at each task's review/commit boundary.
