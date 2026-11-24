# MORT Ad Startup Integration Proposal

**Date:** 2026-10-25  
**Branch:** `feature/compact-onboarding-and-screen-polish`  
**HEAD:** `b3e4bdf354116c05add4f99c1db2f58c15a1daf0`  
**Scope:** Inspection and proposal only. No source integration was applied.

## Files inspected

- `flutter_mort/lib/main.dart`
- `flutter_mort/lib/app.dart`
- `flutter_mort/lib/core/auth/auth_startup.dart`
- `flutter_mort/lib/core/widgets/auth_startup_gate.dart`
- `flutter_mort/lib/features/ads/data/ad_startup_coordinator.dart`
- `flutter_mort/lib/features/ads/data/ad_consent_service.dart`
- `flutter_mort/lib/features/ads/widgets/mort_banner_ad.dart`
- `flutter_mort/lib/features/ads/widgets/mort_rewarded_ad_button.dart`
- `flutter_mort/test/ad_startup_integration_test.dart`
- `flutter_mort/test/ad_session_widget_test.dart`
- `flutter_mort/test/ad_startup_coordinator_test.dart`

## Current startup flow and integration point

`MortBootstrap._initializeSafely()` initializes Supabase, analytics, and push, then currently starts its own consent/SDK initialization with `unawaited(_initializeAdsBestEffort())`. This happens before `MortApp` creates `authStartupProvider` and before `AuthStartupController` resolves the restored session and verifies the profile.

Auth restoration and profile bootstrap actually complete downstream in `AuthStartupController`; successful verification produces `MortAuthStartupStage.authenticated` and a server-derived destination. Therefore `main.dart` cannot correctly trigger ads immediately after its Supabase initializer and still satisfy “after core auth bootstrap.” The appropriate trigger is a `Consumer` around `MortApp` at the successful bootstrap branch, watching `authStartupProvider`. The existing main-level fire-and-forget initializer should be removed to avoid duplicate consent/SDK initialization.

## Proposed patch — `flutter_mort/lib/main.dart` only

This is a draft, **not applied**. It removes the early duplicate initializer and kicks off the coordinator only after the restored-session/profile bootstrap reaches its authenticated state. The application future remains unawaited; auth restoration, route rendering, and the core bootstrap are not delayed.

```diff
diff --git a/flutter_mort/lib/main.dart b/flutter_mort/lib/main.dart
--- a/flutter_mort/lib/main.dart
+++ b/flutter_mort/lib/main.dart
@@
 import 'package:flutter/services.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
-import 'package:google_mobile_ads/google_mobile_ads.dart';
 import 'package:url_launcher/url_launcher.dart';
@@
 import 'core/observability/product_analytics.dart';
 import 'core/theme/mort_theme.dart';
 import 'core/widgets/mort_widgets.dart';
 import 'data/services/supabase_service.dart';
 import 'core/config/app_config.dart';
-import 'features/ads/data/ad_consent_service.dart';
+import 'core/auth/auth_startup.dart';
+import 'features/ads/data/ad_startup_coordinator.dart';
 import 'services/push/push_notification_coordinator.dart';
@@
 class _MortBootstrapState extends State<MortBootstrap> {
   late Future<Object?> _initialization;
+  bool _adsStartupQueued = false;
@@
         final failed =
             snapshot.connectionState == ConnectionState.done &&
             snapshot.data != null;
         if (snapshot.connectionState == ConnectionState.done && !failed) {
-          return const MortApp();
+          return Consumer(
+            builder: (context, ref, _) {
+              ref.listen<AuthStartupController>(
+                authStartupProvider,
+                (previous, authStartup) {
+                  final authSnapshot = authStartup.snapshot;
+                  if (_adsStartupQueued ||
+                      authSnapshot.stage !=
+                          MortAuthStartupStage.authenticated ||
+                      authSnapshot.userId == null) {
+                    return;
+                  }
+                  _adsStartupQueued = true;
+                  WidgetsBinding.instance.addPostFrameCallback((_) {
+                    if (!context.mounted) return;
+                    unawaited(
+                      AdStartupCoordinator.initializeAdsSafely(ref),
+                    );
+                  });
+                },
+                fireImmediately: true,
+              );
+              return const MortApp();
+            },
+          );
         }
@@
-      if (AppConfig.supportsNativeAds && AppConfig.adsEnabled) {
-        // Ads are optional to the product -- a consent or SDK init failure
-        // here must never block sign-in, jobs, safety, or any other core
-        // flow. AdMobService's own per-request checks already fail closed
-        // if this never completes.
-        unawaited(_initializeAdsBestEffort());
-      }
       return null;
@@
-  Future<void> _initializeAdsBestEffort() async {
-    try {
-      await const AdConsentService().ensureConsent();
-      await MobileAds.instance.initialize();
-    } catch (error) {
-      MortStructuredLog.instance.record(
-        'mort.ads.startup_init_failed',
-        level: MortLogLevel.warning,
-        attributes: {'error': error.toString()},
-      );
-    }
-  }
```

The draft call assumes adding this small wrapper to `ad_startup_coordinator.dart`; it starts/awaits `adStartupStateProvider.future` and returns `Future<void>`, so `unawaited` makes the non-blocking intent explicit. This wrapper is not present in the current coordinator implementation.

```diff
diff --git a/flutter_mort/lib/features/ads/data/ad_startup_coordinator.dart b/flutter_mort/lib/features/ads/data/ad_startup_coordinator.dart
--- a/flutter_mort/lib/features/ads/data/ad_startup_coordinator.dart
+++ b/flutter_mort/lib/features/ads/data/ad_startup_coordinator.dart
@@
 class AdStartupCoordinator {
+  static Future<void> initializeAdsSafely(WidgetRef ref) async {
+    await ref.read(adStartupStateProvider.future);
+  }
+
   AdStartupCoordinator({
```

This wrapper alone does not close the teen-specific UMP configuration blocker below; coordinator/provider changes must first make the verified age/role available to `ensureConsent`.

## Integration blockers before applying

1. **Teen-specific consent configuration:** `AdConsentService.ensureConsent` accepts `underAgeOfConsent`, but the current coordinator invokes it with the default `false`. `MortAuthStartupSnapshot` exposes a destination string rather than a typed/verified role. Do not apply this draft as written until the coordinator handoff carries the server-confirmed teen/adult status into UMP consent initialization. Non-personalized ad-request settings alone do not prove the UMP under-age flag was set.
2. **Eligibility state ownership:** the current `adStartupStateProvider` is a cached `FutureProvider`; the proposed one-shot wrapper must share that same provider/coordinator instance with both widgets, and any retry semantics after timeout/failure need an explicit decision. The existing coordinator is single-flight and returns a terminal result.
3. **“Authenticated” scope:** this draft intentionally does not initialize ads for signed-out, offline, fatal-configuration, onboarding, suspended, or deletion-pending snapshots. Confirm whether the product wants any of those states to initialize UMP; do not widen this gate implicitly.

Until those contracts are resolved and tested, keep `APP-ADS-STARTUP-02` open. This proposal does not claim the startup integration is complete or production-safe.

## Verification

Requested command, from `flutter_mort`:

```text
flutter test test\ad_startup_integration_test.dart test\ad_session_widget_test.dart test\ad_startup_coordinator_test.dart --dart-define=ADS_ENABLED=true --dart-define=USE_TEST_ADS=true --reporter expanded
```

- **Exit code:** 0
- **Result:** 25 passed, 0 failed.
- The exact command invoked dependency resolution and downloaded packages. It was then rerun without dependency resolution:

```text
flutter test --no-pub test\ad_startup_integration_test.dart test\ad_session_widget_test.dart test\ad_startup_coordinator_test.dart --dart-define=ADS_ENABLED=true --dart-define=USE_TEST_ADS=true --reporter expanded
```

- **Exit code:** 0
- **Result:** 25 passed, 0 failed.

```text
git diff --check
```

- **Exit code:** 0. Git printed pre-existing line-ending conversion warnings for unrelated dirty files; no whitespace errors were reported.

Tests use intercepted local platform channels and fakes; no live advertising provider was called. The focused suite does not validate the real UMP/native SDK or hosted server behavior.

## Worktree preservation

- `flutter_mort/lib/main.dart` already had unrelated modifications at inspection time. This task did not edit it.
- `flutter_mort/pubspec.lock` was already dirty at inspection time. This task did not edit it directly. The first requested `flutter test` invocation performed dependency resolution; the no-pub rerun passed. The pre-existing lockfile diff was not reset or otherwise altered.
- The worktree has other unrelated dirty and untracked files; they were preserved.