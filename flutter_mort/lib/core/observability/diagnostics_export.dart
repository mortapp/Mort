import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import 'crash_reporting.dart';
import 'structured_log.dart';

class MortDiagnosticsExport {
  MortDiagnosticsExport._();

  static Future<Map<String, Object>> snapshot() async {
    final package = await PackageInfo.fromPlatform();
    final connectivity = await Connectivity().checkConnectivity();
    final recent = MortStructuredLog.instance.recent
        .toList(growable: false)
        .reversed
        .take(20)
        .toList(growable: false)
        .reversed
        .map((item) => item.toSafeMap())
        .toList(growable: false);
    return {
      'schema': 'mort-safe-diagnostics-v1',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'app': {
        'name': AppConfig.appName,
        'version': package.version,
        'build': package.buildNumber,
        'release_stage': AppConfig.releaseStage,
      },
      'runtime': {
        'platform': _platformName(),
        'network_status': _networkStatus(connectivity),
        'crash_provider': MortCrashReporting.instance.providerName,
      },
      'feature_flags': AppConfig.safeReleaseDiagnostics,
      'recent_safe_events': recent,
      'excluded': [
        'credentials',
        'session_data',
        'user_content',
        'location',
        'pins',
        'payment_data',
        'identity_evidence',
      ],
    };
  }

  static Future<String> json() async {
    return const JsonEncoder.withIndent('  ').convert(await snapshot());
  }

  static String _networkStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'offline';
    }
    if (results.contains(ConnectivityResult.wifi)) return 'wifi';
    if (results.contains(ConnectivityResult.mobile)) return 'mobile';
    if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
    return 'connected';
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'other',
    };
  }
}
