# Progression certification test inventory

Date: September 21, 2026

## Inventory result

| Snapshot | `test/**/*.dart` | `integration_test/**/*.dart` | Total |
| --- | ---: | ---: | ---: |
| Merge base `514a91477bded1f34af23f68eb1e781d221b15b4` | 87 | 1 | 88 |
| Current HEAD `fe9c3110c2ae8c501e136714b1072b616826fbaa` | 87 | 1 | 88 |
| Working tree before this certification pass | 107 | 1 | 108 |
| Working tree after adding the iOS progression privacy contract | 108 | 1 | 109 |
| Divergent `origin/feature/mort-master-blueprint-gamification` | 116 | 1 | 117 |

No test file present at the merge base or current HEAD is missing from the working tree. The working tree contains 21 new test files and zero deleted test files relative to HEAD. Flutter discovered and executed the current unit/widget suite; the two reported skips are runtime-gated Google activation tests rather than discovery or compilation failures. The Android integration file requires a real emulator or device and is not included in the ordinary `flutter test` count.

Final machine-readable result: **566 passed, 2 skipped, 0 failed**. The three-test increase from the earlier 563 result is the new iOS progression privacy contract. The intentional skips are `closed-test compile configuration activates approved Google Auth` and `Continue with Google is visible and enabled`.

## New files relative to HEAD

- `entry_redesign_test.dart`
- `financial_exports_test.dart`
- `financial_guide_routes_test.dart`
- `financial_math_test.dart`
- `financial_screens_test.dart`
- `ios_progression_privacy_contract_test.dart`
- `mockup_data_isolation_contract_test.dart`
- `mort_animation_architecture_contract_test.dart`
- `mort_atmosphere_composition_test.dart`
- `mort_atmosphere_device_policy_test.dart`
- `mort_atmosphere_test.dart`
- `mort_atmosphere_widget_test.dart`
- `mort_cloud_renderer_test.dart`
- `mort_component_system_test.dart`
- `mort_mascots_test.dart`
- `primary_surface_visual_contract_test.dart`
- `production_visual_identity_contract_test.dart`
- `progression_model_test.dart`
- `small_screen_pressure_test.dart`
- `unified_auth_google_test.dart`
- `unified_auth_visual_contract_test.dart`

## Why historical totals differ

The repository contains reports from multiple divergent integration efforts. The accepted UI V6 report records 560 passed and 2 skipped. The separate iOS V6 bundle records 579 passed and 2 skipped. The current 563 count came from the UI working tree plus progression coverage; it did not result from deleting tests on this branch.

The later blueprint branch has 25 files absent from this UI working tree:

- 11 Payment OS, receipt, payment widget, and semantics files whose imported `features/payments`, `features/history`, and `features/receipts` modules do not exist in this checkout.
- 8 earlier monochrome foundation and visual convergence files superseded by the current atmosphere, component-system, production-identity, small-screen, and entry redesign suites.
- 2 BrowserStack QA files whose QA application and fixture modules do not exist in this checkout.
- 1 shared widget helper used by the divergent visual suite.
- 1 broader iOS parity file tied to the divergent Payment OS and BrowserStack workflows.
- 1 MORT Verify migration contract tied to the 53 newer hosted migration files missing from this branch.
- 1 pending-legal-reacceptance file tied to a repository API absent from this checkout.

Those files were added after branch divergence and were never deleted from the current branch. Restoring them unchanged would either fail compilation or reintroduce assertions for an older interface. The applicable iOS privacy and asset coverage was extracted into `ios_progression_privacy_contract_test.dart` after it exposed a real missing privacy manifest and release entitlement.

## Intentionally removed tests

None from the current branch or its merge base.

## Remaining coverage gates

- `integration_test/android_native_smoke_test.dart` passed both tests on the Pixel 6 emulator with the expected 0.9.16+107 version defines.
- Xcode compilation, CocoaPods, signing, and physical iPhone behavior require macOS or the exact-head macOS CI workflow.
- The divergent MORT Verify contract requires migration-history reconciliation before it can become a valid current-branch test.
- Hosted progression JWT and Data API attacks require the progression migration on a non-production QA project. The same permissions, XP, replay, privacy, and concurrency behavior is exercised locally against PostgreSQL 17 during this certification pass.
