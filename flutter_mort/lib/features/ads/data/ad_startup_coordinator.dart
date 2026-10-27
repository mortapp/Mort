import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/auth/auth_startup.dart';
import '../../../core/observability/structured_log.dart';
import 'ad_consent_service.dart';

enum AdStartupResult { ready, timedOut, failed }

class AdStartupCoordinator {
  AdStartupCoordinator({
    required Future<void> Function() ensureConsent,
    required Future<void> Function() initializeMobileAds,
    this.timeout = defaultTimeout,
  }) : _ensureConsent = ensureConsent,
       _initializeMobileAds = initializeMobileAds {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }
  }

  static const defaultTimeout = Duration(seconds: 5);

  final Future<void> Function() _ensureConsent;
  final Future<void> Function() _initializeMobileAds;
  final Duration timeout;

  Future<AdStartupResult>? _initialization;

  Future<AdStartupResult> initialize() {
    return _initialization ??= _initializeWithDeadline();
  }

  Future<AdStartupResult> _initializeWithDeadline() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _ensureConsent().timeout(_remaining(stopwatch));
      await _initializeMobileAds().timeout(_remaining(stopwatch));
      return AdStartupResult.ready;
    } on TimeoutException {
      _recordOutcome('timed_out');
      return AdStartupResult.timedOut;
    } catch (_) {
      _recordOutcome('failed');
      return AdStartupResult.failed;
    }
  }

  Duration _remaining(Stopwatch stopwatch) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Ad startup exceeded its deadline.', timeout);
    }
    return remaining;
  }

  void _recordOutcome(String outcome) {
    MortStructuredLog.instance.record(
      'mort.ads.startup_init_incomplete',
      level: MortLogLevel.warning,
      attributes: {'provider': 'google_mobile_ads', 'outcome': outcome},
    );
  }
}

final adStartupCoordinatorProvider = Provider<AdStartupCoordinator>((ref) {
  return AdStartupCoordinator(
    ensureConsent: () => const AdConsentService().ensureConsent(
      underAgeOfConsent:
          ref.read(authStartupSnapshotProvider).underAgeOfConsent ?? true,
    ),
    initializeMobileAds: () async {
      await MobileAds.instance.initialize();
    },
  );
});

final adStartupStateProvider = FutureProvider<AdStartupResult>((ref) {
  return ref.read(adStartupCoordinatorProvider).initialize();
});

Future<void> initializeAdsSafely(WidgetRef ref) async {
  await ref.read(adStartupStateProvider.future);
}
