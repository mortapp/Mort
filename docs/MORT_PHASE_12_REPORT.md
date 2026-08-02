# MORT Phase 12 Report

Updated: 2026-07-30

## Result

The code-controlled physical-services payment architecture is complete and
fail-closed on hosted project `rakjydmgwwgtdislanbt`. Stripe Connect separate
charges/transfers is retained as an evaluation architecture, not an approved or
active provider. No payment, fee, payout, provider onboarding, or live mode was
enabled.

## Delivered

- Server-owned strategies for collection, capture, and human-gated transfer
- Explicit false gates for provider, legal, privacy, minor payout, tax,
  retention, receipts, reconciliation, monitoring, and release approval
- Private forced-RLS financial incident queue with service-only idempotent,
  payload-bound ingestion
- Safe participant receipt/status projection that states it is not escrow or a
  tax receipt
- Role-separated payment operations visibility with no provider identifiers
- Financial-retention hold before Storage or Auth account deletion
- Honest Flutter payment and admin incident states with no Stripe SDK
- Correct physical-service Google Play boundary with no billing permission
- Owner setup guide, activation checklist, privacy corrections, and updated
  payment documentation

## Remote Changes

1. `20260730120000_financial_operations_completion.sql`
2. `20260730203047_fix_identity_storage_policy_execution.sql`
3. `account-deletion-processor` deployed ACTIVE as version 12

The second migration repairs a cross-feature RLS regression found by the full
hosted run: a broad Storage policy called a private identity helper directly,
which could break avatar replacement. The policy now uses the existing
current-user SECURITY DEFINER wrapper. Avatar and identity focused suites pass.

## Verification

| Gate | Result |
|---|---|
| Stripe hosted/source suites | PASS, 25/25 |
| Payment/dispute suites | PASS, 6/6 |
| Financial operations completion | PASS |
| Avatar policy regression | PASS |
| Identity provider regression | PASS |
| Flutter payment contracts | PASS, 4/4 |
| Flutter analyze | PASS, no issues |
| Database lint | PASS, zero findings |
| Migration parity | PASS, 157 aligned |
| Full hosted rerun | NOT COUNTED; final output detached by user interruption |
| Account-deletion worker E2E | BLOCKED; worker secret unavailable locally |

## Bugs Fixed

1. Two stale payment tests required a native Stripe SDK even though the release
   intentionally excludes it. They now lock the server contract and closed
   client boundary.
2. Payment UI copy implied a native PaymentSheet existed. It now states the
   provider is not connected.
3. Privacy copy incorrectly claimed Cash App/Square metadata, real ID uploads,
   and native monetization data collection. It now matches the disabled build.
4. Account deletion could remove Storage before discovering retained financial
   records. Retention review now occurs before any destructive step.
5. The identity Storage policy could break unrelated avatar cleanup through a
   private-helper permission error. A forward migration restored the RLS-safe
   wrapper.

## External Gates

Provider approval/credentials, legal/privacy/tax review, a compliant minor or
representative payout flow, real sandbox transactions, physical-device SDK QA,
financial staffing, reconciliation/on-call drills, store review, and owner live
approval remain incomplete. This is not production readiness.
