# Integration QA Report — QA project `ckcxakhxqlkhppsxxjhv` (2026-11-19/20)

## Scope and test conditions

- **Secrets.** Every secret is a QA-only value generated for this run; none were copied from production. Values are stored only in the QA project's function secrets and vault, and appear in no commit, file, log or screenshot.
  - `ACCOUNT_DELETION_WORKER_SECRET`
  - `IDENTITY_VERIFICATION_MODE=production` (the QA value; the handler only accepts this mode)
  - `IDENTITY_VERIFICATION_PROVIDER=mort_qa_test_provider`
  - `IDENTITY_VERIFICATION_WEBHOOK_SECRET`
  - `REVENUECAT_WEBHOOK_AUTH_HEADER`
  - `MORT_GOOGLE_PLAY_RTDN_SECRET`
  - `MORT_PASSWORD_ATTESTATION_SECRET`
- **Not set:** `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. The owner will supply a Play test-track service account later ("partial now, real later").
- **No real purchases or documents.** No live purchases, payouts or real identity documents were used. Identity tests used the QA test provider name and synthetic events. RevenueCat used a synthetic `SANDBOX` event.
- **Deployed functions** (QA only, `verify_jwt=false` per `supabase/config.toml`): `password-guard`, `account-deletion-processor`, `identity-verification-webhook`, `revenuecat-webhook`, `google-play-rtdn`.
- **Leak check.** Every response body was checked for every QA secret value and the service-role key: no hits. All evidence files and replica logs were scanned for secret values, session tokens, JWT patterns and `sbp_` tokens: no hits.
- **Logs.** The Management API logs endpoint returned 0 rows for the QA project during this run. Server-side log redaction was therefore verified by source review only:
  - each function's `structuredLog` call logs only a trace id, codes and the provider event id;
  - none logs headers, bodies, tokens or identity attributes.

  This is a limitation.

Evidence: `evidence/2026-11-19/integrations.jsonl`.

## RevenueCat (`revenuecat-webhook`)

| ID | Case | Result |
|---|---|---|
| RC-01 | Valid authorized SANDBOX `INITIAL_PURCHASE` for ADULT1, `mort_adult_pro_monthly` | PASS: 200 processed |
| RC-02 / RC-03 | Missing or wrong Authorization | PASS: 401 |
| RC-04 / RC-05 / RC-06 | Malformed JSON, missing event, unsupported product | PASS: 400 |
| RC-07 | Duplicate valid event (identical body) | PASS: 200 `duplicate_event`, no new row |
| RC-08 | Same event id with altered payload | PASS: 409 `duplicate_payload_mismatch` |
| RC-DB | DB state: 1 row in `revenuecat_events`. `revenuecat_product_states` and `monetization_entitlements_cache` give ADULT1 `mort_adult_pro` active for +30 days; RC-08's +10-year expiry was **not** applied. | PASS |
| RC-ENV | **FINDING (P1).** The handler ignores the RevenueCat `environment` field, and the stored normalized event drops it. A SANDBOX event granted a real entitlement. In production, StoreKit sandbox, TestFlight and Play license-tester purchases would grant production entitlements. Fix: persist `environment`, and reject or segregate non-`PRODUCTION` events in production. | FINDING |

The QA fixture ADULT1 currently holds a sandbox `mort_adult_pro` entitlement, which expires after 30 days.

## Google Play RTDN (`google-play-rtdn`), partial

| ID | Case | Result |
|---|---|---|
| GP-01 / GP-02 | Missing or wrong `x-mort-rtdn-secret` | PASS: 401 |
| GP-03 | Google-style OIDC bearer only, which is how real Pub/Sub push authenticates | 401. **This is the design defect below.** |
| GP-04 / GP-05 | Malformed envelope; non-base64 data | PASS: 400 |
| GP-06 | Wrong package name | PASS: 400 |
| GP-07 / GP-08 | Unknown purchase token, plus a duplicate | PASS: 404, no rows |
| GP-DB | `billing_notification_events=0`, `purchase_records=0` after all cases | PASS |
| GP-VALID | Valid notification for a known sandbox purchase | BLOCKED: needs `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` and a test-track purchase |

**Design defects (source review):**

1. Pub/Sub push subscriptions authenticate with a Google-signed OIDC JWT in the `Authorization` header and cannot add a custom `x-mort-rtdn-secret` header, so real RTDN deliveries would be rejected with 401 ([Pub/Sub push authentication](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions), [push subscriptions](https://docs.cloud.google.com/pubsub/docs/push)). The fix is to verify the OIDC token (issuer, audience and service-account email), or to accept a secret in the push endpoint URL query as a weaker interim measure.
2. The duplicate check (select, then insert) is racy, and the insert result is not checked. A unique constraint on `provider_event_hash` with `ON CONFLICT DO NOTHING` should be used instead.

## Identity verification (`identity-verification-webhook`, legacy path)

| ID | Case | Result |
|---|---|---|
| IDV-02 / IDV-03 | Missing signature; wrong-key signature | PASS: 401 |
| IDV-04 | Timestamp outside the 5-minute tolerance | PASS: 400 |
| IDV-05 | Signed malformed JSON | PASS: 400 |
| IDV-06 | Signed `sandbox`-environment event | PASS: 400 `provider_environment_mismatch` |
| IDV-01 / IDV-07 | Valid signed test-provider event, plus a duplicate | **BLOCKED**: 500 `provider_result_processing_failed`. The handler calls `process_identity_verification_provider_event_v2`, which exists in **neither QA nor production** (read-only check). ADULT2's `verification_status` was unchanged, so the failure was fail-closed. |

**Notes:**

- The legacy webhook only accepts `environment: "production"` events. Provider sandbox events can therefore only be tested against a configuration whose mode is labelled production, which makes QA/production separation depend on secrets alone.
- The production-lineage path is the `verification-provider-event` function. It was not exercised in this run.
- Identity v2 was not ported to QA; this deviates from the "port into QA" approval. Porting it, or retiring the legacy function, is a decision for the owner.

## Account deletion (`account-deletion-processor` and client RPCs)

| ID | Case | Result |
|---|---|---|
| DEL-01 / DEL-02 / DEL-03 | Missing secret, wrong secret, user JWT | PASS: 401 |
| DEL-04 | Valid secret, malformed body | **FAIL (minor)**: 500 `deletion_claim_failed` instead of 400. No state changed. |
| DEL-05 | Valid secret, empty queue | PASS: `processed: 0` |
| DEL-*-REQ, DEL-CANCEL, DEL-REREQ | Request, cancel and re-request through the client RPCs (disposable accounts DELETE1 and DELETE2) | PASS |
| DEL-X | ADULT1 cancels with no own request | PASS: `deletion_request_not_cancellable` |
| DEL-SVC | User calls `service_claim_account_deletion_request` | PASS: 403 permission denied |
| DEL-RUN / DEL-DB | Worker run with two requests queued (see below) | PASS |

The DEL-RUN / DEL-DB worker run had two outcomes:

- **DELETE2**, which has legal acceptances (RESTRICT FKs), was parked in `retention_review` with its data retained.
- **DELETE1** was fully processed:
  - its Auth user was deleted, and login now fails;
  - its one owned storage object was removed;
  - its request is `completed` and de-identified (`user_id` null).

**Retention rules:** the worker never hard-deletes a user that still has records under RESTRICT FKs (legal acceptances, safety, financial and audit). It parks them in `retention_review`. Over 50 RESTRICT foreign keys exist in the production lineage, so most real, onboarded accounts will land in `retention_review`. **Legal and product must decide** the retention matrix and the de-identification procedure before production use.

**Production gap:** the client deletion RPCs do not exist in production (read-only check). The in-app deletion request (store requirement) would fail there until the port, or an equivalent, is approved and applied.
