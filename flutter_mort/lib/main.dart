import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app.dart';
import 'core/observability/crash_reporting.dart';
import 'core/observability/sentry_crash_provider.dart';
import 'core/observability/structured_log.dart';
import 'core/observability/product_analytics.dart';
import 'core/theme/mort_theme.dart';
import 'core/widgets/mort_widgets.dart';
import 'data/services/supabase_service.dart';
import 'core/config/app_config.dart';
import 'features/ads/data/ad_consent_service.dart';
import 'features/qa/browserstack_qa_app.dart';
import 'services/push/push_notification_coordinator.dart';
import 'services/push/remote_push_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 15+ (targetSdk 35+, which MORT uses) enforces edge-to-edge
  // display regardless of app preference -- content draws behind system
  // bars whether or not the app asks for it. Keep this before the
  // BrowserStack QA early return so real-device QA exercises the same window
  // inset/system-bar mode as the normal app.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  if (AppConfig.browserStackQaMode) {
    _runApp();
    return;
  }
  configureRemotePushBackgroundHandler();
  if (MortSentryCrashProvider.canInitialize) {
    try {
      await MortSentryCrashProvider.run(_runApp);
      return;
    } catch (_) {
      MortStructuredLog.instance.record(
        'mort.crash_provider_initialization_failed',
        level: MortLogLevel.error,
        attributes: const {'provider': 'sentry', 'outcome': 'failed'},
      );
    }
  }
  _runAppWithFallbackHandlers();
}

void _runApp() {
  runApp(const ProviderScope(child: MortBootstrap()));
}

void _runAppWithFallbackHandlers() {
  final reporter = MortCrashReporting.instance;
  final priorFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      reporter.record(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: false,
        context: 'flutter_framework',
      ),
    );
    (priorFlutterHandler ?? FlutterError.presentError)(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      reporter.record(
        error,
        stackTrace,
        fatal: true,
        context: 'platform_dispatcher',
      ),
    );
    return reporter.providerConfigured;
  };
  runZonedGuarded(_runApp, (error, stackTrace) {
    unawaited(
      reporter.record(error, stackTrace, fatal: true, context: 'root_zone'),
    );
    if (!reporter.providerConfigured) {
      FlutterError.presentError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
  });
}

class MortBootstrap extends StatefulWidget {
  const MortBootstrap({
    super.key,
    this.initialize,
    this.maintenanceMode,
    this.currentAppVersion,
  });

  final Future<void> Function()? initialize;

  /// Test/preview override for [AppConfig.maintenanceMode].
  final bool? maintenanceMode;

  /// Test/preview override for the running app version used by the
  /// mandatory-update gate. Null defers to PackageInfo at runtime.
  final String? currentAppVersion;

  @override
  State<MortBootstrap> createState() => _MortBootstrapState();
}

class _MortBootstrapState extends State<MortBootstrap> {
  late Future<Object?> _initialization;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    // Maintenance mode is a fail-closed terminal state: no backend calls,
    // no initialization work until the flag is lifted at build time.
    if (widget.maintenanceMode ?? AppConfig.maintenanceMode) {
      return;
    }
    _initialization = _initializeAfterFirstFrame();
  }

  Future<Object?> _initializeAfterFirstFrame() async {
    await WidgetsBinding.instance.endOfFrame;
    return _initializeSafely();
  }

  Future<Object?> _initializeSafely() async {
    try {
      // BrowserStack QA still validates its fail-closed internal-test contract.
      // The QA branch returns before hosted/provider initialization, but it must
      // never bypass checks that keep production systems disabled.
      AppConfig.assertValidReleaseConfiguration();
      if (AppConfig.browserStackQaMode) {
        return null;
      }
      await AppConfig.assertSupportedAppVersion(
        currentVersion: widget.currentAppVersion,
      );
      if (AppConfig.crashReportingEnabled &&
          !MortCrashReporting.instance.providerConfigured) {
        throw StateError('The configured crash provider is unavailable.');
      }
      await (widget.initialize ?? SupabaseService.initializeIfConfigured)();
      await MortProductAnalytics.instance.initialize();
      await PushNotificationCoordinator.instance.initialize();
      if (AppConfig.supportsNativeAds && AppConfig.adsEnabled) {
        // Ads are optional to the product -- a consent or SDK init failure
        // here must never block sign-in, jobs, safety, or any other core
        // flow. AdMobService's own per-request checks already fail closed
        // if this never completes.
        unawaited(_initializeAdsBestEffort());
      }
      return null;
    } catch (error) {
      unawaited(
        MortCrashReporting.instance.record(
          error,
          StackTrace.current,
          fatal: false,
          context: 'startup',
        ),
      );
      return error;
    }
  }

  Future<void> _initializeAdsBestEffort() async {
    try {
      await const AdConsentService().ensureConsent();
      await MobileAds.instance.initialize();
    } catch (error) {
      MortStructuredLog.instance.record(
        'mort.ads.startup_init_failed',
        level: MortLogLevel.warning,
        attributes: {'error': error.toString()},
      );
    }
  }

  void _retry() {
    setState(() {
      _start();
    });
  }

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(AppConfig.playStoreListingUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      MortStructuredLog.instance.record(
        'mort.startup.store_link_failed',
        level: MortLogLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.maintenanceMode ?? AppConfig.maintenanceMode) {
      return MaterialApp(
        title: 'MORT',
        debugShowCheckedModeBanner: false,
        theme: MortTheme.dark(),
        home: MortScreen(
          children: [
            const MortHeader(
              eyebrow: 'Earn nearby. Move smart.',
              title: 'MORT',
              subtitle: 'Brief maintenance',
            ),
            const MortErrorState(
              title: 'MORT is briefly offline',
              message:
                  'We are making MORT better right now. Please check back again shortly.',
            ),
            const SizedBox(height: 16),
            MortButton(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: _retry,
            ),
          ],
        ),
      );
    }
    return FutureBuilder<Object?>(
      future: _initialization,
      builder: (context, snapshot) {
        final failed =
            snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null;
        if (snapshot.connectionState == ConnectionState.done && !failed) {
          if (AppConfig.browserStackQaMode) {
            return const BrowserStackQaApp();
          }
          return const MortApp();
        }
        final error = snapshot.data;
        final updateRequired = error is AppUpdateRequiredException
            ? error
            : null;
        final configFailure = error is AppConfigValidationException;

        return MaterialApp(
          title: 'MORT',
          debugShowCheckedModeBanner: false,
          theme: MortTheme.dark(),
          home: MortScreen(
            children: [
              const MortHeader(
                eyebrow: 'Earn nearby. Move smart.',
                title: 'MORT',
                subtitle: 'Connecting securely...',
              ),
              if (updateRequired != null) ...[
                MortErrorState(
                  title: 'MORT needs an update',
                  message:
                      'You are using version ${updateRequired.currentVersion}. '
                      'Update to the latest version of MORT to keep '
                      'earning safely.',
                ),
                const SizedBox(height: 16),
                MortButton(
                  label: 'Update MORT',
                  icon: Icons.system_update_alt,
                  onPressed: _openPlayStore,
                ),
                const SizedBox(height: 8),
                MortButton(
                  label: 'Retry startup',
                  icon: Icons.refresh,
                  onPressed: _retry,
                ),
              ] else if (failed) ...[
                MortErrorState(
                  title: 'MORT could not start',
                  message: configFailure
                      ? 'MORT could not finish its secure setup on this '
                            'device. Check the app store for an update, then '
                            'try again. No private key is required in the app.'
                      : 'Check your connection and try again. No private key '
                            'is required in the app.',
                ),
                const SizedBox(height: 16),
                MortButton(
                  label: 'Retry startup',
                  icon: Icons.refresh,
                  onPressed: _retry,
                ),
              ] else
                const MortLoading(
                  label: 'Restoring your session...',
                  fullScreen: false,
                ),
            ],
          ),
        );
      },
    );
  }
}
