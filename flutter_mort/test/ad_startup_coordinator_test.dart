import 'dart:async';

import 'package:flutter_mort/features/ads/data/ad_startup_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a five-second default deadline', () {
    expect(AdStartupCoordinator.defaultTimeout, const Duration(seconds: 5));
  });

  test(
    'initializes consent before ads and shares concurrent startup work',
    () async {
      final order = <String>[];
      final consent = Completer<void>();
      final coordinator = AdStartupCoordinator(
        ensureConsent: () async {
          order.add('consent');
          await consent.future;
        },
        initializeMobileAds: () async {
          order.add('mobile_ads');
        },
      );

      final first = coordinator.initialize();
      final second = coordinator.initialize();
      expect(second, same(first));
      expect(order, ['consent']);

      consent.complete();
      expect(await first, AdStartupResult.ready);
      expect(order, ['consent', 'mobile_ads']);
    },
  );

  test(
    'consent timeout does not start mobile ads after consent eventually ends',
    () async {
      final consent = Completer<void>();
      var mobileAdsStarted = false;
      final coordinator = AdStartupCoordinator(
        ensureConsent: () => consent.future,
        initializeMobileAds: () async => mobileAdsStarted = true,
        timeout: const Duration(milliseconds: 20),
      );

      expect(await coordinator.initialize(), AdStartupResult.timedOut);
      consent.complete();
      await Future<void>.delayed(Duration.zero);
      expect(mobileAdsStarted, isFalse);
    },
  );

  test(
    'mobile ads initialization is covered by the remaining deadline',
    () async {
      final mobileAds = Completer<void>();
      final coordinator = AdStartupCoordinator(
        ensureConsent: () async {},
        initializeMobileAds: () => mobileAds.future,
        timeout: const Duration(milliseconds: 20),
      );

      expect(await coordinator.initialize(), AdStartupResult.timedOut);
      mobileAds.complete();
    },
  );

  test(
    'consent failures fail closed without initializing mobile ads',
    () async {
      var mobileAdsStarted = false;
      final coordinator = AdStartupCoordinator(
        ensureConsent: () => Future<void>.error(StateError('consent failed')),
        initializeMobileAds: () async => mobileAdsStarted = true,
      );

      expect(await coordinator.initialize(), AdStartupResult.failed);
      expect(mobileAdsStarted, isFalse);
    },
  );

  test('rejects a non-positive timeout', () {
    expect(
      () => AdStartupCoordinator(
        ensureConsent: () async {},
        initializeMobileAds: () async {},
        timeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
