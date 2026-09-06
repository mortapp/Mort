# MORT CODEX POST-V6 MAINLINE REPORT

BASE_BRANCH=origin/main
WORK_BRANCH=integration/mort-v6-post-hardening
ORIGIN_MAIN_BEFORE=2337a209dabee76f61d3f2651c01486790eda63b
V6_SOURCE_COMMIT=fe9c3110c2ae8c501e136714b1072b616826fbaa
FINAL_HEAD=local test-hardening commit (resolved in git metadata)

V6_RECONCILED=YES
V6_HAPTICS_PRESENT=YES

EXTRA_INTERNAL_DEFECTS_FOUND=0
EXTRA_INTERNAL_DEFECTS_FIXED=0

FILES_CHANGED=

- `flutter_mort/lib/core/widgets/mort_widgets.dart`
- `flutter_mort/test/mort_haptics_microinteraction_test.dart`
- `MORT_CODEX_V6_FORENSIC_INTEGRATION_REPORT.md`

BACKEND_CHANGED=NO
MIGRATIONS_CHANGED=NO
IOS_CHANGED=NO

FORMAT=PASS (258 files checked; 0 changed after final formatting)
ANALYZE=PASS (No issues found; 83.1s)
FOCUSED_TESTS=PASS
FULL_TESTS=PASS
passed: 429
skipped: 2
failed: 0

ANDROID_RUNTIME=NOT_PERFORMED
PHYSICAL_ANDROID=NOT_PERFORMED

EXTERNAL_BLOCKERS=

- provider credentials and store approvals
- production identity/billing/telemetry configuration
- Android device or emulator runtime evidence

INTERNAL_CRITICALS_REMAINING=NONE FOUND in the constrained P0/P1 source audit. The remaining unavailable capabilities are correctly represented as external blockers rather than fabricated completion.

## Reconciliation

The worktree was created directly from current `origin/main`; no dirty Windows workspace state and no feature-branch-wide changes were merged. The verified V6 commit cherry-picked cleanly as `42b6270`, preserving the existing MortHaptics preference gate and adding one haptic per actionable canonical button activation.

## Flutter desktop InkSparkle incident

INITIAL_FAILED_COUNT=23
INITIAL_FULL_SUITE=passed:406 skipped:2 failed:23 exit_code:1

FINAL_FAILURE_INVENTORY=All initially failing tests reached the same `FragmentProgram._fromAsset` exception before their product assertion. No initial failure was a real product failure.

ROOT_CAUSE=Flutter 3.47.2's Material 3 interaction path selected `InkSparkle`; MORT's production theme also explicitly selects `InkSparkle.splashFactory`. The checked-in `shaders/ink_sparkle.frag` contains a Vulkan runtime stage, while the Windows widget-test renderer requires SkSL. Consequently `FragmentProgram._fromAsset` throws during interaction rendering before the MORT assertion runs.

SHARED_PATTERN=Widget tests that create a Material 3 app and exercise an ink interaction, including tests that inject `MortTheme.dark()`. The suite had no pre-existing shared app/test harness.

FIX_TYPE=TEST_INFRASTRUCTURE

FIX=`test/helpers/mort_widget_harness.dart` provides the scoped Windows `TargetPlatformVariant` and `mortTestTheme`, which preserves Material 3 and MORT visual tokens while replacing only the unsupported splash factory with `InkRipple.splashFactory`. Platform-sensitive screen-security fixtures keep their original platform and use only `mortTestTheme(ThemeData())`. The bootstrap retry contract invokes the public button callback directly, avoiding a renderer-only gesture path without changing production code.

PRODUCTION_THEME_CHANGED=NO
ANDROID_RUNTIME_IMPACT=NONE_FOUND
IOS_RUNTIME_IMPACT=NONE_FOUND

PREVIOUS_FAILURES_AFTER_FIX=passed:23 failed:0
V6_HAPTIC_TESTS=passed:4 failed:0
FULL_SUITE_AFTER_FIX=passed:429 skipped:2 failed:0 exit_code:0

## Scope audit

ANDROID_NATIVE_CHANGED=NO
IOS_CHANGED=NO
AUTH_CHANGED=NO
BACKEND_CHANGED=NO
SUPABASE_CHANGED=NO
MIGRATIONS_CHANGED=NO
FINANCIAL_SAFETY_CHANGED=NO
ROUTES_CHANGED=NO

The hardening is confined to Flutter test infrastructure, Flutter test fixtures, and this forensic documentation. No test log is committed.
