# MORT Stripe production architecture

**Status:** Architecture and implementation audit  
**Reviewed:** 2026-11-17  
**Production Supabase project:** `jxbnrkasktbhtiujkhay`  
**Repository baseline reviewed:** `main` at `4028a9b88e7399fb6275473c49505d106714cd55`

This document defines the intended production payment architecture and records the implementation gaps found in the current repository and production database. It does not enable payments, change Stripe Dashboard settings, create live accounts, or alter credentials.

## 1. Executive decision

MORT is a marketplace: an adult funds a one-off local gig through MORT, MORT confirms payment, and MORT releases the teen's compensation after the work and required safety/completion checks are satisfied. MORT operates the customer checkout and payment support flow. The intended charge model is therefore **platform-owned checkout with separate charges and transfers**.

This is also the only pattern in the current code that supports MORT's required delayed release: the adult's payment is created on the platform, while the transfer to the teen's connected account is created later after settlement eligibility is proven.

### Target Connect configuration

Use Stripe Connect **Accounts v2** for new connected accounts:

- Dashboard: **Express**
- Fee collection: **your platform manages pricing** (`fees_collector: "application"`)
- Negative balance liability: **your platform** (`losses_collector: "application"`)
- Connected-account configuration: **Recipient**, requesting `stripe_transfers` on `stripe_balance`
- Charge pattern: **separate charges and transfers**
- Onboarding: Stripe-hosted or embedded Connect onboarding; do not build a custom KYC collection system.

This configuration matches platform-controlled checkout and delayed transfers. It also means MORT must own dispute operations, transfer reversals, negative-balance remediation, payment support, and fee economics. Express accounts have limited visibility for these charge types, so MORT's own support and financial-operations surfaces remain essential.

Do not use `application_fee_amount` with separate charges and transfers. MORT retains its service fee by transferring only the teen's approved net compensation, not the entire collected amount.

## 2. Critical minor-account requirement

Stripe's current age guidance says people 13 or older may open an account, but an account holder under 18 must have a legal guardian added/participating before the account can accept charges or receive transfers. Stripe's Express/Custom onboarding flow collects guardian information in supported countries. The guardian must agree to the relevant Stripe terms and accept the provider's legal responsibility requirements.

**This is separate from MORT's optional guardian-oversight feature.** A guardian may be optional for ordinary MORT account oversight, but Stripe's legal guardian requirement cannot be made optional for a minor's Stripe connected account. MORT must not create a connected account for a teen and assume the teen can receive payouts without the provider's guardian process.

Before enabling teen payouts, obtain Stripe confirmation that the exact proposed Accounts v2 Recipient + Express configuration supports US connected accounts for ages 13–17 with the required legal-guardian representative/consent flow. The current age support article specifically discusses Express/Custom onboarding; do not infer that every Accounts v2 configuration or capability combination is automatically approved for minors.

If Stripe does not approve this exact configuration, payouts must remain disabled until an approved guardian/representative structure is designed and reviewed. Do not silently substitute a parent's personal connected account or route teen earnings to a guardian account without explicit legal, tax, ownership, and product review.

## 3. Canonical money flow

1. Adult poster and teen agree to the gig and the authoritative contract/compensation terms are frozen.
2. Server calculates a versioned funding quote: teen base compensation, MORT service fee, currency, expiry, policy versions, and total payable.
3. Adult funds the full amount through a platform PaymentIntent. Client input never determines the amount.
4. Stripe webhook confirms the provider payment state. The client success screen is not proof of payment.
5. MORT's internal payment ledger records the captured amount and creates/updates the settlement state.
6. Work completion, dispute window, cancellation/partial-compensation policy, identity/payout readiness, and required safety checks are evaluated server-side.
7. Only an eligible settlement can create a transfer to the teen's connected account. The transfer amount is the teen's approved net compensation. MORT retains its service fee in the platform balance.
8. Stripe payout delivery to the teen's external bank/debit destination is provider-managed. MORT mirrors payout status from provider events and reconciles it.
9. Refunds, disputes, reversals, and corrections are recorded as separate immutable financial operations. Never rewrite the original payment or settlement to make a discrepancy disappear.

For the current single-teen-per-gig model, one transfer per eligible settlement is sufficient. Keep the ledger and transfer model capable of multiple transfers only if MORT later supports multiple payees for one adult payment.

## 4. Payment and transfer rules

- Use PaymentIntents for the current native mobile funding flow. The app receives only the PaymentIntent client secret and short-lived customer ephemeral key required by the Stripe mobile SDK.
- Keep all Stripe secret/restricted keys, webhook secrets, and operations credentials server-side.
- Use integer minor currency units, explicit currency, immutable quotes, and server-computed amounts.
- Use idempotency keys for customer creation, payment creation, transfer creation, refunds, reversals, and resolution operations. The idempotency scope must include environment and the immutable MORT operation identifier.
- Never create a transfer before the provider has confirmed successful funding and MORT has finalized the corresponding settlement.
- Before transfer, verify the recipient's current v2 `configuration.recipient.capabilities.stripe_balance.stripe_transfers.status === "active"` and all MORT-specific payout/legal/safety gates. Do not use legacy `charges_enabled` or `payouts_enabled` as the source of truth for new v2 accounts.
- A refund on a separate-charge-and-transfer flow does not itself recover a prior transfer. MORT must explicitly create and track transfer reversals when applicable. For disputes, implement explicit reversal/recovery logic; do not assume Stripe automatically reverses transfers.
- Do not use `application_fee_amount` for this charge pattern. The transfer amount is the teen's approved net amount; the platform retains the remainder.
- Saved payment methods require affirmative, versioned adult consent, clear future-use terms, and a supported off-session flow. Do not save a payment method merely because an adult made a one-time payment.

## 5. Connected-account onboarding and readiness

Create new accounts with Accounts v2 (`POST /v2/core/accounts`), not legacy `stripe.accounts.create({ type: "express" })`.

Recipient account creation should request only the transfer capability required for this model. Do not request merchant/card-payment configuration for recipients who only receive transfers.

Use Stripe-hosted or embedded onboarding to collect identity and legal-guardian information. MORT stores only the provider account reference, capability/readiness state, safe requirement summaries, and timestamps needed for workflow gating. Do not collect or retain unnecessary identity documents or full SSNs in MORT.

Track account updates from the relevant v2 Connect event stream and re-fetch the current account configuration before money movement. Treat capability status as dynamic: a previously-ready account can become restricted or require new information. A transfer must fail closed if the capability is not active or guardian verification is not satisfied.

For Express access, issue short-lived Stripe login links from an authenticated server endpoint. Never expose connected-account management credentials or unrestricted account identifiers in public client state.

## 6. Webhooks and event processing

The webhook endpoint is the authoritative provider-to-MORT synchronization path.

Required behavior:

- Verify the exact raw request body with the correct Stripe webhook signing secret before parsing or processing.
- Keep platform and Connect webhook endpoints/secrets distinct, and verify that each event arrived through the correct route.
- Enforce environment consistency: test events must never mutate live records and live events must never mutate test records.
- Persist event ID, event type, event creation time, payload hash, signature verification result, attempt count, lease, processing status, and safe failure code.
- Deduplicate by (environment, Stripe event ID). A duplicate with a different payload hash is a security/replay conflict, not a successful duplicate.
- Use a lease/claim state machine so concurrent deliveries cannot apply the same event twice. A failed handler must release or expire its lease and remain retryable.
- Return success only after the durable operation is complete. If processing fails, return a retryable failure and preserve enough state for replay.
- Never trust client callbacks or redirect pages to confirm payment, transfer, refund, or payout completion.

Event families to cover and test include PaymentIntent success/failure/cancellation/processing; connected-account capability/requirement updates; transfer creation/update/reversal; refund creation/update/failure; dispute creation/update/closure and funds movement; and connected-account payout creation/update/paid/failed/canceled. Confirm the exact current v2 Connect event names and account context during implementation rather than mechanically retaining v1 event names.

## 7. Refunds, disputes, and financial operations

### Refunds
- Only authorized MORT staff/workflows may initiate refunds.
- Validate the original payment, remaining refundable amount, dispute state, reason, and any previous refund/reversal.
- Record a refund intent before calling Stripe, with a deterministic idempotency key.
- Track provider refund status from webhook events.
- For separate charges and transfers, separately determine whether a transfer reversal is required and whether the connected account has sufficient balance. Escalate unrecoverable amounts to a human financial-operations queue.

### Disputes
- Ingest dispute events promptly and open a linked MORT dispute/financial case.
- Preserve evidence snapshots, timestamps, communications, completion proof, policies accepted, and provider deadlines.
- Assign a human owner and alert before the response deadline.
- Determine whether a transfer reversal is appropriate and attempt it through a separately idempotent operation.
- Track platform debit, transfer reversal, connected-account negative balance, and final dispute outcome independently.
- Do not automatically mark a teen or adult at fault based solely on a cardholder dispute outcome.

### Reconciliation
Run scheduled, idempotent reconciliation for:
- MORT payment records versus Stripe PaymentIntents and charges;
- MORT transfers versus Stripe transfers and reversals;
- connected-account capability and payout status;
- refunds and disputes;
- platform balance transactions and fees;
- webhook events stuck in received/failed/leased states.

Every mismatch must produce a durable case with amount, currency, environment, provider object references, discrepancy category, owner, and resolution. Never silently auto-correct financial records without an auditable operation.

## 8. Ledger and data model

The current repository contains a newer private financial model with funding quotes, payment attempts, settlements, transfers, refunds, disputes, tips, webhook events, audit events, and reconciliation runs. Production currently exposes only a much smaller legacy Stripe schema (see section 11). The migration baseline must be reconciled before this newer model can be used in production.

The target data model should preserve:
- environment-scoped provider account/customer/payment/transfer/refund/dispute/payout IDs;
- immutable funding quote and policy version snapshots;
- payment attempts and provider state transitions;
- settlement and compensation decisions;
- transfer and transfer-reversal records;
- refund and dispute operations;
- webhook delivery/processing leases;
- reconciliation runs and financial audit events.

All provider identifiers must be unique within their environment. All money values must be integer minor units with currency. Keep private tables inaccessible to clients; expose narrowly scoped user RPCs for own payment status/history and service-role-only RPCs for provider mutations. Never let the client submit a payee ID, connected account ID, transfer amount, refund amount, or fee amount as authoritative input.

## 9. Security and environment separation

- Separate test and live API credentials, webhook secrets, and restricted keys.
- Prefer narrowly scoped restricted API keys where supported. Never put secret/restricted keys in Flutter, web JavaScript, Git, logs, crash reports, analytics, or support transcripts.
- Keep webhook signing secrets separate for platform and Connect events.
- Keep the operations secret server-only and rotate it; prefer staff authorization with narrowly scoped database permissions as the primary control, not a shared static secret alone.
- Validate return/refresh URLs against a strict production allowlist.
- Rate-limit all user-facing payment endpoints and enforce authenticated user/role/contract ownership server-side.
- Use least-privilege service-role database procedures, fixed search paths, explicit grants/revokes, and audit logs.
- Do not log client secrets, ephemeral keys, raw webhook payloads containing sensitive data, bank details, or personal identity information.
- Require strong 2FA/passkeys for Stripe Dashboard operators and restrict team access to the minimum needed.

## 10. Version and SDK alignment

The reviewed code currently imports `stripe@22.1.1`, while the Stripe integration guidance reviewed for this audit identifies Node SDK 23.0.0 and API version `2026-10-28.endive` as current. One mobile ephemeral-key request explicitly pins `2026-03-25.dahlia`.

Before changing versions:
1. Confirm the exact Deno-compatible Stripe SDK release and its support for Accounts v2 APIs used by MORT.
2. Pin one deliberate API version for server calls and the corresponding mobile ephemeral-key API version.
3. Update webhook event fixtures and contract tests.
4. Run the full sandbox matrix before any live rollout.

Do not upgrade the SDK/API version as an isolated package bump without compatibility tests.

## 11. Audit findings from current production

Live read-only inspection on 2026-11-17 found:

- Stripe runtime mode is `disabled`.
- `payments_enabled=false`, `job_funding_enabled=false`, `transfers_enabled=false`, `refunds_enabled=false`, and `connected_onboarding_enabled=false`.
- `live_mode_enabled=false`, `live_owner_approved=false`, `connected_accounts_approved=false`, and `payouts_approved=false`.
- The runtime control row has a configured fee field of 297 cents, but payment controls are disabled. Do not treat that value as an approved production price.
- Production has only five private Stripe tables: `stripe_connected_accounts`, `stripe_customers`, `stripe_payment_intents`, `stripe_runtime_controls`, and `stripe_webhook_events`.
- Production's Stripe RPC inventory contains only five older assignment-payment routines: `stripe_server_apply_assignment_payment_webhook`, `stripe_server_claim_webhook_event`, `stripe_server_finish_webhook_event`, `stripe_server_prepare_assignment_payment`, and `stripe_server_record_assignment_payment_intent`.
- The current repository's newer payment endpoints call RPCs such as `stripe_server_create_job_funding_quote_v1`, `stripe_server_consume_job_funding_quote_v1`, `stripe_server_prepare_quote_payment_v1`, `stripe_server_prepare_payment_intent_v2`, `stripe_server_prepare_settlement_transfer_v1`, and `stripe_server_claim_webhook_event_v2`. These were not present in the production RPC inventory.
- Production migration history contains three Stripe entries dated 2026-10-27: `mort_stripe_production_foundation`, `mort_stripe_assignment_payment_api`, and `mort_stripe_assignment_payment_status`. The current `main` tree reviewed here does not contain matching 2026-10-27 migration files.
- The current connected-account creation function uses the legacy v1 `stripe.accounts.create({ type: "express" })` path.
- Current webhook synchronization reads v1 account fields such as `charges_enabled` and `payouts_enabled`; new Accounts v2 recipient transfers must use the v2 recipient capability status.
- The current webhook processor has durable claim/deduplication logic in repository code, but production's current RPC inventory does not contain the newer v2 claim/complete/fail routines it calls.

**Conclusion:** Stripe is not ready to process production money. The immediate blocker is not merely turning on a Stripe flag: production database schema/RPCs, repository migrations, and deployed Edge Function contracts are not aligned. Enabling payments now would risk failed funding, webhook processing, or settlement/transfer execution.

## 12. Implementation sequence

1. **Reconcile source of truth:** recover and commit the exact 2026-10-27 production Stripe migrations, compare them to current main, then create a forward-only migration chain from the real production baseline. Do not edit historical migrations or mark unapplied migrations as applied without proving equivalence.
2. **Lock provider/legal model:** obtain Stripe confirmation for the minor recipient + guardian onboarding requirements and the proposed Accounts v2 recipient configuration. Obtain legal/accounting approval for MORT's merchant-of-record, tax reporting, and fee disclosures.
3. **Migrate connected accounts:** implement Accounts v2 Recipient + Express onboarding, legal guardian collection, capability sync, and fail-closed transfer readiness.
4. **Align database and Edge Functions:** deploy the exact quote/payment/settlement/refund/transfer/webhook/reconciliation RPCs and function contracts together, with no live money movement enabled.
5. **Complete refund/dispute recovery:** prove transfer reversal and negative-balance recovery for separate charges and transfers.
6. **Complete ledger/reconciliation:** prove daily matching, stuck-event recovery, and human exception handling.
7. **Sandbox certification:** test new teen account onboarding (including guardian), adult payment success/failure/3DS, duplicate/out-of-order webhooks, delayed transfer, payout pending/failed, full/partial refund, dispute win/loss, reversal failure, account restriction, and replay after worker crash.
8. **Production credentials and Dashboard:** separately configure least-privilege live keys, webhook endpoints/secrets, account configuration, Radar, risk controls, statement descriptor, support contacts, and payout policies. These are Stripe-owner actions and are not performed by this document.
9. **Controlled launch:** keep all live controls off until every gate is evidenced; then enable one gate at a time with monitoring, reconciliation, and rollback controls.

## 13. Production acceptance gates

- [ ] Stripe confirms the US minor + legal guardian onboarding path for the exact Accounts v2 configuration.
- [ ] Production migrations and deployed Edge Function RPC contracts are aligned.
- [ ] New connected accounts use Accounts v2 Recipient configuration.
- [ ] V2 transfer capability is active and rechecked before every transfer.
- [ ] Adult funding uses server-authoritative immutable quotes.
- [ ] Webhook signature verification, environment isolation, idempotency, replay, and retry tests pass.
- [ ] Teen transfer occurs only after successful payment and finalized settlement eligibility.
- [ ] Refund and dispute transfer-reversal paths pass sandbox tests.
- [ ] Reconciliation identifies and escalates every injected mismatch.
- [ ] No secret appears in client artifacts, repository, logs, or telemetry.
- [ ] Legal, tax, accounting, safeguarding, and support owners approve the live flow.
- [ ] Live owner approval and connected-account/payout approval are explicitly recorded before enabling controls.

## 14. Sources

- Stripe age requirement: https://support.stripe.com/questions/age-requirement-to-create-a-stripe-account
- Stripe US connected-account verification changes: https://support.stripe.com/questions/us-connected-accounts-accepting-card-payments-verification-requirement-changes
- Stripe Accounts v2: https://docs.stripe.com/connect/accounts-v2
- Stripe separate charges and transfers: https://docs.stripe.com/connect/separate-charges-and-transfers
- Stripe Connect webhook events: https://docs.stripe.com/connect/webhooks
- Stripe webhook signature verification: https://docs.stripe.com/webhooks/signature
- Stripe API keys: https://docs.stripe.com/keys
- Stripe pricing: https://stripe.com/pricing
