# MORT Payment Production Activation Checklist

Updated: 2026-07-30

All items are incomplete unless backed by dated evidence. Current result:
**BLOCKED - LIVE PAYMENTS MUST REMAIN OFF**.

- [ ] Provider approved the exact marketplace, country, connected-account, and
  teen/representative use case in writing.
- [ ] Licensed counsel approved payments, minors, worker classification,
  refunds, disputes, consumer terms, privacy, and retention.
- [ ] Tax professional approved reporting, form delivery, and record retention.
- [ ] Provider-approved minor payout/representative flow is documented; no age
  or identity workaround exists.
- [ ] Partial-compensation policy has a version, owner, and legal approval.
- [ ] Negative-balance, reserve, chargeback, transfer-reversal, and platform-loss
  plans are funded and approved.
- [ ] Receipts and tax-document wording is approved and tested.
- [ ] Financial deletion/de-identification policy is approved and exercised.
- [ ] Sandbox credentials are server-only and rotated after setup.
- [ ] Signed webhook, replay, outage, and secret-rotation drills passed.
- [ ] Real sandbox onboarding, charge, refund, transfer, reversal, dispute,
  payout, failure, and reconciliation journeys passed.
- [ ] Physical Android and iOS payment/onboarding journeys passed with supported
  SDKs in separately approved builds.
- [ ] Financial roles, two-person review, support hours, alerts, escalation, and
  on-call staffing are assigned to real trained people.
- [ ] Google Play/App Store declarations, privacy disclosures, terms, support
  scripts, and incident runbooks match the distributed binaries.
- [ ] Public marketplace, production identity verification, and payout account
  eligibility are approved independently.
- [ ] Owner approved a reviewed forward activation migration with rollback,
  monitoring, and incident evidence.

No checklist item may be inferred from code or automated tests alone.
