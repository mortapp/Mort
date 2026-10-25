import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'features/qa/browserstack_qa_app.dart';
import 'services/push/push_notification_coordinator.dart';
import 'services/push/remote_push_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.browserStackQaMode) {
    _runApp();
    return;
  }
  // Android 15+ (targetSdk 35+, which MORT uses) enforces edge-to-edge
  // display regardless of app preference -- content draws behind system
  // bars whether or not the app asks for it. Without explicitly opting
  // in here, Flutter's own inset plumbing can end up mismatched with
  // what the OS is already doing, which is exactly what caused a real,
  // physically-confirmed bug: the Welcome screen's second button
  // ("I already have an account") rendered behind the system navigation
  // bar with SafeArea reporting zero bottom inset. This call keeps
  // Flutter's MediaQuery.viewPadding/SafeArea calculations in sync with
  // the OS's actual (mandatory) edge-to-edge behavior.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
  final bool? maintenanceMode;
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
    if (widget.maintenanceMode ?? AppConfig.maintenanceMode) return;
    _initialization = _initializeAfterFirstFrame();
  }

  Future<Object?> _initializeAfterFirstFrame() async {
    await WidgetsBinding.instance.endOfFrame;
    return _initializeSafely();
  }

  Future<Object?> _initializeSafely() async {
    try {
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

  void _retry() {
    setState(() {
      _start();
    });
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
        final updateRequired = snapshot.data is AppUpdateRequiredException;
        if (snapshot.connectionState == ConnectionState.done && !failed) {
          if (AppConfig.browserStackQaMode) {
            return const BrowserStackQaApp();
          }
          return const MortApp();
        }

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
              if (failed) ...[
                MortErrorState(
                  title: updateRequired
                      ? 'MORT needs an update'
                      : 'MORT could not start',
                  message: updateRequired
                      ? 'This version is no longer supported. Install the latest version to continue.'
                      : 'Check your connection and try again. No private key is required in the app.',
                ),
                const SizedBox(height: 16),
                if (updateRequired)
                  MortButton(
                    label: 'Update MORT',
                    icon: Icons.system_update_alt,
                    onPressed: () => launchUrl(
                      Uri.parse(AppConfig.playStoreListingUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  )
                else
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
