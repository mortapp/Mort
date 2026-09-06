# MORT Flutter Desktop Shader Failure Matrix

## Baseline

- Command: `flutter test --no-pub`
- Result: `406 passed, 2 skipped, 23 failed`
- Common exception: `Asset 'shaders/ink_sparkle.frag' does not contain appropriate runtime stage data for current backend (SkSL). Found stages: Vulkan.`
- Common first framework frame: `FragmentProgram._fromAsset` (`dart:ui/painting.dart:5415`)
- Interpretation: failures occur while Flutter initializes `InkSparkle`, before each test reaches its product assertion. The compiled shader contains a Vulkan stage but the Windows widget-test renderer requires SkSL.

| # | Test file | Test name | Classification | Shader failure / assertion reached / first relevant frame |
|---:|---|---|---|---|
| 1 | `test/account_status_onboarding_route_test.dart` | post-auth account status enters the four-step server-authoritative flow | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 2 | `test/application_detail_screen_test.dart` | loads the status timeline only when it is first expanded | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 3 | `test/bootstrap_and_button_test.dart` | startup failure renders an honest retry action | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 4 | `test/date_of_birth_field_test.dart` | partial input does not validate as complete | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 5 | `test/compact_onboarding_test.dart` | compact onboarding exposes exactly four primary production steps | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 6 | `test/legal_document_navigation_test.dart` | legal document action returns to its invoking route | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 7 | `test/job_and_safety_widget_test.dart` | TeenJobFeedScreen shows clear filters when empty results and filters are active | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 8 | `test/legal_clickwrap_stability_test.dart` | consent form edits do not refetch the exact legal version | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 9 | `test/messaging_completion_test.dart` | conversation list renders context, searches, and paginates | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 10 | `test/mort_liquid_glass_test.dart` | glass navigation is accessible and responsive at large text | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 11 | `test/mort_back_navigation_test.dart` | Safety legal references return to the invoking onboarding step | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 12 | `test/precise_location_gate_test.dart` | shows the required card and offers Open settings for approximate-only | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 13 | `test/quick_accept_button_test.dart` | AVAILABLE -> CLAIMING -> ACCEPTED never shows success before the server confirms | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 14 | `test/proof_review_screen_performance_test.dart` | rebuilds do not request duplicate signed proof URLs | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 15 | `test/role_dashboard_test.dart` | Adult dashboard groups real work, account, and safety routes | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 16 | `test/safety_circle_lifecycle_test.dart` | leaving Safety Circle during invite acceptance is safe | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 17 | `test/screen_security_widget_test.dart` | widget disposal releases protection | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 18 | `test/shared_motion_and_sheet_test.dart` | confirmation sheets protect the bottom safe area | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 19 | `test/settings_experience_test.dart` | Settings groups controls and opens working accessibility | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 20 | `test/support_chat_widget_test.dart` | leaving a support case during send does not update disposed UI | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 21 | `test/teen_shell_navigation_test.dart` | Teen shell preserves branch state and gives visible and system Back parity | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 22 | `test/support_assistant_widget_test.dart` | shows typing then renders answer and citation | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |
| 23 | `test/unified_auth_screen_test.dart` | unified auth switches modes without losing entered email | DESKTOP_INK_SPARKLE_BACKEND | Common shader exception and `FragmentProgram._fromAsset`. |

## Shared-harness finding

The suite has no existing `test/flutter_test_config.dart` or common app harness. Many failures use Flutter's default Material 3 theme, while a subset injects `MortTheme.dark()`, which explicitly selects `InkSparkle.splashFactory`. A shared test-only configuration must therefore cover both paths without changing production theme behavior.

## Root-cause validation and remediation

- Each of the 23 baseline cases was rerun independently after the test-only remediation; all 23 now pass.
- `test/helpers/mort_widget_test.dart` centralizes the scoped Windows `TargetPlatformVariant` and the `mortTestTheme` adapter, which preserves MORT visual tokens while setting only `InkRipple.splashFactory`.
- `MortBootstrap` has a `@visibleForTesting` theme seam for its nested startup-failure `MaterialApp`. Its production default remains exactly `MortTheme.dark()`; the test supplies `mortTestTheme(MortTheme.dark())`.
- The V6 haptics fixture no longer forces `useMaterial3: false`; it uses the shared test harness instead.
- One exploratory run of the screen-security test failed with a missing native call under a simulated Windows platform. Classification: `TEST_STATE_LEAK` from altered platform semantics, not a product failure. That test now retains its original platform and uses only `mortTestTheme(ThemeData())`; it passes.
- `REPRODUCES_ALONE=YES` for all 23 initially inventoried shader failures. The first remediation full run exposed 18 sibling interactions with the same shader exception; each was individually reproduced and resolved through the same test-only harness/theme path.
- Final full-suite verification: `passed=429`, `skipped=2`, `failed=0`, `exit_code=0`, `InkSparkle exceptions=0`.
