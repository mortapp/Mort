# MORT Physical QA Rendering Remediation

## Scope

Bounded repair for the Android physical-device rendering error:

```text
[ERROR:flutter/flow/layers/transform_layer.cc(15)]
TransformLayer is constructed with an invalid matrix.
```

Predictive back itself is not reopened in this pass. The physical retest log shows `OnBackInvokedCallbackInfo` active and no old `OnBackInvokedCallback is not enabled for the application` warning.

## Evidence

Input log:

```text
C:\Users\micha\Mort\artifacts\physical-qa-rendering-fix\retest\rendering-retest-logcat.txt
```

Failure:

```text
08-02 13:17:15.571 D/CoreBackPreview( 1502): Window{33bf6d8 u0 com.mortapp.mobile/com.mortapp.mobile.MainActivity}: Setting back callback OnBackInvokedCallbackInfo{..., mPriority=0, mIsAnimationCallback=true}
08-02 13:17:15.574 E/flutter (16830): [ERROR:flutter/flow/layers/transform_layer.cc(15)] TransformLayer is constructed with an invalid matrix.
08-02 13:17:15.574 E/flutter (16830): [ERROR:flutter/flow/layers/transform_layer.cc(15)] TransformLayer is constructed with an invalid matrix.
```

First physical retest status: **FAILED**. The configured APK containing commit `7b57126605e76df90ee03b9841fef90f601e751a` still emitted the invalid-matrix error twice at `2026-08-02 13:17:15.574`.

No screen-recording media file was present under `artifacts\physical-qa-rendering-fix`. The log shows the failure immediately after a tap delivered to `com.mortapp.mobile` and Android registering Flutter's animated back/page callback after the Chrome OAuth flow.

## Root Cause

The remaining invalid matrix was not from `MortAnimatedBrandMark`.

The app's `ThemeData` did not override Android page transitions, so Android inherited Flutter's default `PredictiveBackPageTransitionsBuilder`. In Flutter `3.41.2`, that builder uses the Material zoom transition path, including `_ZoomEnterTransitionPainter` and `_ZoomExitTransitionPainter`, each pushing a `TransformLayer` from a `Matrix4`. The two Flutter engine errors occurred together at the same moment Android activated the animated back/page callback, matching the two transform-producing zoom transition painters.

Affected route sequence:

```text
Chrome OAuth return / auth callback -> /account-status route transition
```

Affected widget/source:

```text
Flutter Material default Android page transition
PredictiveBackPageTransitionsBuilder -> zoom transition painters -> TransformLayer
```

Invalid value observed:

```text
The Flutter engine reported an invalid matrix from the transform layer during the Android predictive route transition. The app log did not expose matrix element values, but SDK inspection confirmed the active default transition path builds Matrix4 transform layers; MORT-owned transform widgets on the journey were finite-guarded and the duplicate error matched the SDK enter/exit transition pair.
```

## Repair

MORT now owns Android page transitions and avoids the SDK transform-based zoom transition for in-app routes.

Changed behavior:

```text
TargetPlatform.android -> MortFiniteFadePageTransitionsBuilder
```

The new transition uses opacity only and clamps route animation values to a finite `0..1` range. It does not create a page-transition `TransformLayer`.

## Changed Files

```text
C:\Users\micha\Mort\flutter_mort\lib\core\routing\mort_page_transitions.dart
C:\Users\micha\Mort\flutter_mort\lib\core\theme\mort_theme.dart
C:\Users\micha\Mort\flutter_mort\test\physical_rendering_regression_test.dart
C:\Users\micha\Mort\docs\codex\MORT_PHYSICAL_QA_RENDERING_REMEDIATION.md
```

## Tests Added

Added a focused widget regression in:

```text
C:\Users\micha\Mort\flutter_mort\test\physical_rendering_regression_test.dart
```

Coverage:

```text
Samsung SM-A146U physical resolution profile
Repeated route push to /account-status
Android system-back pop via handlePopRoute
Finite transform assertions for all remaining Transform widgets
Finite clamping assertions for NaN, infinity, negative infinity, below-range, and above-range animation values
```

## Commands And Exit Codes

```text
dart format lib\core\routing\mort_page_transitions.dart lib\core\theme\mort_theme.dart test\physical_rendering_regression_test.dart
Exit code: 0
Result: Formatted 3 files (1 changed).

flutter analyze --no-pub
Exit code: 0
Result: No issues found. Ran in 136.7s.

flutter test --no-pub test\physical_rendering_regression_test.dart test\android_native_parity_test.dart
Exit code: 0
Result: All tests passed.

.\scripts\build-standard-closed-test-apk.ps1
Exit code: 0
Result: Created verified closed_test APK.
```

## Second Repair APK

```text
C:\Users\micha\Mort\artifacts\physical-qa-rendering-fix\second-repair\mort-closed-test-0.9.13-second-rendering-repair.apk
```

Current metadata:

```text
Package: com.mortapp.mobile
Version: 0.9.13+103
Target SDK: 36
Min SDK: 24
Signing: protected upload-signing certificate, signed=True
Size: 68301502 bytes
SHA-256: FBA7CE65575BB4A2F7F7E8DE365FC33971DC75DB42D73B0E04AC043E590C60F6
```

## Physical Retest

Second physical Samsung retest: **not done in this pass**.

Do not mark this rendering defect fixed until the second-repair APK is installed on the physical Samsung SM-A146U and the same OAuth/account-status journey produces zero invalid-matrix errors in logcat.

## 0.9.14+104 Final-Pass Status

The finite opacity transition repair remains in the signed `0.9.14+104` runtime
source. Focused rendering tests, the full Flutter suite, API 36 native
integration, and an exact signed-APK cold launch pass. The cold-launch fatal-log
scan did not emit an invalid-matrix error, but it did not exercise the OAuth
callback/account-status transition.

The final attempt to reconnect the remembered Samsung wireless-debugging
endpoint was actively refused. No pairing, unlock, credential, clipboard, or
biometric action was attempted. The required physical OAuth/account-status
retest therefore remains **not done**, and this report does not mark the defect
physically cleared.
