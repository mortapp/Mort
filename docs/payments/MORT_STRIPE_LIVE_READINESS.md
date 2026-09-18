# Stripe Live Readiness

Updated: 2026-09-18

Current result: **NOT LIVE READY — LIVE PAYMENTS MUST REMAIN OFF**.

## Verified fail-closed state

A read-only check of the hosted MORT project on 2026-09-18 shows `mode=sandbox`. Payment, connected-account onboarding, job funding, transfer, refund, live-mode, owner-live-approval, provider-use-case, legal, privacy, minor-payout, tax, negative-balance, retention, receipts, reconciliation, monitoring/on-call, and production-release approvals are all false. `partial_compensation_policy_version` and `production_approved_at` are unset.

The database function `private.stripe_live_financial_ready()` is conjunctive: live readiness requires live mode plus every stored approval, a production partial-compensation policy version, production release approval, and a production approval timestamp. No code-only or test-only result can satisfy those external approvals.

## Blocking gates

- **Provider/minor model:** obtain written provider approval for MORT's exact marketplace model and end-to-end US **minor Connect** / representative flow for ages 13–17. No age, identity, bank, or guardian-evidence workaround is permitted.
- **Production pricing:** approve production service-fee pricing, including exact fee schedule, **provider fee payer**, refund economics, and Connect/provider pricing.
- **Fraud economics:** **Radar Pro** is the selected fraud configuration, but its **transaction cost** and effect on unit economics remain an explicit production input.
- **Reserve/accounting:** approve the negative-balance and chargeback reserve, platform-loss policy, and production **chart of accounts**.
- **Partial compensation:** approve versioned **production partial-compensation** values and legal rationale. Sandbox policy values are not production approval.
- **Legal/tax/privacy:** qualified review is still required for minors, worker classification, consumer terms, refunds, disputes, tax reporting, privacy, retention, receipts, and financial deletion/de-identification.
- **Operations:** assign real financial roles, reconciliation schedule, alerting, escalation, **monitoring/on-call**, support coverage, incident drills, and two-person review where required.
- **Provider testing:** the ordered pre-provider gate must pass before controlled Stripe sandbox mutation testing; the full onboarding/funding/settlement/transfer/refund/reversal/tip/dispute/payout/reconciliation matrix must then pass with sanitized evidence.
- **Physical devices:** supported Android and iOS PaymentSheet plus Stripe-hosted onboarding flows require physical-device verification in separately approved builds.
- **Store/public release:** Google Play/App Store declarations, privacy disclosures, terms, support scripts, public marketplace activation, production identity verification, and payout-account eligibility remain separate gates.
- **Final owner approval:** a reviewed forward-only activation migration, rollback/disable procedure, monitoring evidence, provider pricing evidence, and **final owner approval** are required before any live flag or credential is enabled.

## Credential rule

No live secret, restricted key, webhook secret, PaymentIntent client secret, service-role JWT, or live publishable-key value belongs in source, Git history, build artifacts, logs, screenshots, or evidence. Secret variable names may appear in server-only configuration/docs; actual values remain in approved secret stores only.

Until every blocking item has dated evidence, live credentials, live provider mutations, instant payouts, production pricing, and production partial-compensation values remain disabled.
