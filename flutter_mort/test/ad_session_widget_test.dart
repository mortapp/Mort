import 'dart:async';
import 'dart:collection';

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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _adChannelName = 'plugins.flutter.io/google_mobile_ads';
const _eligibleEntitlements = <String, dynamic>{
  'ad_free_active': false,
  'premium_active': false,
};

class _FakeMonetizationRepository extends MonetizationRepository {
  Map<String, dynamic>? entitlements = Map.of(_eligibleEntitlements);
  Object? entitlementError;
  Completer<Map<String, dynamic>>? entitlementCompleter;
  Map<String, dynamic> eligibility = {
    'allowed': true,
    'reason': 'Eligible.',
    'request_non_personalized': true,
  };
  final eligibilityCompleters = Queue<Completer<Map<String, dynamic>>>();
  int eligibilityCalls = 0;
  int impressionCalls = 0;

  @override
  Future<Map<String, dynamic>> getMyEntitlements() {
    final completer = entitlementCompleter;
    if (completer != null) return completer.future;
    final error = entitlementError;
    if (error != null) return Future.error(error);
    return Future.value(entitlements ?? const <String, dynamic>{});
  }

  @override
  Future<Map<String, dynamic>> adEligibility(String placement, String format) {
    eligibilityCalls++;
    if (eligibilityCompleters.isNotEmpty) {
      return eligibilityCompleters.removeFirst().future;
    }
    return Future.value(eligibility);
  }

  @override
  Future<void> recordAdImpression({
    required String placement,
    required String format,
    String? adUnitId,
    bool requestNonPersonalized = true,
  }) async {
    impressionCalls++;
  }
}

class _AdHarness {
  _AdHarness(this.tester, {required this.repository, required this.identity}) {
    authEvents = StreamController<AuthState>.broadcast(sync: true);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        monetizationRepositoryProvider.overrideWithValue(repository),
        adStartupStateProvider.overrideWith(
          (ref) async => AdStartupResult.ready,
        ),
        adSessionIdentityReaderProvider.overrideWith(
          (ref) =>
              () => identity,
        ),
        authStateProvider.overrideWith((ref) => authEvents.stream),
      ],
    );
  }

  final WidgetTester tester;
  final _FakeMonetizationRepository repository;
  AdSessionIdentity? identity;
  late final StreamController<AuthState> authEvents;
  late final ProviderContainer container;

  Future<void> primeEntitlements() async {
    await container.read(backendEntitlementsProvider.future);
  }

  Future<void> pumpBanner({String placement = 'job_feed'}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: MortBannerAd(placement: placement)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpRewarded({VoidCallback? onReward}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: MortNativeRewardedAdButton(
              placement: 'profile_spark',
              label: 'Watch for Spark',
              onReward: onReward,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  void accountSwitch() {
    identity = _identity(userId: 'user-b', accessToken: 'token-b');
    authEvents.add(const AuthState(AuthChangeEvent.signedIn, null));
  }

  void tokenRefresh() {
    identity = _identity(accessToken: 'token-refreshed');
    authEvents.add(const AuthState(AuthChangeEvent.tokenRefreshed, null));
  }

  Future<void> dispose() async {
    container.dispose();
    await authEvents.close();
  }
}

AdSessionIdentity _identity({
  String userId = 'user-a',
  String accessToken = 'token-a',
  DateTime? expiresAt,
}) {
  return AdSessionIdentity(
    userId: userId,
    accessToken: accessToken,
    expiresAt:
        expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 10)),
  );
}

List<MethodCall> _nativeCalls = <MethodCall>[];

List<MethodCall> _callsFor(String method) =>
    _nativeCalls.where((call) => call.method == method).toList();

Future<void> _sendAdEvent(
  WidgetTester tester,
  int adId,
  String eventName, {
  Map<String, dynamic> additionalArguments = const {},
}) async {
  final arguments = <String, dynamic>{
    'adId': adId,
    'eventName': eventName,
    ...additionalArguments,
  };
  final data = instanceManager.channel.codec.encodeMethodCall(
    MethodCall('onAdEvent', arguments),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _adChannelName,
    data,
    (_) {},
  );
}

int _loadedAdId(String method) {
  final arguments = _callsFor(method).single.arguments as Map;
  return arguments['adId'] as int;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testsEnabled = AppConfig.adsEnabled && AppConfig.useTestAds;

  setUp(() {
    _nativeCalls = <MethodCall>[];
    instanceManager = AdInstanceManager(_adChannelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, (call) async {
          _nativeCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, null);
  });

  testWidgets('account switch during eligibility prevents a banner request', (
    tester,
  ) async {
    final originalRequest = Completer<Map<String, dynamic>>();
    final switchedRequest = Completer<Map<String, dynamic>>();
    final repository = _FakeMonetizationRepository()
      ..eligibilityCompleters.addAll([originalRequest, switchedRequest]);
    final harness = _AdHarness(
      tester,
      repository: repository,
      identity: _identity(),
    );
    addTearDown(harness.dispose);
    await harness.primeEntitlements();
    await harness.pumpBanner();

    expect(repository.eligibilityCalls, 1);
    harness.accountSwitch();
    await tester.pump();
    await tester.pump();
    expect(repository.eligibilityCalls, 2);
    originalRequest.complete(repository.eligibility);
    await tester.pump();

    expect(_callsFor('loadBannerAd'), isEmpty);
    switchedRequest.complete(repository.eligibility);
    await tester.pump();
    await tester.pump();

    expect(_callsFor('loadBannerAd'), hasLength(1));
    expect(repository.impressionCalls, 0);
  }, skip: !testsEnabled);

  testWidgets('signed-out sessions cannot request banner or rewarded ads', (
    tester,
  ) async {
    final bannerRepository = _FakeMonetizationRepository();
    final bannerHarness = _AdHarness(
      tester,
      repository: bannerRepository,
      identity: null,
    );
    addTearDown(bannerHarness.dispose);
    await bannerHarness.primeEntitlements();
    await bannerHarness.pumpBanner();

    expect(bannerRepository.eligibilityCalls, 0);
    expect(_callsFor('loadBannerAd'), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    final rewardedRepository = _FakeMonetizationRepository();
    final rewardedHarness = _AdHarness(
      tester,
      repository: rewardedRepository,
      identity: null,
    );
    addTearDown(rewardedHarness.dispose);
    await rewardedHarness.primeEntitlements();
    await rewardedHarness.pumpRewarded();

    expect(rewardedRepository.eligibilityCalls, 0);
    expect(_callsFor('loadRewardedAd'), isEmpty);
  }, skip: !testsEnabled);

  testWidgets(
    'token replacement during rewarded eligibility prevents native loading',
    (tester) async {
      final eligibilityRequest = Completer<Map<String, dynamic>>();
      final repository = _FakeMonetizationRepository()
        ..eligibilityCompleters.add(eligibilityRequest);
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpRewarded();

      harness.identity = _identity(accessToken: 'new-access-token');
      eligibilityRequest.complete(repository.eligibility);
      await tester.pump();
      await tester.pump();

      expect(_callsFor('loadRewardedAd'), isEmpty);
      expect(repository.impressionCalls, 0);
    },
    skip: !testsEnabled,
  );

  testWidgets(
    'expired session during eligibility prevents a rewarded request',
    (tester) async {
      final expiry = DateTime.now().toUtc().add(const Duration(seconds: 1));
      final eligibilityRequest = Completer<Map<String, dynamic>>();
      final repository = _FakeMonetizationRepository()
        ..eligibilityCompleters.add(eligibilityRequest);
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(expiresAt: expiry),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpRewarded();

      harness.identity = _identity(expiresAt: DateTime.now().toUtc());
      eligibilityRequest.complete(repository.eligibility);
      await tester.pump();
      await tester.pump();

      expect(_callsFor('loadRewardedAd'), isEmpty);
      expect(repository.impressionCalls, 0);
    },
    skip: !testsEnabled,
  );

  testWidgets(
    'unknown, loading, failed, and malformed entitlements do not request ads',
    (tester) async {
      final loadingRepository = _FakeMonetizationRepository()
        ..entitlementCompleter = Completer<Map<String, dynamic>>();
      final loadingHarness = _AdHarness(
        tester,
        repository: loadingRepository,
        identity: _identity(),
      );
      addTearDown(loadingHarness.dispose);

      await loadingHarness.container.read(adStartupStateProvider.future);
      await loadingHarness.pumpBanner();
      expect(loadingRepository.eligibilityCalls, 0);
      expect(_callsFor('loadBannerAd'), isEmpty);

      loadingRepository.entitlementCompleter!.complete(_eligibleEntitlements);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(loadingRepository.eligibilityCalls, 1);
      expect(_callsFor('loadBannerAd'), hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      final failedRepository = _FakeMonetizationRepository()
        ..entitlementError = const FormatException('malformed entitlements');
      final failedHarness = _AdHarness(
        tester,
        repository: failedRepository,
        identity: _identity(),
      );
      addTearDown(failedHarness.dispose);
      await failedHarness.pumpBanner();
      expect(failedRepository.eligibilityCalls, 0);
      expect(_callsFor('loadBannerAd'), hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      final malformedRepository = _FakeMonetizationRepository()
        ..entitlements = {'ad_free_active': false};
      final malformedHarness = _AdHarness(
        tester,
        repository: malformedRepository,
        identity: _identity(),
      );
      addTearDown(malformedHarness.dispose);
      await malformedHarness.primeEntitlements();
      await malformedHarness.pumpRewarded();
      expect(malformedRepository.eligibilityCalls, 0);
      expect(_callsFor('loadRewardedAd'), isEmpty);
    },
    skip: !testsEnabled,
  );

  testWidgets('denied server eligibility never starts a native ad request', (
    tester,
  ) async {
    final repository = _FakeMonetizationRepository()
      ..eligibility = {
        'allowed': false,
        'reason': 'Consent and ad preferences are not ready.',
        'request_non_personalized': true,
      };
    final harness = _AdHarness(
      tester,
      repository: repository,
      identity: _identity(),
    );
    addTearDown(harness.dispose);
    await harness.primeEntitlements();
    await harness.pumpBanner();

    expect(repository.eligibilityCalls, 1);
    expect(_callsFor('loadBannerAd'), isEmpty);
  }, skip: !testsEnabled);

  testWidgets(
    'ad-free entitlement change disposes a cached banner and blocks reload',
    (tester) async {
      final repository = _FakeMonetizationRepository();
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpBanner();

      final adId = _loadedAdId('loadBannerAd');
      await _sendAdEvent(tester, adId, 'onAdLoaded');
      await tester.pump();
      expect(find.byType(AdWidget), findsOneWidget);

      repository.entitlements = {
        'ad_free_active': true,
        'premium_active': false,
      };
      harness.container.invalidate(backendEntitlementsProvider);
      await tester.pump();
      await tester.pump();

      expect(_callsFor('disposeAd'), hasLength(1));
      expect(_callsFor('loadBannerAd'), hasLength(1));
      expect(find.byType(AdWidget), findsNothing);
    },
    skip: !testsEnabled,
  );

  testWidgets('premium entitlement change revokes cached rewarded ad', (
    tester,
  ) async {
    final repository = _FakeMonetizationRepository();
    final harness = _AdHarness(
      tester,
      repository: repository,
      identity: _identity(),
    );
    addTearDown(harness.dispose);
    await harness.primeEntitlements();
    await harness.pumpRewarded();

    final adId = _loadedAdId('loadRewardedAd');
    await _sendAdEvent(tester, adId, 'onAdLoaded');
    await tester.pump();
    expect(find.text('Watch for Spark'), findsOneWidget);

    repository.entitlements = {'ad_free_active': false, 'premium_active': true};
    harness.container.invalidate(backendEntitlementsProvider);
    await tester.pump();
    await tester.pump();

    expect(_callsFor('disposeAd'), hasLength(1));
    expect(find.textContaining('Unavailable'), findsOneWidget);
  }, skip: !testsEnabled);

  testWidgets(
    'late native banner callback after disposal cannot record an impression',
    (tester) async {
      final repository = _FakeMonetizationRepository();
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpBanner();
      final adId = _loadedAdId('loadBannerAd');

      await tester.pumpWidget(const SizedBox.shrink());
      await _sendAdEvent(tester, adId, 'onAdLoaded');
      await tester.pump();

      expect(repository.impressionCalls, 0);
      expect(tester.takeException(), isNull);
    },
    skip: !testsEnabled,
  );

  testWidgets(
    'late rewarded callback after disposal cannot grant reward or impression',
    (tester) async {
      var rewards = 0;
      final repository = _FakeMonetizationRepository();
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpRewarded(onReward: () => rewards++);
      final adId = _loadedAdId('loadRewardedAd');
      await _sendAdEvent(tester, adId, 'onAdLoaded');
      await tester.pump();
      await tester.tap(find.text('Watch for Spark'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await _sendAdEvent(
        tester,
        adId,
        'onRewardedAdUserEarnedReward',
        additionalArguments: {'rewardItem': RewardItem(1, 'Spark')},
      );

      expect(rewards, 0);
      expect(repository.impressionCalls, 0);
      expect(tester.takeException(), isNull);
    },
    skip: !testsEnabled,
  );

  testWidgets(
    'reward callback after account switch cannot grant reward or impression',
    (tester) async {
      var rewards = 0;
      final repository = _FakeMonetizationRepository();
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpRewarded(onReward: () => rewards++);
      final adId = _loadedAdId('loadRewardedAd');
      await _sendAdEvent(tester, adId, 'onAdLoaded');
      await tester.pump();
      await tester.tap(find.text('Watch for Spark'));
      await tester.pump();
      expect(_callsFor('showAdWithoutView'), hasLength(1));

      harness.identity = _identity(userId: 'user-b', accessToken: 'token-b');
      await _sendAdEvent(
        tester,
        adId,
        'onRewardedAdUserEarnedReward',
        additionalArguments: {'rewardItem': RewardItem(1, 'Spark')},
      );

      expect(rewards, 0);
      expect(repository.impressionCalls, 0);
    },
    skip: !testsEnabled,
  );

  testWidgets(
    'banner records an impression only after the native impression event',
    (tester) async {
      final repository = _FakeMonetizationRepository();
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpBanner();
      final adId = _loadedAdId('loadBannerAd');

      await _sendAdEvent(tester, adId, 'onAdLoaded');
      await tester.pump();
      expect(repository.impressionCalls, 0);

      await _sendAdEvent(tester, adId, 'onAdImpression');
      await tester.pump();
      expect(repository.impressionCalls, 1);
    },
    skip: !testsEnabled,
  );

  testWidgets(
    'rewarded impression is counted on display, independent of completion',
    (tester) async {
      final repository = _FakeMonetizationRepository();
      var rewards = 0;
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpRewarded(onReward: () => rewards++);
      final adId = _loadedAdId('loadRewardedAd');
      await _sendAdEvent(tester, adId, 'onAdLoaded');
      await tester.pump();
      await tester.tap(find.text('Watch for Spark'));
      await tester.pump();
      expect(repository.impressionCalls, 0);

      await _sendAdEvent(tester, adId, 'onAdImpression');
      await tester.pump();
      expect(repository.impressionCalls, 1);

      expect(rewards, 0);
    },
    skip: !testsEnabled,
  );

  testWidgets(
    'repeated rewarded taps during loading and showing start only one ad',
    (tester) async {
      final eligibilityRequest = Completer<Map<String, dynamic>>();
      final repository = _FakeMonetizationRepository()
        ..eligibilityCompleters.add(eligibilityRequest);
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpRewarded();

      await tester.tap(find.textContaining('Loading...'));
      await tester.tap(find.textContaining('Loading...'));
      expect(repository.eligibilityCalls, 1);
      expect(_callsFor('loadRewardedAd'), isEmpty);

      eligibilityRequest.complete(repository.eligibility);
      await tester.pump();
      await tester.pump();
      final adId = _loadedAdId('loadRewardedAd');
      await _sendAdEvent(tester, adId, 'onAdLoaded');
      await tester.pump();

      await tester.tap(find.text('Watch for Spark'));
      await tester.pump();
      await tester.tap(find.textContaining('Ad playing'));
      expect(_callsFor('showAdWithoutView'), hasLength(1));
    },
    skip: !testsEnabled,
  );

  testWidgets(
    'session transition disposes and reloads a cached banner for new account',
    (tester) async {
      final repository = _FakeMonetizationRepository();
      final harness = _AdHarness(
        tester,
        repository: repository,
        identity: _identity(),
      );
      addTearDown(harness.dispose);
      await harness.primeEntitlements();
      await harness.pumpBanner();
      final oldAdId = _loadedAdId('loadBannerAd');
      await _sendAdEvent(tester, oldAdId, 'onAdLoaded');
      await _sendAdEvent(tester, oldAdId, 'onAdImpression');
      await tester.pump();

      harness.accountSwitch();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(_callsFor('disposeAd'), hasLength(1));
      expect(_callsFor('loadBannerAd'), hasLength(2));
      expect(repository.impressionCalls, 1);
    },
    skip: !testsEnabled,
  );
}
