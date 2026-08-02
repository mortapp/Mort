import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';
import 'crash_reporting.dart';

class MortSentryCrashProvider {
  MortSentryCrashProvider._();

  static bool get canInitialize =>
      AppConfig.crashReportingEnabled && AppConfig.isSentryConfigured;

  static Future<void> run(void Function() appRunner) async {
    final package = await PackageInfo.fromPlatform();
    final release =
        '${package.packageName}@${package.version}+${package.buildNumber}';
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = AppConfig.sentryDsn
          ..environment = AppConfig.releaseStage
          ..release = release
          ..dist = package.buildNumber
          ..sendDefaultPii = false
          ..attachStacktrace = true
          ..attachThreads = false
          ..enableAutoSessionTracking = true
          ..enableNativeCrashHandling = true
          ..enableAutoNativeBreadcrumbs = false
          ..enableAppLifecycleBreadcrumbs = false
          ..enableUserInteractionBreadcrumbs = false
          ..enablePrintBreadcrumbs = false
          ..recordHttpBreadcrumbs = false
          ..captureFailedRequests = false
          ..attachScreenshot = false
          ..enableUserInteractionTracing = false
          ..enableAutoPerformanceTracing = false
          ..enableAppHangTracking = false
          ..enableFramesTracking = false
          ..enableLogs = false
          ..enableMetrics = false
          ..tracesSampleRate = 0
          ..maxBreadcrumbs = 50
          ..beforeSend = sanitizeEvent;
      },
      appRunner: () {
        MortCrashReporting.instance.configure(
          sink: capture,
          breadcrumbSink: addBreadcrumb,
          providerName: 'sentry',
        );
        appRunner();
      },
    );
  }

  static Future<void> capture(
    CrashEnvelope envelope,
    StackTrace stackTrace,
  ) async {
    await Sentry.captureException(
      _SanitizedCrash(envelope.category),
      stackTrace: stackTrace,
      withScope: (scope) async {
        await scope.setTag('mort_category', envelope.category);
        await scope.setTag('mort_context', envelope.context);
        await scope.setTag('mort_correlation_id', envelope.correlationId);
        await scope.setTag('mort_fatal', envelope.fatal.toString());
        scope.fingerprint = [envelope.category, envelope.context];
        scope.level = envelope.fatal ? SentryLevel.fatal : SentryLevel.error;
      },
    );
  }

  static Future<void> addBreadcrumb(SafeBreadcrumb breadcrumb) {
    return Sentry.addBreadcrumb(
      Breadcrumb(
        category: breadcrumb.event,
        level: _sentryLevel(breadcrumb.level),
        timestamp: breadcrumb.occurredAt,
        data: breadcrumb.attributes,
      ),
    );
  }

  static SentryEvent sanitizeEvent(SentryEvent event, Hint hint) {
    final safeExceptions = event.exceptions
        ?.map(
          (exception) => SentryException(
            type: _safeType(exception.type),
            value: '[details redacted]',
            stackTrace: exception.stackTrace,
            mechanism: exception.mechanism,
            threadId: exception.threadId,
          ),
        )
        .toList(growable: false);
    final category =
        event.tags?['mort_category'] ??
        (safeExceptions?.isNotEmpty == true
            ? safeExceptions!.first.type
            : 'unknown_error');
    final context = _safeContextTag(event.tags?['mort_context']);
    final fatal =
        event.tags?['mort_fatal'] == 'true' || event.level == SentryLevel.fatal;
    final correlationId =
        event.tags?['mort_correlation_id'] ?? event.eventId.toString();
    return SentryEvent(
      eventId: event.eventId,
      timestamp: event.timestamp,
      platform: event.platform,
      release: event.release,
      dist: event.dist,
      environment: event.environment,
      level: fatal ? SentryLevel.fatal : (event.level ?? SentryLevel.error),
      modules: event.modules,
      sdk: event.sdk,
      debugMeta: event.debugMeta,
      exceptions: safeExceptions,
      fingerprint: [category ?? 'unknown_error', context],
      tags: {
        'mort_category': category ?? 'unknown_error',
        'mort_context': context,
        'mort_correlation_id': correlationId,
        'mort_fatal': fatal.toString(),
        'release_stage': AppConfig.releaseStage,
      },
      breadcrumbs: event.breadcrumbs
          ?.where((item) => item.category?.startsWith('mort.') == true)
          .map(
            (item) => Breadcrumb(
              category: item.category,
              level: item.level,
              timestamp: item.timestamp,
              data: _safeBreadcrumbData(item.data),
            ),
          )
          .toList(growable: false),
    );
  }

  static Map<String, dynamic>? _safeBreadcrumbData(
    Map<String, dynamic>? input,
  ) {
    if (input == null) return null;
    const allowed = {
      'code',
      'feature',
      'network_status',
      'operation',
      'outcome',
      'platform',
      'provider',
      'release_stage',
      'status',
    };
    return {
      for (final entry in input.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
  }

  static String _safeType(String? value) {
    final normalized =
        value?.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_') ?? '';
    return normalized.isEmpty || normalized.length > 80
        ? 'unknown_error'
        : normalized;
  }

  static String _safeContextTag(String? value) {
    const allowed = {
      'flutter_framework',
      'platform_dispatcher',
      'root_zone',
      'startup',
      'repository_operation',
      'background_operation',
      'unspecified',
    };
    return allowed.contains(value) ? value! : 'unspecified';
  }

  static SentryLevel _sentryLevel(String level) => switch (level) {
    'debug' => SentryLevel.debug,
    'warning' => SentryLevel.warning,
    'error' => SentryLevel.error,
    'critical' => SentryLevel.fatal,
    _ => SentryLevel.info,
  };
}

class _SanitizedCrash implements Exception {
  const _SanitizedCrash(this.category);

  final String category;

  @override
  String toString() => category;
}
