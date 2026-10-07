# MORT black and gray primary interface — 2026-10-07

## Scope and design

The latest user clarification makes black and gray the primary interface colors and white a supporting color. This source correction supersedes the white-dominant palette recorded on 2026-10-06; that historical evidence remains preserved.

| Role | Color |
| --- | --- |
| Page background | `#0D0D0D` |
| Cards | `#1B1B1B` |
| Selected surface | `#2C2C2C` |
| Filled action | `#424242` |
| Main text/highlights | `#F1F1F1` |
| Supporting text | `#C1C1C1` |
| Secondary text | `#ACACAC` |
| White action text | `#FFFFFF` |

`MortClassicStyle` selects the existing flat layout independently of theme brightness. The dark palette therefore retains the current cards, navigation, controls, and entry hierarchy. Shared tokens cover feature screens; explicit paywall, safety, auth, receipt, progression, and native/web startup colors were aligned. The selected Annual badge and legacy destructive-button foreground were corrected after contrast checks found insufficient contrast.

Pet illustrations, character colors, accessories, auras, and colorful environments keep the dedicated pet palette. SHA-256 comparisons confirm that the pet palette, catalog, avatar renderer, and Guide mascot source files are unchanged. All 14 companions and three Guide mascots were visually inspected.

## Behavior and release boundaries

- Continue with Free remains directly below the paid action and invokes the existing close callback.
- Purchase, restore, entitlement, authentication, role, and backend behavior are unchanged.
- Production prices remain supplied by RevenueCat/Google Play. The isolated screenshot fixture uses previously reported Pro prices for illustration only.
- The localhost web preview disables IAP, ads, public marketplace, and marketplace payments. This does not modify Android release configuration.
- Repository version metadata remains `0.9.16+117`. No Android artifact was regenerated or overwritten; all six preserved +115/+116/+117 APK/AAB hashes and sizes match the previous preservation manifest.
- No merge, push, Play upload, or production rollout was performed. The separate Plus catalog/launch and actual purchase lifecycle gates are not certified by this UI change.

## Evidence

Evidence directory: `C:\Users\micha\Mort\build\ui-preview\black-gray-primary-2026-10-07`.

`verified-source-sha256.json` binds all changed Flutter/native/web source and test files to verification. `completion-head.json` records the final commit and confirms the manifest still matches after commit. `reviewed-source.diff` preserves the inspected diff.

Eight actual widget captures: paywall, welcome, Settings, emergency safety, Financial Safety, Companion Studio, all companions, and Guide mascots. The screenshot harness uses isolated synthetic preview data and invokes no real purchase or emergency action.

## Sequential audit

1. Believer: the semantic palette and captured screens implement the requested black/gray hierarchy with supporting white and vibrant pet artwork.
2. Skeptic: inspected the same diff for brightness-driven layout regressions, foreground contrast, native startup, hardcoded prices, and changed callbacks. Fixed the Annual badge and legacy destructive-button contrast; updated obsolete white-background test expectations. No production auth or entitlement changes were found.
3. Investor/operations: source correction is isolated on `feature/mort-neutral-all-screens`; existing signed releases and historical evidence are preserved. The local visual gallery identifies its synthetic data. Native device/store verification remains separate.
4. Judge: completion is limited to source/UI verification after the final gates below pass. Physical Android/iOS certification, release packaging, store acceptance, purchase lifecycle, and Plus launch remain unclaimed.

## Final checks

| Check | Result |
| --- | --- |
| Dart format | PASS — 409 files, 0 changed on final check |
| Flutter analysis | PASS — no issues |
| Focused final contrast/entry/components tests | PASS — 19 tests |
| Full Flutter suite | PASS — 804 tests, 2 skipped |
| Actual widget screenshot fixture | PASS |
| Android/iOS feature parity | PASS — 35 capability records; no physical-device claim |
| Native XML/plist/storyboard | PASS — valid files and dark startup |
| Pet artwork preservation | PASS — four source hashes unchanged |
| Secret scan | PASS — no findings; values not printed |
| Local Flutter web build | PASS |
| Browser smoke check | PASS — Enter MORT -> Welcome; no browser errors; gallery images loaded with no horizontal overflow |
| Preserved release artifacts | PASS — six original hashes/sizes unchanged |
| Source manifest consistency | PASS — verified files unchanged after final checks |

Local preview: `http://127.0.0.1:4173/neutral-ui.html?palette=20261007`. The app is available via the gallery's Open MORT app link. The Codex tab-open request was queued, so this report does not claim that a visible tab changed.

## Remaining gates

Physical Android/iOS appearance checks remain pending for this corrected source palette. Existing signed store builds are unchanged and do not contain this source correction. A future authorized release needs separate packaging/version-code/signing/store verification. No production rollout occurred. This UI verification does not complete Plus store setup or subscription purchase/renewal/expiration/restore certification.
