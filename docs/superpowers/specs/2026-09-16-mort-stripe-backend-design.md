# MORT Stripe Backend Architecture

**Status:** Owner-approved architecture; specification awaiting owner review
**Date:** 2026-09-16
**Primary funding model:** Pre-work platform capture followed by post-settlement Stripe Connect transfer
**Initial environment:** Stripe sandbox/test, USD only
**Production state:** Disabled; live money movement is outside this specification's authorization

## 1. Purpose and scope

This specification defines MORT's server-authoritative job-payment architecture. It connects the completed Flutter Payment OS presentation layer to the existing Supabase and Stripe Connect foundation without giving Flutter financial authority.

The approved primary flow is:

1. Capture the adult's base job payment and sandbox MORT service fee before work becomes startable.
2. Treat captured funds as a platform liability, not teen earnings or MORT revenue.
3. After an authoritative completion, cancellation, abandonment, or job-dispute decision, calculate compensated base pay on the server.
4. Transfer exactly the compensated base pay to the teen's Stripe connected account.
5. Refund unearned base and fee components.
6. Process an optional tip as a separate post-work payment and transfer.

This specification covers sandbox policy, data contracts, state machines, ledger behavior, immutable financial documents, history, webhooks, reconciliation, authorization, testing, operational recovery, and production activation gates.

It does not authorize live payments, production pricing, migrations, Edge Function deployment, Flutter changes, provider mutations, or a production launch.

## 2. Authority model

### Stripe authority

Stripe is authoritative for provider objects and provider outcomes:

- PaymentIntent existence, authorization, capture, status, and charge identifiers;
- connected-account requirements, capabilities, restrictions, and payouts;
- provider events, disputes, refunds, transfers, reversals, and balance effects;
- whether a payment method supports a requested provider feature.

MORT never changes a provider outcome merely because the client reports success.

### Supabase and MORT authority

Supabase is authoritative for MORT business and financial truth:

- who may fund, work, settle, view, refund, transfer, or operate on a job;
- contract, job, base-pay, currency, and lifecycle state;
- versioned service-fee, Fair Pay, tip, cancellation, and partial-compensation policy;
- quote eligibility and immutable quote snapshots;
- normalized payment state and legal transitions;
- settlement decisions, ledger postings, teen earnings credit, MORT fee recognition;
- immutable financial documents and chronological history;
- activation controls, financial roles, audit events, and release gates.

### Flutter authority

Flutter is presentation and interaction only. It may submit opaque identifiers, a client request ID, and user choices explicitly permitted by the backend, such as a requested tip. It never supplies authoritative base pay, service fee, total, worker provider ID, compensated amount, receipt facts, payment success, transfer success, or payout success.

## 3. Existing architecture being reused

The design extends the existing Stripe/Supabase foundation:

- `private.stripe_runtime_controls` and existing sandbox/live activation controls;
- connected accounts, requirements, onboarding sessions, customers, PaymentIntents, payment attempts, transfers, refunds, disputes, payout events, webhook events, reconciliation runs, financial roles, audit events, incidents, saved-payment consents, and payment resolutions;
- authenticated Stripe Edge Functions for config, connected-account creation, onboarding, readiness, payment creation, payment resolution, transfer, and refund;
- the unauthenticated but Stripe-signature-verified webhook;
- server rate limiting, safe error normalization, idempotency keys, operations authorization, and private provider references;
- job contracts and payment obligations as the base-pay and relationship authority;
- existing Flutter Payment OS models, screens, receipt presentation, history presentation, Fair Pay presentation, tip controls, and fail-closed feature flags.

The existing strategy values remain the architectural baseline:

- `separate_charges_and_transfers`;
- capture before job start;
- post-settlement transfer release.

The existing dynamic payment preview and dynamic `get_my_job_payment_receipt` summary are not sufficient. The former is not an immutable quote; the latter is not an immutable issued financial document.

## 4. Stripe environments and activation controls

Test and live environments are isolated in configuration, database uniqueness, provider identifiers, idempotency keys, webhook endpoints, logs, and operations.

Canonical Edge Function secret names are:

- `STRIPE_TEST_SECRET_KEY` — owner-confirmed as installed in Supabase using a genuine Stripe Sandbox/Test secret; its value must never be read, printed, logged, documented, or returned;
- `STRIPE_TEST_PUBLISHABLE_KEY` — must be confirmed and installed before any provider or Flutter sandbox execution;
- `STRIPE_TEST_WEBHOOK_SECRET` — intentionally deferred until the TEST webhook endpoint is deployed and configured, then required before any provider sandbox execution;
- the existing live-name equivalents remain unused and live mode remains disabled.

The publishable key is client-safe but is delivered only through the authenticated, environment-gated config contract. Secret keys, webhook signing secrets, service-role credentials, and operations secrets remain server-only.

Provider mutation requires all of these conditions:

1. runtime mode is `sandbox`;
2. the operation-specific sandbox feature gate is enabled;
3. required test secret names are present;
4. the runtime validates the expected test-key mode without exposing values;
5. the request is authenticated and authorized, except the signature-verified webhook;
6. the relevant policy, readiness, and release gates pass.

Before any Stripe sandbox mutation test, a pre-provider-test gate must complete in this order:

1. confirm `STRIPE_TEST_SECRET_KEY` presence without reading or exposing its value;
2. confirm `STRIPE_TEST_PUBLISHABLE_KEY` presence;
3. deploy and configure the TEST webhook endpoint;
4. install `STRIPE_TEST_WEBHOOK_SECRET` without reading or exposing its value;
5. verify that the complete runtime and provider configuration is sandbox-only;
6. only then enable the specific Stripe sandbox mutation-test gate.

Live credentials remain separate, untouched, and ineligible to satisfy this gate.

The owner-selected current Stripe fraud configuration is **Radar Pro**. This is a fixed configuration decision, not an unresolved product-selection question. Its transaction cost and resulting effect on MORT unit economics remain inputs to the production pricing and release review.

Live mode additionally requires every production gate in Section 33 and a later explicit owner approval. Nothing in this specification changes a live flag.

## 5. Connected-account model

MORT uses a Stripe-managed connected account with Stripe-hosted onboarding. The implementation may migrate the existing Express shorthand toward equivalent controller properties after Stripe validates MORT's platform configuration. MORT does not collect Stripe identity documents, bank details, Social Security information, guardian identity evidence, or raw requirements payloads in Flutter or its own public tables.

The teen/minor model is:

- intended users are ages 13–17 in the United States;
- Stripe determines the current representative, legal-guardian, consent, identity, and capability requirements;
- MORT stores only provider identifiers and safe normalized status fields;
- no parent or guardian field is hardcoded beyond requirements Stripe actually returns;
- activation remains blocked until an end-to-end US minor sandbox onboarding flow is proven.

Safe stored fields include:

- user ID, environment, connected-account ID, account configuration, country, and default currency;
- onboarding status, details-submitted flag, transfers capability, payouts-enabled flag, and safe requirements category;
- normalized guardian status: `PROVIDER_MANAGED_UNKNOWN`, `REQUIRED`, `PENDING`, `SATISFIED`, or `RESTRICTED`;
- safe disabled-reason code, last synchronized time, and disconnected time.

Readiness states are:

- `NOT_STARTED`
- `ONBOARDING`
- `REQUIREMENTS_DUE`
- `PENDING_VERIFICATION`
- `READY_FOR_TRANSFER`
- `RESTRICTED`
- `DISCONNECTED`
- `PROVIDER_UNAVAILABLE`

`READY_FOR_TRANSFER` requires the current test environment, completed provider onboarding, an active transfers capability, payouts enabled or otherwise provider-confirmed payout readiness, no blocking requirement, and a recent provider synchronization. A worker must be ready before the normal paid-job start gate passes.

## 6. Pre-work funding lifecycle

The conceptual flow is:

```text
job accepted or scheduled
  -> authoritative funding eligibility
  -> versioned funding quote
  -> adult PaymentSheet confirmation
  -> platform PaymentIntent
  -> provider-confirmed capture
  -> job FUNDED
  -> job STARTABLE
```

The platform PaymentIntent amount is:

```text
basePayCents + sandboxServiceFeeCents
```

The PaymentIntent is a platform charge with `transfer_group`; it does not use `transfer_data.destination` or `application_fee_amount` in the primary flow. Confirmation and capture happen before the job becomes startable.

Provider success is necessary but not sufficient. The transactional webhook reducer revalidates the attempt, quote snapshot, current contract version, job parties, currency, environment, amount, and absence of a conflicting terminal state before marking the job funded. If Stripe captures a payment after MORT state became ineligible, the reducer freezes the job and opens an idempotent refund/reconciliation case; it does not make the job startable.

At funding capture:

- no teen earnings are credited;
- no teen earnings receipt is issued;
- no MORT service-fee revenue is recognized;
- the captured gross amount is recorded as a platform liability;
- the funding event appears in authorized history as funded/pending settlement.

## 7. Job start gate

The normal paid-job flow cannot begin without authoritative funding.

The server-side start operation must lock the job, contract, payment obligation, quote, and active attempt and verify:

- the caller is an authorized participant;
- the accepted contract version still matches the funded quote;
- provider-confirmed captured amount and currency match the snapshot;
- the funding record is `SUCCEEDED` and not refunded, disputed, reversed, stale, or under reconciliation;
- the worker is still the assigned worker and is `READY_FOR_TRANSFER`;
- the job is not cancelled, completed, abandoned, or under a blocking dispute;
- no other start transition has won concurrently.

Race handling uses row locks, unique active-funding constraints, and a single database transition. Two start requests yield one start and one idempotent current-state response.

Stale-state rules:

- an expired quote cannot create a provider payment;
- a quote is superseded when the contract version, base pay, worker, currency, or active financial policy changes before PaymentIntent creation;
- after provider creation, the immutable quote snapshot remains attached to the attempt;
- a changed contract requires cancellation/refund and a new quote rather than mutating the funded amount;
- an `UNKNOWN` or unreconciled provider state blocks both job start and a replacement attempt.

## 8. Payment quote model

`private.stripe_job_funding_quotes` is an immutable snapshot with controlled lifecycle fields. It contains:

- `id` / `quoteId`
- `environment`
- `payer_id`
- `worker_id`
- `job_id`
- `contract_id`
- `contract_version_id`
- `base_pay_cents`
- `service_fee_cents`
- `authoritative_total_cents`
- `currency_code`
- `financial_policy_version_id`
- `connected_account_id`
- `connected_account_readiness`
- `payment_eligibility`
- `provider_availability`
- `request_id`
- `request_payload_sha256` / request hash
- `created_at`
- `expires_at`
- `consumed_at`
- `superseded_at`
- `superseded_by_quote_id`

All amounts are integer cents. The server loads payer, worker, job, contract, base pay, currency, policy, and readiness. The client never supplies financial amounts or provider account IDs.

A quote has one of these lifecycle states: `ACTIVE`, `CONSUMED`, `SUPERSEDED`, or `EXPIRED`. At most one active, non-expired funding quote exists for the same payer/contract version/request identity. Consuming a quote and creating the local attempt occur in one database transaction before any Stripe mutation.

## 9. Payment attempt and idempotency model

The local attempt is persisted before Stripe is called. The existing `private.stripe_job_payment_attempts` and `private.stripe_job_payment_intents` are extended rather than replaced.

Each attempt binds:

- authenticated payer;
- quote ID and immutable quote hash;
- contract and version;
- environment and operation version;
- server-generated attempt ID;
- client request ID;
- provider idempotency key derived from environment and attempt ID;
- normalized state;
- provider object references stored server-side only;
- creation, reconciliation, and terminal timestamps.

Required behavior:

- the same caller, operation, request ID, and canonical payload hash returns the original attempt/result;
- reusing the bound request identity with different input rejects as a mismatched replay;
- concurrent submissions serialize and create at most one provider PaymentIntent;
- a timeout does not authorize a new attempt until status reconciliation completes;
- a duplicate request linked to a live or terminal attempt returns `DUPLICATE_BLOCKED` plus a safe reference to the original state;
- provider idempotency is a second defense, not a replacement for database uniqueness.

## 10. Payment state machine

The normalized states are:

- `READY`
- `PROCESSING`
- `REQUIRES_ACTION`
- `PENDING`
- `SUCCEEDED`
- `DECLINED`
- `FAILED`
- `CANCELLED`
- `UNKNOWN`
- `PROVIDER_UNAVAILABLE`
- `DUPLICATE_BLOCKED`

Legal transitions are:

| From | Allowed next states |
| --- | --- |
| `READY` | `PROCESSING`, `CANCELLED`, `PROVIDER_UNAVAILABLE` |
| `PROCESSING` | `REQUIRES_ACTION`, `PENDING`, `SUCCEEDED`, `DECLINED`, `FAILED`, `CANCELLED`, `UNKNOWN`, `PROVIDER_UNAVAILABLE` |
| `REQUIRES_ACTION` | `PROCESSING`, `PENDING`, `SUCCEEDED`, `DECLINED`, `FAILED`, `CANCELLED`, `UNKNOWN` |
| `PENDING` | `SUCCEEDED`, `DECLINED`, `FAILED`, `CANCELLED`, `UNKNOWN` |
| `UNKNOWN` | `PROCESSING`, `REQUIRES_ACTION`, `PENDING`, `SUCCEEDED`, `DECLINED`, `FAILED`, `CANCELLED`, `PROVIDER_UNAVAILABLE` only through authenticated reconciliation |
| `PROVIDER_UNAVAILABLE` | `READY`, `PROCESSING`, `UNKNOWN` after a new availability/status check |
| `SUCCEEDED` | Terminal for that attempt; later refunds/disputes are separate events and documents |
| `DECLINED`, `FAILED`, `CANCELLED` | Terminal for that attempt |
| `DUPLICATE_BLOCKED` | Terminal synthetic result referencing the canonical attempt |

Transitions are checked against the current row under lock. Provider-created time, event type, current provider retrieval, and the allowed transition graph prevent a late event from regressing a terminal state. A new attempt after a terminal failure uses a new request/attempt identity; a `SUCCEEDED` attempt can never be replaced by another charge for the same obligation.

## 11. Job completion and settlement lifecycle

After work, one of four authoritative outcomes begins settlement:

- completion;
- adult or system cancellation;
- teen abandonment;
- job-completion dispute and resolution.

The server creates an immutable settlement decision containing:

- job, contract, version, payer, and worker;
- funded base and funded service fee;
- `compensated_base_cents`;
- recomputed final service fee;
- base and fee refund components;
- policy version and decision reason;
- decision-maker role and audited actor;
- evidence references where permitted;
- appeal/dispute linkage;
- decision and finalization timestamps.

Settlement posts the ledger transaction first. Provider operations are then executed through an idempotent saga:

1. transfer exactly `compensatedBaseCents` to the worker;
2. refund unearned base and service-fee components to the adult;
3. record provider results and reconcile failures;
4. issue immutable documents only when their required financial facts are authoritative.

Transfer success credits the provider transfer state; authoritative earnings credit occurs from the settlement ledger decision and is linked to transfer state. External payout status remains independent.

## 12. Partial-compensation policy

Neither adult nor teen supplies authoritative compensation. They may submit evidence or dispute statements, but `compensatedBaseCents` is produced only by a versioned server policy or an authorized, audited operations decision permitted by that policy.

The policy supports:

- outcome type and reason-code allowlists;
- a permitted range from zero through funded base pay;
- evidence requirements;
- one- or two-person approval thresholds;
- appeal windows and resolution linkage;
- effective time, policy version, and active state;
- fail-closed behavior when no applicable policy exists.

The precise production compensation schedule is not approved. Sandbox can exercise the mechanism only with explicit test cases and authorized test operators. No generic client endpoint accepts an arbitrary compensation amount.

For funded base `B`, original fee `F(B)`, and compensated base `E`, settlement is:

```text
teen transfer = E
adult refund = (B - E) + (F(B) - F(E))
MORT fee recognized = F(E)
```

## 13. Service-fee policy

The sandbox-only policy is:

- 8% of compensated base pay;
- $1 minimum when compensated base is greater than zero;
- $5 maximum;
- USD only.

Integer calculation is deterministic:

```text
percentageFeeCents = floor((compensatedBaseCents * 800 + 5000) / 10000)
serviceFeeCents = compensatedBaseCents == 0
  ? 0
  : clamp(percentageFeeCents, 100, 500)
```

The policy is stored in a versioned financial-policy row with rate, minimum, maximum, rounding rule, currency, effective time, active state, and environment. Quotes and settlements reference the exact version. Flutter never hardcodes the active policy as financial truth.

This pricing is approved only for sandbox behavior. Production profitability and production pricing remain owner gates.

## 14. Fair Pay policy

Fair Pay is a versioned backend policy, optionally specialized by job type, containing:

- recommended minimum;
- recommended maximum;
- hard minimum;
- `yellowMayContinue`;
- currency, effective time, version, and active state.

The server computes:

- `GREEN` at or within the recommended range;
- `YELLOW` below the recommendation but at or above the hard minimum;
- `RED` below the hard minimum.

`RED` always blocks publication. `YELLOW` follows the active policy's `yellowMayContinue`. Missing, expired, ambiguous, or currency-mismatched policy blocks publication. Tips are excluded from Fair Pay. Flutter renders the server result and cannot override it.

## 15. Tip policy

Tip policy is versioned and includes USD currency, minimum, maximum, effective time, version, active state, and late-tip eligibility window.

Tips are:

- selected after work;
- separate from the pre-work base charge;
- processed through their own quote/attempt/PaymentIntent;
- transferred 100% to the teen after provider-confirmed success;
- charged no MORT percentage fee;
- excluded from Fair Pay;
- represented by a separate immutable financial document;
- independent of completed base settlement.

A failed, cancelled, declined, pending, or unknown tip never invalidates base settlement and never produces a successful tip document. MORT absorbs tip processing cost during sandbox testing. Incremental authorization, overcapture, and multicapture are not primary tip mechanisms.

## 16. Stripe separate charges and transfers

The primary base flow is precise:

1. MORT creates a charge on the platform account through a PaymentIntent.
2. The PaymentIntent uses a stable `transfer_group` linking the provider charge to the MORT job/contract without exposing that reference publicly.
3. The adult confirms through the official Stripe mobile SDK.
4. Stripe captures the platform charge before work.
5. Webhook/reconciliation confirms provider success and MORT marks the job funded.
6. After authoritative settlement, MORT creates a separate Connect transfer for exactly the compensated base.
7. Stripe payout behavior occurs later on the connected account and is not payment success.

The base PaymentIntent does not use destination-charge fields. Separate charges and transfers are retained because they protect the teen from ordinary post-work decline, support exact partial compensation, and match the current database and Edge Function foundation.

## 17. Refund architecture

Refunds are component-aware. Refunding a platform charge does not reverse a previously created worker transfer. MORT records and executes explicit amounts.

| Refund type | Customer refund | Worker transfer action | MORT fee action | Provider operations |
| --- | ---: | ---: | ---: | --- |
| Base only | Base component | Reduce unexecuted transfer or reverse exact base amount | None | Platform-charge refund plus transfer reversal when already transferred |
| Tip only | Tip component | Reverse exact tip transfer | None | Refund separate tip charge plus tip transfer reversal |
| MORT fee only | Fee component | None | Reverse fee revenue | Platform-charge refund only |
| Base + tip | Base plus tip | Reverse exact base and tip transfers | None unless separately included | Refund base and tip provider charges plus exact reversals |
| Full refund | Base, tip, and MORT fee | Reverse base and tip transfers | Reverse all fee revenue | Refund both charges and reverse exact transfers |

Each refund document records the requested component allocation, provider operations, amounts recovered, platform-funded shortfall, and original document links. Provider operations are an idempotent saga. If reversal fails because the connected account lacks funds, the adult refund policy and teen-protection policy determine whether MORT funds the shortfall; the failure is not hidden or converted into an automatic teen debit.

Original processing, Connect, currency-conversion, and applicable fraud costs remain expense unless Stripe explicitly returns them.

## 18. Card disputes and chargebacks

For platform charges, MORT's Stripe balance receives the provider debit and dispute fee. The webhook creates a dispute event, financial incident, reserve/loss posting, and operations case.

There is no automatic surprise negative teen balance. A teen transfer already earned under an authoritative settlement remains credited unless a future legal and owner-approved recovery policy authorizes a specific adjustment. The current design does not introduce that policy.

Job-completion disputes and card-network disputes are distinct:

- a job-completion dispute determines `compensatedBaseCents` before transfer where possible;
- a later card dispute is provider risk against the platform and does not rewrite the historical job decision;
- winning a dispute posts a recovery transaction;
- losing a dispute posts platform loss and closes the incident;
- every correction is append-only.

## 19. Double-entry ledger

The ledger consists of:

- `private.financial_accounts`
- `private.financial_transactions`
- `private.financial_ledger_entries`

Every transaction has one environment, one currency, a source type and source ID, an idempotency key, an effective time, and entries whose signed debits equal signed credits. Database constraints and deferred validation reject imbalance.

Required accounts include:

- Stripe platform cash/clearing;
- captured job funds liability;
- customer refund payable;
- teen earnings payable;
- tip payable;
- MORT service-fee revenue;
- Stripe processing expense;
- Radar Pro expense;
- Connect account/funds-routing expense;
- payout fee expense;
- chargeback loss;
- transfer-reversal recovery receivable;
- unrecovered reversal loss;
- platform financial reserve/memorandum account as approved by accounting policy.

Conceptual postings:

### Platform capture

```text
Dr Stripe cash/clearing                 gross captured
Cr Captured job funds liability        gross captured
```

### Stripe processing, Radar Pro, and Connect costs

```text
Dr Applicable provider expense         provider fee
Cr Stripe cash/clearing                 provider fee
```

### Settlement

```text
Dr Captured job funds liability        original base + original fee
Cr Teen earnings payable               compensated base
Cr MORT service-fee revenue             fee on compensated base
Cr Customer refund payable             unearned base + returned fee
```

### Teen transfer

```text
Dr Teen earnings payable               transfer amount
Cr Stripe cash/clearing                 transfer amount
```

### Customer refund

```text
Dr Customer refund payable             refund amount
Cr Stripe cash/clearing                 refund amount
```

### Tip charge and transfer

```text
Dr Stripe cash/clearing                 tip captured
Cr Tip payable                          tip captured

Dr Tip payable                          tip transferred
Cr Stripe cash/clearing                 tip transferred
```

Tip processing cost is a separate provider-expense posting.

### Chargeback

```text
Dr Chargeback loss or approved recovery receivable
Cr Stripe cash/clearing
```

### Transfer reversal and failed recovery

```text
Dr Transfer-reversal recovery receivable Amount the approved correction seeks to recover
Cr Customer refund payable or settlement adjustment liability

Dr Stripe cash/clearing                 recovered amount
Cr Transfer-reversal recovery receivable

Dr Unrecovered reversal loss            unrecoverable amount
Cr Transfer-reversal recovery receivable
```

The corresponding customer refund debits customer refund payable and credits Stripe cash/clearing. If the correction does not create a customer refund, the credit side of the initial receivable posting uses the specifically approved settlement-adjustment account. No recovery receivable is created merely because an adult files a card dispute, and no posting authorizes an automatic teen clawback.

These are system-ledger semantics, not a substitute for accountant review of production financial statements. The production chart of accounts remains an activation gate.

## 20. Immutable financial documents

`private.financial_documents` stores immutable snapshots, with typed columns plus a canonical JSON snapshot and integrity hash. `private.financial_document_links` records relationships among original, refund, adjustment, and reversal documents. Updates and deletes are denied; corrections issue new linked documents.

Supported document types are:

- adult payment;
- teen earnings;
- store purchase;
- late tip;
- full refund;
- partial refund;
- adjustment;
- reversal.

Timing rules:

- provider-confirmed pre-work funding creates a funding confirmation/history fact, not a teen earnings receipt;
- the adult final job-payment receipt is issued after authoritative settlement and reflects funded base, compensated base, final MORT fee, refunds, and successful contemporaneous tip references;
- the teen earnings receipt is issued only after the authoritative settlement credits earnings;
- a later successful tip receives its own tip document;
- failed, declined, cancelled, unknown, or provider-unavailable attempts receive no success receipt;
- adult and teen receipts for the same job share an order reference but have distinct receipt numbers;
- external payout status is never embedded into an immutable receipt.

Documents snapshot privacy-safe party handles, job title, order number, line items, amounts, currency, policy versions, and masked payment metadata. They never reconstruct old facts from mutable current job or profile data.

## 21. Receipt numbering

Receipt numbers are generated only by a server function using cryptographically strong randomness:

- the first character is a random uppercase letter excluding `I`, `O`, and `L`;
- the letter has no document-type meaning;
- the remaining random body provides sufficient collision resistance;
- a unique database constraint detects collision;
- generation retries within a bounded server loop and fails closed after the bound;
- order numbers are independently server-generated, display as four digits where the Payment OS requires that presentation, use a collision-safe internal scope, and do not expose sequential database IDs.

Clients cannot reserve, propose, or alter receipt numbers.

## 22. Job and payment history

`private.financial_history_events` is the canonical append-only chronological feed. It includes authorized job events, funding attempts, payments, settlements, earnings, receipts, tips, refunds, adjustments, reversals, disputes, transfers, and payout-status events.

The read contract supports:

- cursor pagination using `(occurred_at, id)`;
- year filtering;
- event-type filtering;
- search by receipt number, order number, normalized job title, and privacy-safe handle;
- bounded page sizes and stable descending order.

The client never receives legal names, email, phone, exact job address, full provider references, raw provider errors, secret metadata, or another party's private history. Search keys are normalized server-side and scoped by authorization before matching.

## 23. Webhook architecture

The Stripe webhook remains an external endpoint with Supabase JWT verification disabled only because Stripe cannot present a Supabase JWT. It requires:

- the raw request body;
- `Stripe-Signature` verification with `STRIPE_TEST_WEBHOOK_SECRET` in sandbox;
- strict body-size limits;
- environment and `livemode` agreement;
- no secret or raw payload logging.

The event inbox extends the existing webhook table with:

- unique `(environment, provider_event_id)`;
- event type, provider-created time, payload hash, received time, delivery count;
- `RECEIVED`, `PROCESSING`, `PROCESSED`, `FAILED_RETRYABLE`, `FAILED_TERMINAL`, or `IGNORED` state;
- lease owner, lease expiry, attempt count, next-attempt time, and safe failure code;
- processed time and normalized target references.

Behavior:

1. A new event is inserted and leased.
2. A duplicate with the same hash returns the canonical result or current processing acknowledgment.
3. The same provider event ID with a different payload hash creates a security incident and is not processed.
4. An expired processing lease or `FAILED_RETRYABLE` event can be reclaimed.
5. The reducer locks affected records, validates the provider/environment/amount/currency/metadata relationship, and applies only legal monotonic transitions.
6. Financial finalization and idempotent event markers commit in one database transaction.
7. The inbox becomes `PROCESSED` only after that commit.
8. Out-of-order events are ignored, applied as a non-regressing transition, or trigger authenticated provider reconciliation.

Unique source-event constraints prevent duplicate transactions, ledger postings, earnings, tips, documents, transfers, refunds, and history events.

## 24. Status reconciliation

Webhook state is primary, supplemented by an authenticated server-to-provider status check when delivery is delayed or the result is unknown.

The status endpoint:

- authenticates the caller and verifies party ownership;
- loads the server-side provider reference rather than accepting one from Flutter;
- rate-limits by user, contract, attempt, and network signal;
- retrieves the provider object only in confirmed sandbox mode;
- applies the same normalized transition reducer used by webhooks;
- returns safe state, permitted next actions, and a masked attempt reference.

`UNKNOWN` blocks another payment attempt until reconciliation yields a safe terminal failure/cancellation or confirms the original attempt. A client timeout is never evidence of failure.

## 25. RLS and authorization

Clients cannot mutate financial truth. Financial tables remain in `private` with direct `anon` and `authenticated` privileges revoked. RLS is enabled and forced as defense in depth where supported.

Client reads occur through caller-bound RPCs or security-invoker views returning allowlisted DTOs. Authorization is party-based:

- payer sees authorized funding, payment, refund, adult document, and history data;
- worker sees authorized earnings, tip, teen document, transfer, payout-summary, and history data;
- neither party can enumerate receipt numbers or records belonging to another relationship;
- provider IDs and internal incident data remain server-side;
- guardian visibility follows the existing privacy-safe guardian financial-summary policy and does not expose adult payment credentials or raw provider data.

Privileged functions:

- live in a private schema when callable only by the service role;
- public wrappers exist only where Data API RPC access is required;
- set `search_path = ''` and schema-qualify every object;
- validate `auth.uid()` and relationship inside the function;
- reject user-supplied actor IDs;
- revoke `PUBLIC`, `anon`, and unintended-role execution before granting the exact role;
- use app metadata or private role assignments, never user-editable metadata, for authorization.

Staff financial roles expire, can be revoked, require reason codes, and generate audit events. High-risk refunds, adjustments, reversals, and control changes use two-person approval where policy requires it.

## 26. Rate limiting

Rate limits use the existing private, server-controlled mechanism. Clients cannot update counters. Limits combine authenticated user, IP/network signal, device/session signal where available, target job/contract, and operation.

Separate buckets cover:

- funding quote creation;
- PaymentIntent creation/confirmation preparation;
- status reconciliation;
- connected-account creation and onboarding links;
- readiness synchronization;
- refunds;
- tip quote and PaymentIntent creation;
- transfer, adjustment, reversal, and operator actions.

Limits are tighter for provider mutations and operator actions. A duplicate idempotent replay returns the original result without consuming a second financial operation, while abusive replay still contributes to abuse telemetry.

## 27. Observability and audit

Observability records:

- normalized state transitions and their source;
- quote, attempt, settlement, ledger transaction, document, and incident IDs;
- webhook inbox state, lease, retry, and reconciliation outcome;
- provider event/object references only in protected server-side storage;
- safe failure codes, latency, attempt counts, and rate-limit outcomes;
- actor, role, reason, before/after control state, and approval chain for operator actions.

Logs never contain secret values, client secrets, ephemeral-key secrets, webhook bodies, raw identity requirements, PAN/CVV, bank data, full provider errors, or unmasked PII. User-facing errors use a safe code and action such as retry, complete onboarding, check status, or contact support.

Alerts cover webhook backlog, failed leases, unreconciled unknown attempts, ledger imbalance rejection, transfer/refund mismatches, reversal failures, connected-account restrictions, dispute spikes, and negative platform-balance risk.

## 28. Payment OS mapping

The completed Flutter Payment OS remains the presentation foundation.

| Area | Existing Flutter surface | Mapping | Required change |
| --- | --- | --- | --- |
| Connected-account onboarding | `StripePayoutSetupScreen` | **EXTEND** | Render hosted-onboarding/readiness contract and safe blocker states |
| Pre-work funding | `StripeJobFundingScreen` | **EXTEND** | Consume authoritative funding quote, present PaymentSheet, reconcile status, and show funded/startable truth |
| Funding state | `MortPaymentState`, `MortPaymentStateBadge`, `payment_state_panel.dart` | **REUSE** | Map backend normalized states without local success inference |
| Expired/stale funding | Existing funding screen | **NEW STATE REQUIRED** | Show requote/refund-reconciliation state; no separate unrelated screen |
| Status-before-retry | Existing funding screen | **NEW STATE REQUIRED** | Block a second attempt and invoke status reconciliation |
| Post-work settlement | `PaymentReviewScreen` and legal contract/payment screens | **EXTEND** | Show funded base, authoritative compensation/refund, final fee, and optional new tip charge; do not charge base again |
| Partial compensation/dispute | Existing contract/payment resolution surfaces | **EXTEND** | Render server decision and appeal state; never accept an authoritative amount from the client |
| Fair Pay | `fair_pay.dart`, `fair_pay_panel.dart`, job-creation gates | **REUSE + EXTEND** | Replace reference/local authority with versioned server assessment |
| Tip selection | `tipping.dart`, `tip_selector.dart` | **REUSE + EXTEND** | Submit requested tip to separate backend tip quote/payment contract |
| Tip failure/retry | Payment review/history surfaces | **NEW STATE REQUIRED** | Preserve settled base while showing tip-only failure or unknown reconciliation |
| Receipt detail | `ReceiptDetailScreen`, `MortReceiptDocumentView` | **REUSE + EXTEND** | Load immutable authorized backend document by opaque receipt lookup |
| History | `JobPaymentHistoryScreen`, filters, rows | **REUSE + EXTEND** | Add server cursor, year, search, pagination, and canonical event types |
| Admin finance operations | `AdminPaymentOperationsScreen` | **EXTEND** | Use expiring audited roles, approvals, and safe operation contracts |
| Stripe SDK bridge | `StripePaymentSheetService` | **EXTEND AFTER BACKEND** | Replace intentional fail-closed stub only after contracts and test configuration pass |

No unrelated screen is redesigned. The final payment review must visibly distinguish already funded base/service fee from the separate optional tip charge.

## 29. Stripe mobile SDK integration

`flutter_stripe` is intentionally absent today and is added only after backend quote, attempt, status, webhook, and config contracts exist and pass sandbox tests.

The eventual mobile integration:

- receives the test publishable key through the authenticated config endpoint;
- initializes Stripe for the confirmed sandbox environment;
- receives PaymentIntent client secret, customer ID, and ephemeral-key secret only for the authorized attempt;
- presents the official PaymentSheet;
- treats the SDK result as presentation feedback, then reconciles backend/provider status;
- validates return/deep-link parameters and performs no destructive action directly from a deep link;
- stores no PAN, CVV, bank credential, Stripe secret key, webhook secret, or service-role credential;
- keeps payment feature flags fail-closed when the SDK, config, provider, or backend is unavailable.

## 30. RevenueCat and store-billing separation

Job payments use Stripe and this financial architecture. Digital subscriptions and other app-store purchases continue using the existing Google Play/RevenueCat architecture.

MORT does not create a second digital purchase path in Stripe. Store purchase documents are issued from server-verified store/RevenueCat events and use the common immutable document/history presentation, but they remain operationally and economically separate from job funding, teen earnings, Connect transfers, and tips.

## 31. Economics and pricing gates

The backend records actual provider costs rather than assuming that the sandbox service fee equals profit. Cost categories include:

- Stripe Payments percentage and fixed fee;
- international-card and currency-conversion surcharges;
- Radar Pro transaction cost under the owner-selected current configuration;
- Connect monthly active-account charges;
- funds-routing cost where applicable to MORT's account configuration;
- standard and optional instant payout fees;
- processing cost retained after refunds;
- dispute-received, dispute-response, and network fees;
- separate tip-payment processing cost;
- transfer reversal failure and platform-funded shortfall.

The September 2026 public US baseline used for sandbox modeling is 2.9% + $0.30 for a successful domestic online card charge. Current Connect public pricing describes account and payout costs for platform-controlled pricing, but MORT's actual agreement and configuration are not independently confirmed.

At the sandbox fee cap, payment processing alone can exceed MORT's $5 fee for higher-priced jobs. Separate tip charges also add another fixed processing fee while the full tip remains teen-owned. The system therefore stores provider fees and produces unit-economics reporting by policy version and job amount.

No code or UI may describe the sandbox 8%/$1/$5 policy as production-approved or claim exact production profitability. Production pricing, provider-fee payer, reserve level, the effect of Radar Pro transaction cost on MORT unit economics, payout cadence economics, and chart-of-accounts treatment require explicit owner and professional review. Radar Pro itself is already selected and must not be treated as an unresolved product-selection decision.

## 32. Sandbox test plan

The implementation plan must produce automated SQL, Edge Function, provider-contract, hostile-client, and Flutter tests plus controlled Stripe sandbox end-to-end scenarios.

Required scenarios:

- successful platform capture, funding gate, settlement, transfer, documents, and history;
- decline;
- requires action;
- pending where supported;
- cancellation;
- network interruption;
- `UNKNOWN` outcome;
- duplicate payment submission;
- status-before-retry enforcement;
- invalid webhook signature;
- duplicate webhook with matching hash;
- provider event ID with mismatched hash;
- failed webhook processing followed by successful leased retry;
- out-of-order webhook without state regression;
- no receipt on failed, declined, cancelled, unknown, or unavailable payment;
- adult final job-payment receipt after settlement;
- teen earnings receipt after authoritative earnings credit;
- separate contemporaneous tip and later tip;
- tip failure without base-settlement rollback;
- full refund;
- each component-aware partial refund;
- exact transfer reversal;
- transfer reversal failure and platform-shortfall handling;
- history cursor, year, search, and filter behavior;
- receipt lookup authorization and cross-user enumeration denial;
- minor connected account incomplete/restricted;
- connected account ready;
- job start blocked without authoritative funding;
- stale/superseded quote and changed-contract handling;
- concurrent quote, payment, start, settlement, and operator actions;
- Fair Pay `GREEN`, `YELLOW` allowed, `YELLOW` blocked, and `RED`;
- missing Fair Pay policy fails closed;
- tip below/above limits and missing tip policy fails closed;
- direct client mutation of financial truth denied;
- ledger imbalance rejected;
- dispute won, dispute lost, chargeback loss, and no automatic teen clawback;
- environment mismatch and live credential/mode rejection;
- secret and sensitive-log scans.

No sandbox test may use live credentials or real money.

## 33. Production activation gates

Live activation remains disabled until all of these are evidenced and recorded:

- Stripe platform account ready;
- Connect use case approved;
- US 13–17 hosted onboarding proven end to end;
- legal review complete;
- tax and privacy review complete;
- RLS, grants, hostile-client tests, and database advisors green;
- test webhook signature, retry, ordering, and reconciliation green;
- full sandbox end-to-end payment/settlement/transfer green;
- refund, partial refund, reversal, and reversal-failure recovery green;
- ledger balancing and reconciliation green;
- observability, on-call, retention, and incident runbooks approved;
- Connect/provider pricing confirmed;
- production unit economics and service-fee policy approved;
- production chart of accounts and reserve policy approved;
- final owner approval recorded.

Every gate is conjunctive. No single successful payment, sandbox test, secret presence, or deployment enables live mode.

## 34. Planned migration, Edge Function, and RPC inventory

Implementation will create migration files with the Supabase CLI so timestamps are generated by the tool. The exact migration slugs and responsibilities are:

1. `mort_stripe_policy_and_funding_v1` — versioned financial/Fair Pay/tip/partial-compensation policy, immutable funding quotes, request binding, and runtime-strategy constraints.
2. `mort_stripe_funding_attempts_and_state_v1` — extensions to PaymentIntents/attempts, normalized states, active-attempt uniqueness, funded job gate, and reconciliation metadata.
3. `mort_stripe_webhook_inbox_v2` — leases, retries, hash mismatch incidents, monotonic reducer contracts, and source-event idempotency.
4. `mort_stripe_settlement_ledger_v1` — settlement decisions, accounts, transactions, entries, balance enforcement, earnings/tip/fee/refund/transfer/dispute postings.
5. `mort_stripe_documents_history_v1` — immutable documents, links, receipt/order numbering, chronological history, authorized lookup, pagination, year, and search.
6. `mort_stripe_financial_access_and_activation_v1` — RLS/forced RLS, grants, security-definer hardening, audited staff operations, rate limits, observability, reconciliation, and production gates.

Existing Edge Functions to extend:

- `stripe-config`
- `stripe-create-connected-account`
- `stripe-create-onboarding-link`
- `stripe-get-connected-account-status`
- `stripe-create-job-payment-intent`
- `stripe-resolve-job-payment`
- `stripe-create-job-transfer`
- `stripe-create-job-refund`
- `stripe-webhook`

New Edge Functions:

- `stripe-create-job-funding-quote`
- `stripe-get-job-payment-status`
- `stripe-create-job-tip-payment-intent`
- `stripe-get-financial-document`
- `stripe-list-financial-history`

Existing server RPCs are extended compatibly or receive a versioned implementation. Exact new RPC contracts are:

- `stripe_server_create_job_funding_quote_v1`
- `stripe_server_consume_job_funding_quote_v1`
- `stripe_server_record_payment_intent_v2`
- `stripe_server_apply_payment_event_v2`
- `stripe_server_claim_webhook_event_v2`
- `stripe_server_lease_webhook_event_v2`
- `stripe_server_complete_webhook_event_v2`
- `stripe_server_fail_webhook_event_v2`
- `stripe_server_get_payment_status_target_v1`
- `stripe_server_prepare_settlement_v1`
- `stripe_server_finalize_settlement_v1`
- `stripe_server_prepare_transfer_v2`
- `stripe_server_record_transfer_v2`
- `stripe_server_prepare_component_refund_v1`
- `stripe_server_record_refund_v2`
- `stripe_server_prepare_tip_payment_v1`
- `stripe_server_finalize_tip_v1`
- `get_my_financial_document_v1`
- `get_my_financial_history_v1`
- `get_my_job_payment_status_v1`

Private implementation functions own financial mutations. Public client RPCs are caller-bound read/status contracts. Service-only public wrappers exist only where required by Supabase RPC exposure, have explicit grants, and delegate to private implementations.

## 35. Rollback and recovery

Database changes are forward-only and additive. Implementation must not reset hosted Supabase, rewrite migration history, delete immutable financial records, or destructively roll back a financial event.

Recovery strategy:

- disable the operation-specific runtime gate to stop new provider mutations;
- keep status, webhook, reconciliation, and authorized reads available where safe;
- roll Edge Functions back only to a database-compatible version;
- correct schema defects with a new forward migration;
- reclaim expired webhook leases and reconcile provider objects;
- create missing ledger/history/document artifacts idempotently from verified provider and settlement facts;
- resolve provider/database inconsistency through an audited reconciliation incident;
- represent human corrections as linked adjustment or reversal transactions/documents;
- rotate a compromised secret and invalidate affected sessions/provider endpoints without recording its value;
- never erase the historical transaction, receipt, refund, dispute, adjustment, or reversal that explains current balances.

An operator correction cannot edit an issued receipt or ledger entry. It creates a balanced append-only transaction and linked document, with actor, reason, evidence, approval, and source incident.

## References

- MORT Payment OS checkpoint: `1b4af24d00b41145aeb72c4b182f0b93824d9840`
- MORT Payment OS clean handoff supplied by the owner
- [Stripe Connect charge types](https://docs.stripe.com/connect/charges)
- [Stripe separate charges and transfers](https://docs.stripe.com/connect/separate-charges-and-transfers)
- [Stripe manual capture](https://docs.stripe.com/payments/place-a-hold-on-a-payment-method)
- [Stripe connected-account onboarding](https://docs.stripe.com/connect/onboarding)
- [Stripe pricing](https://stripe.com/pricing)
- [Stripe Connect pricing](https://stripe.com/connect/pricing)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Edge Function authentication](https://supabase.com/docs/guides/functions/auth)
- [Supabase Edge Function secrets](https://supabase.com/docs/guides/functions/secrets)
