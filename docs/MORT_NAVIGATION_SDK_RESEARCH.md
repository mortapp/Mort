# MORT Navigation SDK Research (2026-08-19)

Researched using current official documentation (Google Maps Platform,
Mapbox) to answer: which routing/navigation SDK should MORT use for
post-authorized "navigate to job site," and is it safe/practical for
Flutter?

## Requirement recap

Once a Teen has an authorized, active job relationship (accepted +
mutual safety agreement confirmed -- exactly the existing
`get_released_job_location` gate), MORT should offer real turn-by-turn
navigation to the private job-site coordinates, without ever rendering
the destination as a permanently-visible, copyable street address.
Location access must already disappear on completion/cancellation/block
(already true -- verified live in the 18-check adversarial suite from
this session).

## Options compared

### Google Maps Platform + `google_navigation_flutter`

- **Flutter support**: Official first-party plugin, maintained by
  Google (`googlemaps/flutter-navigation-sdk` on GitHub, published as
  `google_navigation_flutter` on pub.dev). Wraps the native Navigation
  SDK for both platforms.
- **Android**: Full native Navigation SDK support.
- **iOS**: Also supported by the same plugin -- meaningful for MORT's
  "iOS source parity now, platform work later" goal, since the Flutter
  integration work would not need to be redone platform-by-platform.
- **Maturity**: **Beta, pre-1.0.** Per its own docs, breaking changes
  are possible before a 1.0 release. This is the main real risk.
- **Turn-by-turn**: Full native turn-by-turn guidance, Android
  Auto/Apple CarPlay compatible.
- **Pricing**: Navigation SDK is billed per destination requested in a
  route calculation; Google reduced per-destination pricing and lowered
  volume-discount thresholds in a May 2025 update. First destinations
  each month are free (exact current free-tier count and per-destination
  rate should be reconfirmed in the Cloud Console pricing calculator at
  enablement time, since Google revises these periodically). The
  separate Routes API (for the "X.X miles away" ETA figure, distinct
  from full turn-by-turn) has its own free monthly SKU allowance.
- **API-key security**: Google's own documented pattern is to embed a
  *restricted* client key (not a secret) directly in the app, then lock
  it down in Cloud Console to the specific APIs used (Navigation SDK,
  Maps SDK for Android/iOS) plus platform restrictions (Android package
  name + SHA-1 signing-certificate fingerprint; iOS bundle ID). This is
  the standard, Google-sanctioned model -- not a backend-proxy pattern,
  and not something a `--dart-define` secret-key regex guard would even
  flag, since it's meant to be client-embedded and restricted rather
  than kept secret. Distinct from any `SUPABASE_SERVICE_ROLE_KEY`-style
  secret.
- **Privacy**: The route computation happens against Google's own
  servers; MORT would send the destination coordinates (already
  server-authorized at that point) plus the Teen's live position while
  actively navigating. This is materially similar in exposure to any
  third-party navigation option -- there's no way to get real turn-by-
  turn without a routing provider seeing origin/destination.

### Mapbox

- **Flutter support**: A Maps SDK for Flutter exists, but per Mapbox's
  own guidance surfaced in current documentation, **the Flutter SDK does
  not provide full turn-by-turn navigation out of the box** -- real
  navigation requires pulling in additional native Mapbox Navigation
  SDK pieces and building the turn-by-turn UI/logic manually. This is a
  meaningfully larger integration lift than Google's plugin for the
  specific "give me a working turn-by-turn screen" requirement.
- **Pricing**: Billed per Monthly Active User of the app (not per
  route/destination) -- a different cost shape that may be cheaper or
  more expensive than Google's depending on MORT's actual usage pattern;
  needs modeling against real user counts, not guessed.
- **Maturity**: Core Maps SDK is mature; the navigation layer is the
  weaker fit for Flutter specifically, per the above.

## Recommendation

**Google Maps Platform (`google_navigation_flutter`) for post-authorized
navigation, with the Beta status explicitly flagged as a real, current
risk rather than downplayed.** It's the only option offering genuine
turn-by-turn Flutter support for both Android and iOS as an official,
maintained plugin -- directly matching MORT's stated Flutter-first,
Android-now/iOS-later architecture. Mapbox remains a credible fallback
if the Beta instability becomes a real problem, but would require
building meaningfully more of the navigation UX by hand today.

## What this does NOT authorize by itself

Enabling this requires the owner to:

1. Enable billing on the actual Google Cloud project tied to MORT (a
   real financial/account action -- not something to do silently).
2. Generate and restrict a Maps/Navigation API key in Cloud Console
   (Android package + SHA-1 fingerprint, iOS bundle ID, API
   restrictions).
3. Confirm current per-destination/Routes SKU pricing in the Cloud
   Console calculator at the time of enablement (rates are periodically
   revised by Google; the figures above are directional, not a
   committed quote).

None of this was done as part of this research pass -- it's an owner
decision with real recurring cost, consistent with how AdMob/Play
billing-adjacent items have been handled all session (researched and
documented, never silently actioned).

## Interim UX until navigation is built

The existing `get_released_job_location` RPC already returns
`latitude`/`longitude` once authorized (built earlier this session). A
reasonable interim step, once the owner approves the SDK choice, is a
simple "Navigate to job site" button that launches the coordinates in
the device's default external maps app (`url_launcher` with a
`geo:`/`google.navigation:` intent) rather than building the full
in-app `google_navigation_flutter` integration immediately. This ships
real navigation utility sooner, at the documented privacy tradeoff:
launching an external app creates navigation history in that third-party
app that MORT cannot see or revoke. This tradeoff should be stated to
the Teen in-product (e.g. "Opens your default maps app"), not hidden.
