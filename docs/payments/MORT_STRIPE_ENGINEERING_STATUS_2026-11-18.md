# MORT Stripe Engineering Status — 2026-11-18

## Executive status

This continuation made targeted changes on the existing test-only Stripe branch; it did not restart the architecture or repeat prior migrations. The work is **not complete and is not approval to enable payments, transfers, or payouts**. PR #113 remains a draft. No live Stripe calls, PaymentIntents, transfers, refunds, or payouts were created in this work.

The latest fully completed CI run examined was [44332525650](https://github.com/mortapp/Mort/actions/runs/44332525650) for commit `a57f3b6e998c330203aa0feeb5f50a3346f099c2`. It failed only in `stripe-local-regression`; the failure was the new recipient-readiness gate correctly rejecting a synthetic quote because the local fixture had left `connected_accounts_approved` and `payouts_approved` false. The fixture was then updated to assert that rejection first and to set approval flags only inside the rolled-back local test transaction before its success-path retry. That correction is not yet in a completed CI run.

## Scope and safety

- The only Supabase project used or inspected for this Stripe work was test project `ckcxakhxqlkhppsxxjhv`.
- No production project or deleted project was modified. The separate production migration referenced by PR #38 was not touched.
- Existing migrations were not duplicated. The one forward migration already applied during the prior continuation restores the missing owner-scoped financial-history RPC on the authorized test project; its migration source is tracked in PR #113.
- No live credentials were used. The local session had no Stripe test secret or webhook secrets, and no local Supabase database URL/access token. The Supabase MCP available here did not expose project secret values or a names-only secret inventory.
- No provider object/event IDs or cleanup records exist because no provider objects were created. Provider E2E and hosted-regression CI jobs were skipped, not passed.

## Work completed or verified in this continuation

1. Restored the missing financial-history v2 RPC on the authorized test project through the tracked forward migration, and verified its owner-bound signature/grants and a synthetic non-existent-user call. The existing financial-document RPC was inspected for owner authorization and minimized results; this is not a full multi-role integration test.
2. Corrected a stale client contract assertion. The regression now requires a server status refresh and a server-reported `SUCCEEDED` state before the UI shows a funded status.
3. Added retryable Stripe transport/API error classification tests, malformed-JSON rejection coverage, and deleted Connect-account status payload tests.
4. Added source handling for `account.deleted` to the shared verification allowlist, the webhook handler, and the connected-account status refresh handler. Both source paths call the existing service-only status RPC with disconnected, non-payout-eligible, restricted state. This source change has passed local Deno type-check/tests in the branch, but has **not** been deployed to the test project or validated against a provider-signed event.
5. The local Stripe unit suite passed **31 tests, 0 failures** after the above additions. The pre-provider gate passed **18 cases** with `provider_mutation_performed: false`; the regression-manifest validator passed with `provider_e2e_executed: false`.
6. In CI run 44332525650, these jobs passed: `stripe-contracts` (including Edge Function type-check and Deno tests), `stripe-security-freeze`, `flutter-authoritative`, both Android APK build jobs, `expo-reference`, and `public-site`. The failing job was `stripe-local-regression`; provider E2E and hosted regression were skipped. `stripe-contracts` passed on that commit, so the source code and then-committed tests type-checked successfully.
7. Inventory of the authorized project showed all **13 Stripe-named Edge Functions active**. This is an inventory result, not proof that each deployed function matches the branch or passes its end-to-end database/provider contract.
8. Read-only inspection of `mort-web` found no Stripe/funding implementation in its app routes. Its payments page is explicitly preference-only and read-only, with save controls disabled; the adult job page contains no funding, refund, or payment-history flow. Therefore mort-web adult funding is **not integrated or complete**.

## Remaining engineering blockers — not complete

### P0: webhook fencing and delivery reliability

The current webhook claims events using the v2 claim RPC but does not carry the returned lease token into event application, completion, or failure recording. Completion/failure paths remain vulnerable to a stale worker racing a newer claimant. There is no completed integration coverage for duplicate, out-of-order, concurrent, stale-worker, or failed-delivery recovery. Do not consider webhook reliability complete until the claim/apply/complete/fail database contract is fenced atomically and those cases pass against the exact RPCs and handler.

### P0/P1: provider-created-but-unrecorded operations and ledger consistency

Onboarding AccountLink creation still lacks a durable request-id/idempotency lifecycle and recovery when Stripe creates a link but recording it fails; the provider link ID is not consistently persisted. Transfer/refund partial failures also need an explicit provider-ID/ledger reconciliation path and fault-injection tests. Existing idempotency helps retries but is not evidence that every partial failure leaves the internal ledger consistent.

### P1: guardian readiness lifecycle

The source currently maps Connect requirements into a limited set of states. The full guardian readiness lifecycle (unknown, required, pending, satisfied, restricted, and reversal/recovery behavior) has not been completed or tested across webhook, refresh, funding quote, and payout gates. Until then, guardian-dependent funding must remain fail-closed.

### Website and client verification

`mort-web` does not offer adult Stripe funding. Its current payment route explicitly disables saving preferences; there is no website PaymentIntent, status/refund/history, or Connect onboarding flow to verify. Client-side amount/recipient tampering cannot be declared comprehensively ruled out across the website because the flow does not exist. The Flutter source uses a server quote and refreshes server payment status; CI's `flutter-authoritative` and Android APK builds passed, but this is not a complete real-provider flow. iOS configuration/device behavior was not independently built or exercised in this run.

### Database / CI integration

CI run 44332525650's local regression failed at the intended readiness control with `recipient_model_not_approved_or_ready`. The test fixture now explicitly tests that fail-closed case, then enables synthetic approvals only within a rolled-back local QA transaction. Rerun the full CI job and verify every local migration regression. Hosted database integration remained skipped; no local Supabase database URL was available in this session.

### Test-project deployment parity

The test project has 13 active Stripe-named Edge Functions, but this continuation did not deploy the new `account.deleted` changes or prove that every deployed function and RPC matches the current branch. Deployment to the test project and invocation of the exact deployed handlers remain pending. Production must not be used to close this gap.

## Provider validation and owner/approval dependencies

Provider sandbox validation is still **not performed**. An authorized administrator must configure and confirm test-only Stripe API and platform/Connect webhook secrets on the authorized test project, verify that Stripe reports test mode and the expected account identity, and confirm the test-project secret set without exposing values. The local session has no Stripe secrets, and the available MCP cannot inspect remote secret names/values.

After that, run synthetic test identities through actual success, decline, 3DS, cancellation, retry, Connect onboarding, transfer/reversal, full/partial refund, signed webhook replay/recovery, dispute, reconciliation, and settlement scenarios. Capture actual Stripe object/event IDs, expected and actual outcomes, and cleanup status. Do not report any scenario passed without provider evidence. Stripe/Connect approval and legal/tax/guardian approval may be required before any recipient/payout path is treated as ready; do not activate live payments, payouts, subscriptions, or tips.

## Pull requests

- [PR #113](https://github.com/mortapp/Mort/pull/113) remains open and draft. The latest completed run examined, 44332525650, failed in `stripe-local-regression`; its other listed source/mobile/build/security jobs passed. The local fixture correction is pending a new completed CI run. Keep the PR in draft until CI, exact deployed test-project verification, provider evidence, and required owner/legal reviews are complete.
- [PR #38](https://github.com/mortapp/Mort/pull/38), “Restrict direct guardian-link writes,” is open but **not** a draft. It concerns a separate guardian-link security migration and states that its migration was applied to production on 2026-11-01. Its historical check set included a successful `stripe-contracts` job but failures in local regression, Expo reference, and public site. It was not modified as part of this Stripe assignment; do not infer that it is fully verified from PR #113 results.

## Next gates

1. Rerun CI after the local readiness-fixture correction; resolve any subsequent regression failures without weakening production controls.
2. Finish onboarding request idempotency/recovery, atomic webhook lease fencing, guardian state lifecycle, and partial-failure reconciliation with tests against the exact SQL functions and Edge handlers.
3. Deploy only to the authorized test project after review, then verify source/deployment parity and execute database integration tests there.
4. Have the authorized administrator configure test-only secrets and confirm sandbox account identity; only then run provider E2E and record object/event evidence.
5. Build and test iOS separately, add the mort-web adult funding flow or formally keep web payments disabled, and complete role/tenant isolation tests.
6. Keep all live payments and payouts disabled until owner, Stripe, legal/tax, and operational approvals are documented.
