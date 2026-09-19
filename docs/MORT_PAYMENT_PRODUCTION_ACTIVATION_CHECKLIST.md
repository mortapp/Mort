# MORT Payment Production Activation Checklist

Updated: 2026-09-19

All items are incomplete unless backed by dated evidence. Current result:
**BLOCKED — LIVE PAYMENTS MUST REMAIN OFF**.


## Production gate ownership matrix

| Gate | Owner | Evidence | Status |
| --- | --- | --- | --- |
| Exact provider marketplace/use-case approval, including minor Connect ages 13–17 | Provider relationship owner | Written provider approval for the exact MORT flow | BLOCKED |
| Legal review | Licensed counsel | Dated written legal approval covering minors, worker classification, refunds/disputes, consumer terms, privacy/retention/receipts | BLOCKED |
| Tax reporting | Tax professional | Dated reporting/form-delivery/record-retention approval | BLOCKED |
| Production pricing and provider fee payer | Product + finance owner | Approved service-fee/refund schedule, provider fee payer, Connect/provider pricing, store/public disclosures | BLOCKED |
| Radar Pro economics | Finance owner | Radar Pro transaction cost incorporated into reviewed unit economics | BLOCKED |
| Production partial compensation | Product + legal owner | Approved production values, semantic version, rationale, and release evidence | BLOCKED |
| Reserve and chart of accounts | Finance/accounting owner | Approved reserve, negative-balance/chargeback loss plan, and production chart of accounts | BLOCKED |
| Minor payout/representative flow | Provider + legal owner | End-to-end provider-approved minor representative/payout proof with no workaround | BLOCKED |
| Monitoring/on-call and financial operations | Operations owner | Named staffing, alerts, escalation, reconciliation schedule, incident drills, support hours | BLOCKED |
| Physical Android/iOS payment/onboarding QA | Mobile release owner | Dated physical-device PaymentSheet and hosted-onboarding evidence | BLOCKED |
| Store/public disclosures | Release + legal owner | Reviewed Play/App Store declarations, privacy disclosures, terms, support scripts | BLOCKED |
| Final activation | MORT owner | Reviewed forward-only activation/disable procedure plus every prior gate's dated evidence | BLOCKED |


- [ ] Provider approved the exact marketplace, country, connected-account, and teen/representative use case in writing, including **minor Connect** readiness for ages 13–17.
- [ ] Licensed counsel approved payments, minors, worker classification, refunds, disputes, consumer terms, privacy, retention, receipts, and financial deletion/de-identification.
- [ ] Tax professional approved reporting, form delivery, record retention, and operational ownership.
- [ ] **Production pricing** is approved: service-fee schedule, refund economics, **provider fee payer**, Connect/provider pricing, and store/public disclosures.
- [ ] **Radar Pro** remains the selected fraud product and its **transaction cost** is incorporated into reviewed unit economics.
- [ ] Production **partial-compensation** policy has approved values, version, owner, legal rationale, and release evidence.
- [ ] Negative-balance, chargeback, transfer-reversal, and platform-loss plans are funded; the reserve and production **chart of accounts** are approved.
- [ ] Provider-approved minor payout/representative flow is documented; no age, identity, bank, SSN, or guardian-evidence workaround exists.
- [ ] Sandbox credentials are server-only, rotated as required, and source/history/artifact/evidence secret scans pass.
- [ ] Ordered pre-provider gate passes before any provider mutation.
- [ ] Real sandbox onboarding, charge/capture, decline, requires-action, ambiguity/retry, webhook duplicate/out-of-order, settlement, transfer, refund, reversal, tip, dispute, payout, failure, and reconciliation journeys pass with sanitized evidence.
- [ ] Signed webhook, replay, outage, lease-recovery, reconciliation, and secret-rotation drills pass.
- [ ] Physical Android and iOS PaymentSheet and Stripe-hosted onboarding journeys pass with supported SDKs in separately approved builds.
- [ ] Financial roles, two-person review, support hours, alerts, escalation, reconciliation schedule, and **monitoring/on-call** staffing are assigned to trained people.
- [ ] Google Play/App Store declarations, privacy disclosures, terms, support scripts, and incident runbooks match the distributed binaries.
- [ ] Public marketplace, production identity verification, payout-account eligibility, and standard-payout-only policy are approved independently.
- [ ] Provider pricing and reserve assumptions are rechecked against the final production account configuration.
- [ ] A reviewed forward-only activation migration and disable/recovery procedure are approved.
- [ ] **Final owner approval** is recorded only after all prior evidence is complete.

Current hosted controls remain sandbox/fail-closed: live mode, live owner approval, provider/use-case approval, legal/privacy/tax/minor payout approvals, production release approval, and provider-mutation flags are false; production partial-compensation version and production approval timestamp are unset.

No checklist item may be inferred from code or automated tests alone.
