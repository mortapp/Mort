import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../data/services/supabase_service.dart';
import '../config/app_config.dart';
import 'structured_log.dart';

class MortOperationalTelemetry {
  MortOperationalTelemetry._();

  static const _uuid = Uuid();
  static const _eventTypes = {
    'api_failure',
    'auth_failure',
    'job_transition_failure',
    'pin_failure',
    'message_delivery_failure',
    'support_escalation',
    'deletion_failure',
    'storage_failure',
  };
  static PackageInfo? _packageInfo;

  static Future<void> recordFailure({
    required String eventType,
    required String safeCode,
  }) async {
    final type = _eventTypes.contains(eventType) ? eventType : 'api_failure';
    final code = _safeCode(safeCode);
    MortStructuredLog.instance.record(
      'mort.operational_failure',
      level: MortLogLevel.warning,
      attributes: {'operation': type, 'code': code, 'outcome': 'failed'},
    );
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }
    try {
      final package = _packageInfo ??= await PackageInfo.fromPlatform();
      await SupabaseService.client.rpc(
        'record_my_client_operational_event',
        params: {
          'p_event_type': type,
          'p_safe_code': code,
          'p_correlation_id': _uuid.v4(),
          'p_platform': _platformName(),
          'p_app_version': '${package.version}+${package.buildNumber}',
          'p_release_stage': AppConfig.releaseStage,
          'p_client_request_id': _uuid.v4(),
        },
      );
    } catch (_) {
      MortStructuredLog.instance.record(
        'mort.operational_telemetry_unavailable',
        level: MortLogLevel.warning,
        attributes: {'operation': type, 'outcome': 'failed'},
      );
    }
  }

  static String _safeCode(String value) {
    final normalized = value.toLowerCase().trim().replaceAll(
      RegExp('[^a-z0-9_.-]'),
      '_',
    );
    return RegExp(r'^[a-z][a-z0-9_.-]{2,79}$').hasMatch(normalized)
        ? normalized
        : 'unknown_failure';
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }
}
