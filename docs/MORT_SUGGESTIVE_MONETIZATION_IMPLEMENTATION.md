# MORT suggestive monetization implementation map

2026-10-04 integration follow-up: the current Free/Plus/Pro split, legacy
product compatibility, and remaining catalog/UI/store gates are recorded in
`docs/completion/MORT_MONETIZATION_INTEGRATION_2026-10-04.md`. Statements below
describe the original isolated suggestion branch where dated.

Date: 2026-10-03

## Existing

- Flutter is the authoritative client. RevenueCat owns digital purchase UI and
  client entitlement visibility; its authenticated webhook owns the server
  entitlement cache.
- The current verified Google Play catalog remains Weekly $0.99, Monthly $2.99,
  Annual $20.99, and Lifetime $30.99. The UI reads localized `priceString`
  values from the validated RevenueCat offering. These are billing periods for
  the existing MORT Pro product, not four product tiers.
- Continue with Free, restore purchases, customer management, teen purchase
  guidance, and the free safety/core-work contract already have Flutter tests.
- Stripe Connect remains a separate, fail-closed real-world marketplace rail.
  It cannot grant RevenueCat entitlements, XP, rank, Motion Tokens, or trust.
- Product analytics is consent gated, avoids sensitive payloads, and writes
  through the existing narrow backend repository.

## Implemented in this branch

- A centralized premium suggestion policy with account-scoped persistence,
  per-suggestion and global impression history, dismissal state, conversion
  state, 24-hour spacing, seven-day inline caps, and stricter interruptive
  caps. Concurrent prompt claims are serialized to avoid two placements both
  reserving the final available impression.
- Subscriber, safety-critical, unknown-entitlement, and converted-state
  suppression, including account switches and live entitlement changes. Local
  prompt state only suppresses marketing; it cannot grant access. RevenueCat
  errors and missing customer information fail closed for marketing.
- A reusable, dismissible MORT-styled inline suggestion card. It records
  consent-gated impression, dismissal, and click events with surface names.
- A progression surface shown after the user's authoritative progress loads.
  Copy explicitly keeps XP, rank, and Motion Tokens independent of purchases.
- Consent-gated paywall, purchase start/result, and restore funnel events. An
  additive SQL migration extends both the RPC taxonomy and its private table
  constraints with bounded event, surface, and outcome values. Client RPC
  rejection now produces a delivery failure instead of silently succeeding.
- Focused tests for frequency caps, dismissal cooldowns, account isolation,
  subscriber suppression, safety suppression, conversion suppression, free
  safety access, localized store prices, and Continue with Free.

## Intentionally unchanged

- Frozen Play build 114 and its store-backed prices.
- RevenueCat products, offerings, entitlements, and webhook deployment.
- Stripe live marketplace controls.
- Safety, verification, job discovery, applying, posting, messaging, earned
  money, disputes, moderation, Guardian Mode, and progression authority.

## Missing or requires a later product/catalog decision

- A true Free / Plus / Pro catalog cannot be claimed from the current provider
  evidence. The live app currently exposes Free plus one MORT Pro entitlement
  with weekly, monthly, annual, and lifetime billing options. Creating a Plus
  tier, Pro tier, new monthly/annual products, upgrade/downgrade paths, and a
  maximum-three-tier comparison requires coordinated App Store, Play Console,
  RevenueCat, webhook, legal-copy, device, and owner approval work.
- The client now separates Free, Plus, and Pro in one RevenueCat entitlement
  interpreter. A new `mort_plus` entitlement has Plus access only; `mort_pro`
  inherits Plus access. The historical `mort_plus_monthly`,
  `mort_plus_yearly`, and `mort_plus_lifetime` SKUs keep the Pro-equivalent
  client access they received in previous builds, but only while the matching
  RevenueCat Plus entitlement is active. These legacy SKUs must not be reused
  for a future lower-tier Plus offer. Current backend mappings remain Plus;
  any new server-side Pro-only feature must honor the documented grandfather
  rule before launch. A provider-side customer/SKU audit is still required.
- The only verified live offering is the four-product Pro `default` offering.
  Plus checkout, Plus-targeted suggestions, and Plus/Pro upgrade or downgrade
  claims remain off until a distinct provider offering and store products are
  verified. The current Pro suggestion is suppressed for both Plus and Pro
  subscribers; no subscriber sees a redundant acquisition prompt.
- Additional suggestion placements should be wired only at real success
  boundaries: application submitted, job completed, and first job posted.
  Their domain success callbacks need to be audited before UI insertion so a
  prompt can never precede or obscure success.
- Benefit-usage summaries require authoritative counters for boosts, advanced
  searches, and insights. No estimated benefit or invented savings is shown.
- Trial reminders, retention discounts, and win-back offers require verified
  provider configuration. The app must not display an unsupported offer.
- Apple Pay and Google Pay remain limited to eligible Stripe marketplace
  payments and require merchant/provider/device certification before release.

## Frequency policy

| Presentation | Minimum spacing | Seven-day maximum | After dismissal |
| --- | ---: | ---: | ---: |
| Inline card | 24 hours globally | 3 globally | 7 days per suggestion |
| Sheet/full screen | 24 hours globally | 1 globally | 14 days per suggestion |

Explicit user navigation to Optional subscription remains available and does
not use suggestion throttling.

## External gates

- RevenueCat/App Store Connect/Play Console catalog design and approval for any
  new Plus or Pro products.
- Real store sandbox purchase, renewal, grace, billing issue, cancellation,
  expiration, refund/revocation, upgrade, downgrade, and restore evidence.
- Apple Pay merchant ID and Google Pay production approval for Stripe Payment
  Sheet, plus physical-device validation.
- Legal/privacy/teen-spending review and owner rollout approval.
- No build 115, provider mutation, hosted database mutation, merge, or
  production rollout was performed by this branch.

## Verification of the follow-up analytics migration

- The MORT local Docker stack accepted the additive migration and the
  synthetic-user `qa-privacy-observability.mjs` suite passed consent,
  idempotency, bounded monetization taxonomy, rejected product identifiers,
  service-only rows, and immediate opt-out. No Loop container or hosted
  database was changed.
- Full Flutter analysis found no issues. Focused suggestion engine/card and
  safety tests passed after the account, entitlement, safety-transition, and
  optional local-storage failure fixes.
