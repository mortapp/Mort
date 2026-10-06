# MORT monetization integration evidence — 2026-10-04

**Later evidence:** signed build 115 was subsequently produced from `9c1721c`.
Backend expiry/Verify fixes and current artifact preservation are recorded in
[the 2026-10-05 continuation](MORT_CONTINUATION_2026-10-05.md). Statements below
about artifacts or pending exact-head tests describe the earlier checkpoint.
The subsequent [Flutter RPC response repair](MORT_RPC_RESPONSE_FIX_2026-10-05.md)
is verified in source and awaits confirmation of an unused packaging code.

Status: **FAIL — BLOCKERS REMAIN** for a Free / Plus / Pro release candidate.
This is an engineering ledger for `release/mort-post-114-integration`, not a
store launch approval. Uploaded Google Play closed-test build `0.9.16+114`
remains unchanged. No public production rollout, hosted migration, store
product change, or new Android artifact was performed.

## Branches and conflict map

- `feature/mort-classic-ui-redesign` at `0bebe2f` supplies the current classic
  UI, website, school gating, and account-deletion changes.
- `feature/mort-suggestive-monetization` at `7b4392f` supplies the existing
  soft-suggestion engine plus the Free/Plus/Pro entitlement split.
- Their common base is `9d6480c`. Before integration, the monetization branch
  changed 16 paths and the classic branch 101; no paths overlapped. The merge
  had no textual conflicts. Behavioral conflicts were found and repaired in
  the local school QA fixtures and an obsolete paywall source assertion.
- `origin/main` diverges from the post-114 release line and omits later safety
  and product work. The integration branch was based on the classic branch to
  preserve the verified post-114 code. Neither source branch nor `main` was
  merged into a production branch.

## Entitlements and product mapping

The client formerly treated `mort_plus` as Pro. The central
`RevenueCatEntitlementState` now resolves `mort_pro` to Pro, a new distinct
`mort_plus` product to Plus, and unknown entitlements to Free. Pro inherits
Plus-level perks. Ad-free and other add-ons remain independent. RevenueCat
`CustomerInfo` alone supplies active entitlements and active product IDs;
missing customer information grants no premium tier.

| Product ID | Store/billing | Entitlement | App tier | Evidence |
| --- | --- | --- | --- | --- |
| `mort_pro:weekly` | Play subscription, weekly | `mort_pro` | Pro | Code mapping; owner saw $0.99/week on build 114 |
| `mort_pro:monthly` | Play subscription, monthly | `mort_pro` | Pro | Code mapping; owner saw $2.99/month on build 114 |
| `mort_pro:annual` | Play subscription, annual | `mort_pro` | Pro | Code mapping; owner corrected and saw $20.99/year on build 114 |
| `lifetime` | Play one-time | `mort_pro` | Pro | Code mapping; owner saw $30.99 one-time on build 114 |
| `weekly`, `monthly`, `yearly` | RevenueCat Test Store | `mort_pro` | Pro | Test-only server mapping; no Play claim |
| `mort_plus_monthly`, `mort_plus_yearly`, `mort_plus_lifetime` | Historical/code-only, store existence unverified | `mort_plus` plus ad-free; lifetime also `mort_lifetime` | Pro-equivalent **client grandfather rule** while active | Previously received Pro client benefits; actual purchasers and store mapping need provider audit |
| `mort_ad_free_lifetime`, `mort_profile_style_pack`, `mort_adult_pro_monthly`, `mort_guardian_plus_monthly`, `mort_username_change_token_1`, `mort_job_boost_1` | Code-only side products; live availability unverified | Corresponding independent entitlements | Add-ons, not Plus/Pro tier | Webhook and SQL allowlists only |
| Future distinct Plus monthly/annual IDs | Not selected or verified | `mort_plus` | Plus | Empty, private provider map and empty client identifiers; **external catalog approval required before activation** |

The historical Plus SKUs are reserved: they cannot be reused for a newly
limited Plus offer. The server cache still labels those SKUs `mort_plus`,
reflecting its existing mapping; no current server Pro-only feature may be
assumed to honor the client grandfather rule. Verify historical customers in
RevenueCat before migration and align any future server Pro-only check.

The owner has no verified evidence that the three historical Plus SKUs were
sold. They remain reserved until a RevenueCat purchase-history and legacy
mapping audit confirms their status. No new Plus IDs or prices are approved.
The planning target is **$1.99/month for Plus**, below Pro Monthly at $2.99;
this is not a store price, offer, or activated product. An annual Plus price
remains undecided. The public identifiers can later be supplied through
`REVENUECAT_PLUS_OFFERING_ID`, `REVENUECAT_PLUS_MONTHLY_PRODUCT_ID`, and
`REVENUECAT_PLUS_ANNUAL_PRODUCT_ID` after catalog approval. The client rejects
legacy or Pro SKUs and packages that do not exactly match the separate Plus
offering. The private `revenuecat_plus_products` map is empty and disabled by
default, requires an approved timestamp and exact Play app/store match, and
is inaccessible to ordinary clients. Provider configuration and tests must
precede any Plus purchase UI; these identifiers alone cannot activate it.

Pricing is read from RevenueCat store metadata (`priceString`); no displayed
live price was hard-coded or changed. The four existing Pro billing options
remain on the current paywall because the new three-tier catalog and Plus
products are not verified. The maximum-three-tier acquisition UI, Plus
monthly/annual checkout, and upgrade/downgrade UI are **not complete**.

## Suggestive monetization

The account-scoped suggestion engine, dismissal state, 24-hour spacing,
seven-day cap, consent-gated analytics, and free dismissal remain intact.
Free users may see the existing optional **Pro** progression suggestion.
Both Plus and Pro subscribers suppress that acquisition suggestion. There is
no Plus-targeted copy or contextual Plus-to-Pro prompt until an actual Plus
offering exists. No purchase grants XP, rank, Motion Tokens, job priority,
verification, or safety access.

## Adult and business role

One universal Plus/Pro entitlement now resolves benefits for the active role.
Adult Plus accepts Plus or Pro; Adult Pro accepts Pro only, plus the historical
`mort_adult_pro` entitlement for existing holders. The older adult-only grant
does not promote worker access. The `FeatureAccess` adult applicant-sorting
capability is now Plus-or-higher; no poster screen currently invokes this
capability, so this does not claim a launched sorting tool.

Adult Free must retain job posting, applicants, hiring, scheduling, messaging,
completion, payment access, receipts, disputes, reports, verification, and
account controls. A source search found no subscription checks on those
existing routes. Local job-lifecycle, billing-boundary, and RLS regressions
remain the evidence for the available flows; **live marketplace settlement is
still disabled by the separate Stripe gate**, so full real-world payment
completion cannot be certified. Paid visibility must never bypass relevance,
age, safety, location, or moderation. Adult Plus product direction is reusable
posting, shortlist organization, and useful listing insights; adult Pro is
repeat-job/business organization. Those benefits need real implementations and
authoritative counters before display. No invented usage counts, boosts, or
listing-priority changes are active. No adult Plus prompt is shown before a
successful posting boundary; current suggestion work is a dismissible Pro
progression card and preserves its cooldowns.

## Lifecycle and security evidence

- A transaction-rolled-back local SQL test covers Plus activation,
  cancellation, billing issue, expiration, replay/payload mismatch, Pro
  activation, perpetual lifetime, and revocation. It verifies authenticated
  clients cannot execute the provider-only writer. This is **simulation**, not
  Play/RevenueCat transaction evidence.
- The new additive SQL migration makes `PRODUCT_CHANGE` informational. A
  deferred switch must not revive or grant a product before an actual purchase
  or renewal event. It was applied only to the local `mort-mobile` database.
  Provider-specific immediate and deferred upgrade/downgrade sequences still
  need real sandbox testing; server cache replacement semantics remain a gate.
- An additional local-only migration creates the private, empty Plus provider
  map. A rolled-back SQL test rejects unknown, disabled, wrong-app, and
  wrong-store entries, then activates/revokes an approved synthetic Plus
  product without granting Pro. The authenticated role cannot read or insert
  into the map or call the provider writer. This is not a provider purchase.
- Local MORT checks passed for analytics consent/replay/private rows, Plus
  entitlement forgery denial, purchase-token cross-account replay denial,
  RLS, account-deletion FK and functional behavior, and Stripe pre-provider
  separation. No Loop container was modified.
- The strict teen-school trigger exposed an obsolete local QA seeder. The
  seeder now binds synthetic teens through the real approved local-domain
  path before assigning the teen role. It does not create hosted approvals.
- The full Flutter regression exposed a timing race in one auth-startup test:
  it asserted immediately after the grace-window future completed while a
  later auth-stream event was still resolving. The test now waits for the
  authenticated state notification; focused auth-startup tests pass. The
  complete exact-head rerun is required before release packaging.
- The source secret scan found zero findings. Privileged RevenueCat, Stripe,
  Supabase, and signing credentials were not printed or committed.

## Exact integrated checks

At committed integration code `cb1272a` before the later SQL/QA evidence
patches: Flutter analyze **0 issues**; full Flutter suite **793 passed,
0 failed, 2 skipped**. After the current changes, focused monetization tests
passed **13/13**, focused auth-startup tests **26/26**, Flutter analyze
**0 issues**, Deno Edge tests **33/33**, classic legal website **3/3**, local
Stripe pre-provider gate **18/18**, and the source secret scan **0 findings in
2,481 files**. The first full precommit Flutter run had **794 passed, one
auth-startup timing-test failure, two skipped**; the timing assertion was
repaired. The local migration set includes the nine classic migrations,
suggestion analytics, deferred product-change, and private Plus mapping.
Rerun the complete exact final committed head before final certification.

## Remaining gates

1. **RevenueCat/Play/App Store catalog:** audit whether historical Plus SKUs
   were sold; choose distinct future Plus product IDs and store prices below
   Pro Monthly, attach them to a verified `mort_plus` entitlement and offering,
   then enter the exact IDs/app binding in the guarded client/provider maps.
   Confirm Pro mappings. Do not reuse grandfathered SKUs. No Plus catalog is live.
2. **Code/UI:** after catalog approval, implement the verified Plus offer, Free/Plus/Pro comparison
   with at most three primary tiers, store-backed monthly/annual controls,
   Plus purchase/restore/management path, and real upgrade/downgrade handling.
   The existing Pro paywall remains the working closed-test route meanwhile.
   Adult-specific Plus/Pro conveniences and outcomes also remain unimplemented;
   the shared role-aware entitlement helpers are ready without gating core Free.
3. **Lifecycle device/provider:** licensed Play sandbox purchase, entitlement
   receipt, renewal, cancellation through paid-period end, expiration,
   billing recovery/grace, refund/revocation, restore, and Plus/Pro changes.
   Build 114 proves only sheet launch/cancel, store pricing, and Continue with
   Free dismissal/no reopen by owner report.
4. **Release:** the owner confirmed versionCode **115** is unused for this
   integration candidate. Source `pubspec.yaml` is `0.9.16+115`; build 114
   remains unchanged. Build and verify signed APK/AAB only after the final
   exact-head checks, with Play billing enabled and public marketplace off.
   No artifact had been produced at this ledger checkpoint.
5. **Platform/operations:** Android physical layout and purchase tests, iOS
   macOS/Xcode and App Store sandbox evidence, legal/teen-spending review,
   and explicit rollout approval. No emulator was launched per owner request.

**Verdict: FAIL — BLOCKERS REMAIN.**
