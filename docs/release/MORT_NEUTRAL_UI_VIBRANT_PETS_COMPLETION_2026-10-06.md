# MORT neutral interface + vibrant pets completion

Date: 2026-10-06
Branch: `feature/mort-neutral-all-screens`
Base release source: `058cec4b20d5061bfa84b4aeae95de9f9fcc456b`
Authoritative client: `flutter_mort`
Status: CODE_AND_LOCAL_PREVIEW_VERIFIED; NATIVE_DEVICE_RECHECK_PENDING

The user's latest correction is incorporated: pets are vibrant and colorful.
The paywall and application controls use white, black, gray, and silver.

## Implemented

- Shared white canvas, light gray/silver surfaces, near-black text/actions,
  readable secondary text, silver borders, and black selection indicators.
- Paywall: white surface, silver selected plan with black outline, black paid
  action with white text, Continue with Free directly below, neutral benefit
  icons, readable loading/disabled state, restore and legal links preserved.
- Shared tokens cover auth/onboarding, teen/adult/business, guardian, jobs,
  applicants, messages, safety, financial screens, receipts, progression,
  settings, support, legal, and admin. Literal application colors, progression
  SVG chrome, custom background/brand painters, and the web startup loader
  were audited and neutralized.
- Explicit repairs for emergency-panel contrast, Guide headings, Companion
  Studio sheets, onboarding completion icon, progression share cards, native
  startup surfaces/system-bar icons, selected chips, and premium lock icons.
- Separate `MortPetColors` artwork palette: fourteen colorful companions and
  three colorful Guide mascots; colorful accessories, items, auras, and
  illustrated environments. Studio page controls remain neutral.
- Coral, Sunshine, Mint, Lavender, and Sky cosmetic choices added. Existing
  saved-look IDs remain supported, including user-selected neutral looks.
- Existing iOS plist comment containing illegal internal double hyphens was
  repaired. Python plist/XML parsing now succeeds.

## Behavior preserved

Store prices and product/entitlement interpretation remain authoritative.
Paywall purchase, restore, selection, legal, dismiss/free callbacks and route
protection are unchanged. No auth bypass, local Pro grant, billing/provider
catalog change, backend migration, or marketplace activation was introduced.
Companion locks, account-scoped saved looks, reduced motion, safety-serious
mascot state, and focus timer behavior remain protected by the regression suite.
User images/documents and third-party provider logos remain content artwork.

## Final verification

| Gate | Result | Evidence in local evidence directory |
| --- | --- | --- |
| Dart formatting | PASS: 409 files, 0 changes | `dart format --output=none --set-exit-if-changed lib test` |
| Flutter analysis | PASS: no issues, 29.1 seconds | `flutter-analyze-final-vibrant-pets.log` |
| Full Flutter suite | PASS: 804 passed, 2 skipped, 0 failed | `flutter-tests-final-vibrant-pets.log` |
| Screenshot rendering | PASS: actual product widgets, 8 captures | `screen-capture-pet-gallery.log` |
| Web release preview compilation | PASS: 148.3 seconds | `web-build-vibrant-pets.log` |
| Source/generated-text secret scan | PASS: 16265 files, 0 findings | `secret-scan-vibrant-pets.log` |
| Android/iOS capability parity | PASS: 35 records | `platform-parity-verified.log` |
| Native XML/plist validation | PASS | Python plistlib and ElementTree parsing |
| Diff whitespace | PASS | `git diff --check` |
| Browser entry navigation | PASS: Enter MORT opens Welcome; no browser errors | `browser-landing-final.png`, `browser-welcome-final.png` |
| Screen gallery | PASS: screen switching/images load; no horizontal overflow | `http://127.0.0.1:4173/neutral-ui.html` |

Evidence directory:
`C:\Users\micha\Mort\build\ui-preview\neutral-all-screens`

New regression coverage verifies shared foreground contrast, neutral application
literals/progression SVGs, native light startup, paywall selection/action/free
ordering, emergency readability/actions, vibrant companion saturation, and
restriction of the character palette to illustration files.

Screenshots: paywall, welcome, settings, emergency, financial safety, Companion
Studio, all fourteen companion illustrations, and three Guide mascots. The
screenshots use isolated synthetic fixture data and explicit Roboto rendering
for test-only default-font fallbacks. Displayed paywall prices illustrate the
owner's earlier device-verified catalog; they are not a new live catalog fetch
or hardcoded production prices. No screenshot action performed a purchase,
emergency call, safety escalation, or real-account mutation.

Earlier test failures from stale dark/color expectations, Windows newline
sensitivity, and chip contrast were resolved. A test invocation with a wrong
paywall filename was superseded by the passing complete suite. Initial neutral
pet renders were superseded by the user's requested vibrant pet renders.

## Sequential review of the final source and evidence

1. Believer: shared palette reaches existing screens/components; updated
   paywall and colorful pet artwork match the latest user directions.
2. Skeptic: inspected white-on-white risks, selected/disabled controls,
   emergency labels/actions, native dark-device startup, dynamic text/scroll
   regressions, and the narrow character-color exception. Reproducible issues
   were fixed and affected/full checks passed.
3. Investor/operations: subscription/store pricing, activation flags, free
   exits, saved-look IDs, tier guards, signed artifacts and release gates are
   preserved. This visual work does not certify a live Plus catalog.
4. Judge: approve source/local preview completion. Do not claim physical
   Android/iOS appearance, Play acceptance, purchase lifecycle, or a new signed
   release from this branch. Those remain separate gates.

## Release state

- Source version metadata remains `0.9.16+117`; no release version bump.
- Signed 115, 116, and 117 APK/AAB files and their original evidence were kept.
  Read-only hashes are recorded in `preserved-artifact-hashes.json`; 116/117
  values match the prior recorded release hashes.
- No new Android APK/AAB, upload, merge, push, or production rollout.
- The modified UI is in source/local previews; existing phone artifacts retain
  their previously packaged interface. A future phone release needs a new
  separately authorized unused version code and packaging verification.
- Plus catalog approval and actual licensed purchase/renewal/expiration/restore
  certification remain external gates. Stripe marketplace stays fail-closed.
- Recheck startup/system bars and representative screens on physical Android
  and iOS, including large text and device dark appearance. iOS compilation
  was not performed on this Windows host. No emulator was opened.

The final committed SHA and source/evidence hashes are recorded after commit
in `completion-head.json` in the local evidence directory. The verified source
manifest is compared after commit so the recorded tests correspond to the
unchanged source, tests, assets, and native configuration in that commit.
