import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/observability_repository.dart';
import '../../data/services/supabase_service.dart';
import '../config/app_config.dart';
import 'structured_log.dart';

class MortProductAnalytics {
  MortProductAnalytics._();

  static final MortProductAnalytics instance = MortProductAnalytics._();
  static const _uuid = Uuid();

  final ObservabilityRepository _repository = ObservabilityRepository();
  StreamSubscription<AuthState>? _authSubscription;
  PackageInfo? _packageInfo;
  bool _initialized = false;
  bool _optedIn = false;

  bool get buildEnabled => AppConfig.productAnalyticsEnabled;
  bool get optedIn => _optedIn;

  Future<void> initialize() async {
    if (_initialized || !SupabaseService.isConfigured) return;
    _initialized = true;
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.userUpdated) {
        unawaited(refreshConsent());
      } else if (state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.userDeleted) {
        _optedIn = false;
      }
    });
    await refreshConsent();
  }

  Future<bool> refreshConsent() async {
    if (!buildEnabled || SupabaseService.client.auth.currentUser == null) {
      _optedIn = false;
      return false;
    }
    try {
      _optedIn =
          (await _repository.analyticsPreference()).productAnalyticsOptIn;
    } catch (_) {
      _optedIn = false;
    }
    return _optedIn;
  }

  Future<bool> setConsent(bool optIn) async {
    if (!buildEnabled || SupabaseService.client.auth.currentUser == null) {
      _optedIn = false;
      return false;
    }
    final preference = await _repository.updateAnalyticsPreference(optIn);
    _optedIn = preference.productAnalyticsOptIn;
    MortStructuredLog.instance.record(
      'mort.analytics_consent_changed',
      attributes: {
        'feature': 'product_analytics',
        'status': _optedIn ? 'enabled' : 'disabled',
      },
    );
    return _optedIn;
  }

  Future<void> recordScreenPath(String path) async {
    await record(
      eventName: 'screen_view',
      surface: surfaceForPath(path),
      outcome: 'opened',
    );
  }

  Future<void> record({
    required String eventName,
    required String surface,
    required String outcome,
  }) async {
    if (!buildEnabled || !_optedIn) return;
    if (SupabaseService.client.auth.currentUser == null) return;
    try {
      final package = _packageInfo ??= await PackageInfo.fromPlatform();
      await _repository.recordProductEvent(
        eventName: eventName,
        surface: surface,
        outcome: outcome,
        platform: _platformName(),
        appVersion: '${package.version}+${package.buildNumber}',
        releaseStage: AppConfig.releaseStage,
        clientRequestId: _uuid.v4(),
      );
    } catch (_) {
      MortStructuredLog.instance.record(
        'mort.analytics_delivery_failed',
        level: MortLogLevel.warning,
        attributes: const {'feature': 'product_analytics', 'outcome': 'failed'},
      );
    }
  }

  @visibleForTesting
  String surfaceForPath(String path) {
    final segment = Uri.tryParse(path)?.pathSegments.firstOrNull ?? '';
    return switch (segment) {
      'auth' => 'auth',
      'onboarding' => 'onboarding',
      'teen' || 'adult' || 'guardian' => 'home',
      'jobs' || 'job' => 'jobs',
      'applications' => 'applications',
      'messages' => 'messages',
      'safety' => 'safety',
      'support' => 'support',
      'notifications' => 'notifications',
      'settings' => 'settings',
      'profile' => 'profile',
      'admin' => 'admin',
      'legal' => 'legal',
      _ => 'unknown',
    };
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    _initialized = false;
    _optedIn = false;
    _packageInfo = null;
  }
}
