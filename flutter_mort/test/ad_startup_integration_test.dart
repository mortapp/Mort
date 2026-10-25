import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_mort/data/repositories/monetization_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/ads/data/ad_session_identity.dart';
import 'package:flutter_mort/features/ads/data/ad_startup_coordinator.dart';
import 'package:flutter_mort/features/ads/widgets/mort_banner_ad.dart';
import 'package:flutter_mort/features/ads/widgets/mort_rewarded_ad_button.dart';
import 'package:flutter_mort/features/monetization/providers/revenuecat_providers.dart';
import 'package:flutter_mort/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';

const _adChannelName = 'plugins.flutter.io/google_mobile_ads';
const _umpChannelName = 'plugins.flutter.io/google_mobile_ads/ump';
final _testsEnabled = AppConfig.adsEnabled && AppConfig.useTestAds;

class _FakeMonetizationRepository extends MonetizationRepository {
  int eligibilityCalls = 0;

  @override
  Future<Map<String, dynamic>> adEligibility(
    String placement,
    String format,
  ) async {
    eligibilityCalls++;
    return const {
      'allowed': true,
      'reason': 'Eligible.',
      'request_non_personalized': true,
    };
  }

  @override
  Future<void> recordAdImpression({
    required String placement,
    required String format,
    String? adUnitId,
    bool requestNonPersonalized = true,
  }) async {}
}

final List<MethodCall> _nativeCalls = [];

List<MethodCall> _callsFor(String method) =>
    _nativeCalls.where((call) => call.method == method).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _nativeCalls.clear();
    instanceManager = AdInstanceManager(_adChannelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, (call) async {
          _nativeCalls.add(call);
          if (call.method == 'MobileAds#initialize') {
            return InitializationStatus({});
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, null);
  });

  testWidgets(
    'banner and rewarded ad requests wait for consent and SDK readiness',
    (tester) async {
      final consent = Completer<void>();
      final sdk = Completer<void>();
      final order = <String>[];
      final repository = _FakeMonetizationRepository();
      final coordinator = AdStartupCoordinator(
        ensureConsent: () async {
          order.add('consent');
          await consent.future;
        },
        initializeMobileAds: () async {
          order.add('sdk');
          await sdk.future;
        },
      );
      final testIdentity = AdSessionIdentity(
        userId: 'test-user',
        accessToken: 'test-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          monetizationRepositoryProvider.overrideWithValue(repository),
          adStartupCoordinatorProvider.overrideWithValue(coordinator),
          adSessionIdentityReaderProvider.overrideWith(
            (ref) =>
                () => testIdentity,
          ),
          backendEntitlementsProvider.overrideWith(
            (ref) async => const {
              'ad_free_active': false,
              'premium_active': false,
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(backendEntitlementsProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  MortBannerAd(placement: 'job_feed'),
                  MortNativeRewardedAdButton(
                    placement: 'profile_spark',
                    label: 'Watch for Spark',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(order, ['consent']);
      expect(repository.eligibilityCalls, 0);
      expect(_callsFor('loadBannerAd'), isEmpty);
      expect(_callsFor('loadRewardedAd'), isEmpty);

      consent.complete();
      await tester.pump();
      await tester.pump();
      expect(order, ['consent', 'sdk']);
      expect(repository.eligibilityCalls, 0);
      expect(_callsFor('loadBannerAd'), isEmpty);
      expect(_callsFor('loadRewardedAd'), isEmpty);

      sdk.complete();
      expect(
        await container.read(adStartupStateProvider.future),
        AdStartupResult.ready,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(repository.eligibilityCalls, 2);
      expect(_callsFor('loadBannerAd'), hasLength(1));
      expect(_callsFor('loadRewardedAd'), hasLength(1));
    },
    skip: !_testsEnabled,
  );

  testWidgets('app bootstrap does not start an independent ad-consent flow', (
    tester,
  ) async {
    var consentInfoRequests = 0;
    final umpChannel = MethodChannel(
      _umpChannelName,
      StandardMethodCodec(UserMessagingCodec()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(umpChannel, (call) async {
          if (call.method == 'ConsentInformation#requestConsentInfoUpdate') {
            consentInfoRequests++;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(umpChannel, null),
    );

    await tester.pumpWidget(
      ProviderScope(child: MortBootstrap(initialize: () async {})),
    );
    await tester.pumpAndSettle();

    expect(consentInfoRequests, 0);
    expect(_callsFor('MobileAds#initialize'), isEmpty);
  }, skip: !_testsEnabled);
}
