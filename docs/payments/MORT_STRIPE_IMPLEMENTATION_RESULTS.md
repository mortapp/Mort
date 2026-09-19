# Stripe Connect Implementation Results

Status: Tasks 1-31 complete on the Stripe feature branch. Task 32 regression wiring is implemented and its Task-32-specific CI gates are green; the final all-green regression is currently blocked by secret-scanner false positives that are owned by Task 33. Live payments remain disabled.

## Task 31 — controlled Stripe sandbox E2E

Task 31 is complete.

- The controlled Stripe sandbox run produced passing sanitized evidence for all 22 required scenarios.
- The committed evidence is `docs/payments/MORT_STRIPE_TASK31_SANDBOX_EVIDENCE_2026-09-18.json`.
- The repo validator accepted that evidence with `complete=true` and `provider_e2e_executed=true`.
- Recent Task 31 webhook inbox reconciliation finished with zero unreconciled events.
- No live Task 31 PaymentIntent was created and no real card data was used.
- After QA, `sandbox_provider_qa_approved`, payments, connected onboarding, job funding, transfers, refunds, live mode, and live owner approval were restored to false.
- The temporary Task 31 QA function was made inert and JWT-protected.

## Task 32 — full Stripe regression gate

Implemented:

- `scripts/run-mort-stripe-regression.ps1` is the fail-fast regression entrypoint.
- The runner verifies six hosted-aligned migration responsibility anchors without renaming already-applied migrations:
  - `mort_stripe_policy_and_funding_v1`
  - `mort_stripe_funding_attempts_and_state_v1`
  - `mort_stripe_webhook_lease_v1`
  - `mort_stripe_settlement_ledger_v1`
  - `mort_financial_documents_history_v1`
  - `mort_stripe_financial_access_hardening_v1`
- It runs local Supabase start/reset and migration listing unless explicitly skipped, the full Supabase regression, the Stripe pre-provider fixture gate, all Deno Edge tests, Supabase advisors, Flutter formatting/analyzer, the focused Payment OS integration test, the full Flutter suite, source/extraction/history secret scans, the Task 32 manifest, and `git diff --check`.
- Successful runner output contains an `evidence_matrix`; every row records `command`, `commit`, `timestamp`, `result`, and `environment`.
- Ordinary pull-request CI does not execute provider mutations.
- The protected/manual `stripe-provider-e2e` job is `workflow_dispatch`-only and routes through `stripe-sandbox-e2e.ps1`, which itself runs the Task 30 and Connect preflight gates.
- The hosted non-provider regression remains a separate manual workflow-dispatch job.

### Task 32 verification matrix

| Command / gate | Commit tested | Timestamp (UTC) | Result | Environment |
| --- | --- | --- | --- | --- |
| `node scripts/qa-stripe-pre-provider-gate.mjs` | `351ab2bc` | 2026-09-19T01:31:54Z | PASS | PR CI / non-provider |
| `deno test --node-modules-dir=auto --allow-read --allow-env supabase/functions/_tests` | `351ab2bc` | 2026-09-19T01:31:54Z | PASS — 26 tests | PR CI / non-provider |
| Task 31 committed sandbox evidence validation | `351ab2bc` | 2026-09-19T01:31:54Z | PASS | Stripe sandbox evidence |
| `node scripts/qa-stripe-sandbox-e2e-evidence.mjs --regression-manifest` | `351ab2bc` | 2026-09-19T01:31:54Z | PASS | PR CI / source contract |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | `351ab2bc` | 2026-09-19T01:31:54Z | PASS | Flutter CI |
| `flutter analyze --no-pub` | `351ab2bc` | 2026-09-19T01:31:54Z | PASS | Flutter CI |
| `flutter test --no-pub test/features/payment_os_integration_test.dart` | `351ab2bc` | 2026-09-19T01:31:54Z | PASS | Flutter CI |
| `flutter test --no-pub` | `351ab2bc` | 2026-09-19T01:31:54Z | PASS | Flutter CI |
| `node scripts/build-public-legal-site.mjs && node scripts/validate-public-legal-site.mjs` | `351ab2bc` | 2026-09-19T01:31:54Z | PASS | Public-site CI |
| `./scripts/secret-scan.ps1` | `351ab2bc` | 2026-09-19T01:31:54Z | BLOCKED — scanner classifies its own test/regex literals and existing private-key parser source as findings | Task 33 dependency |

The secret-scan failure reports paths such as the scanner implementation itself, synthetic Stripe test fixtures, `HostedWireDTOTests.swift`, and the existing push private-key parser. The scan prints no secret values. Correcting scanner allowlisting/classification belongs to Task 33, whose declared files include `secret-scan.ps1`, `secret_extraction_scan.mjs`, and `secret-scan-git-history.mjs`. Those files were intentionally not modified as part of Task 32.

Because the full regression entrypoint intentionally includes the secret scans, Task 32 must not be called fully GREEN until Task 33 corrects those scanner false positives and the complete runner is executed successfully.

## Architecture and safety state

- Primary funding remains a pre-work platform charge/capture with a server-issued quote and `transfer_group`; the primary PaymentIntent does not use destination-charge fields.
- Server-authoritative settlement determines compensated base, exact teen transfer, component refunds, and separate optional tips.
- Tips remain separate post-work PaymentIntents with 100% tip principal assigned to the teen and no MORT tip fee.
- Payment, transfer, and payout state remain distinct.
- Webhook signature verification, leases/retries, duplicate handling, and monotonic stale-event behavior are regression-covered.
- Production pricing, production partial-compensation values, live payment activation, instant payouts, and live provider mutations remain disabled.

## Remaining sequence

1. Finish Task 33 secret hygiene and production-activation freeze.
2. Re-run `scripts/run-mort-stripe-regression.ps1` and require a fully green evidence matrix.
3. Keep live activation closed until all external legal, tax, privacy, minor-Connect, economics, monitoring/on-call, provider-pricing, and final owner-approval gates are independently satisfied.
