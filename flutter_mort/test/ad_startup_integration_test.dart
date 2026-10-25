import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_mort/core/auth/auth_startup.dart';
import 'package:flutter_mort/main.dart';
import 'package:flutter_mort/data/repositories/monetization_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/ads/data/ad_session_identity.dart';
import 'package:flutter_mort/features/ads/data/ad_startup_coordinator.dart';
import 'package:flutter_mort/features/ads/widgets/mort_banner_ad.dart';
import 'package:flutter_mort/features/ads/widgets/mort_rewarded_ad_button.dart';
import 'package:flutter_mort/features/monetization/providers/revenuecat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _adChannelName = 'plugins.flutter.io/google_mobile_ads';
const _umpChannelName = 'plugins.flutter.io/google_mobile_ads/ump';
final _testsEnabled = AppConfig.adsEnabled && AppConfig.useTestAds;
const _eligibleEntitlements = <String, dynamic>{
  'ad_free_active': false,
  'premium_active': false,
};

class _FakeMonetizationRepository extends MonetizationRepository {
  _FakeMonetizationRepository(this.eligibility, {this.currentUserId});

  final Map<String, dynamic> eligibility;
  final String? Function()? currentUserId;
  int eligibilityCalls = 0;
  final eligibilityUserIds = <String?>[];

  @override
  Future<Map<String, dynamic>> getMyEntitlements() async =>
      Map.of(_eligibleEntitlements);

  @override
  Future<Map<String, dynamic>> adEligibility(String placement, String format) {
    eligibilityCalls++;
    eligibilityUserIds.add(currentUserId?.call());
    return Future.value(eligibility);
  }

  @override
  Future<void> recordAdImpression({
    required String placement,
    required String format,
    String? adUnitId,
    bool requestNonPersonalized = true,
  }) async {}
}

class _StartupHarness {
  _StartupHarness({
    required this.tester,
    required this.repository,
    required this.coordinator,
    required this.identityReader,
  }) {
    authEvents = StreamController<AuthState>.broadcast(sync: true);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        monetizationRepositoryProvider.overrideWithValue(repository),
        adSessionIdentityReaderProvider.overrideWith((ref) => identityReader),
        adStartupCoordinatorProvider.overrideWithValue(coordinator),
        authStateProvider.overrideWith((ref) => authEvents.stream),
      ],
    );
  }

  final WidgetTester tester;
  final _FakeMonetizationRepository repository;
  final AdStartupCoordinator coordinator;
  final AdSessionIdentity? Function() identityReader;
  late final StreamController<AuthState> authEvents;
  late final ProviderContainer container;

  Future<void> pumpAds() async {
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
  }

  Future<void> dispose() async {
    container.dispose();
    await authEvents.close();
  }
}

AdSessionIdentity _activeIdentity({String userId = 'user-a'}) {
  return AdSessionIdentity(
    userId: userId,
    accessToken: 'token-$userId',
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
  );
}

List<MethodCall> _nativeCalls = <MethodCall>[];

List<MethodCall> _callsFor(String method) =>
    _nativeCalls.where((call) => call.method == method).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _nativeCalls = <MethodCall>[];
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
    'consent and SDK readiness gate both widgets until startup completes',
    (tester) async {
      final order = <String>[];
      final consent = Completer<void>();
      final sdk = Completer<void>();
      final identity = _activeIdentity();
      final harness = _StartupHarness(
        tester: tester,
        repository: _FakeMonetizationRepository({
          'allowed': true,
          'reason': 'Eligible.',
          'request_non_personalized': true,
        }),
        coordinator: AdStartupCoordinator(
          ensureConsent: () async {
            order.add('consent');
            await consent.future;
          },
          initializeMobileAds: () async {
            order.add('sdk');
            await sdk.future;
          },
        ),
        identityReader: () => identity,
      );
      addTearDown(harness.dispose);

      await harness.pumpAds();
      expect(order, ['consent']);
      expect(harness.repository.eligibilityCalls, 0);
      expect(_callsFor('loadBannerAd'), isEmpty);
      expect(_callsFor('loadRewardedAd'), isEmpty);
      expect(find.textContaining('Preparing ads...'), findsOneWidget);

      consent.complete();
      await tester.pump();
      await tester.pump();
      expect(order, ['consent', 'sdk']);
      expect(harness.repository.eligibilityCalls, 0);
      expect(_callsFor('loadBannerAd'), isEmpty);
      expect(_callsFor('loadRewardedAd'), isEmpty);

      sdk.complete();
      expect(
        await harness.container.read(adStartupStateProvider.future),
        AdStartupResult.ready,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(harness.repository.eligibilityCalls, 2);
      expect(_callsFor('loadBannerAd'), hasLength(1));
      expect(_callsFor('loadRewardedAd'), hasLength(1));
      expect(
        (_callsFor('loadBannerAd').single.arguments as Map)['request']
            .nonPersonalizedAds,
        isTrue,
      );
    },
    skip: !_testsEnabled,
  );

  testWidgets(
    'app bootstrap does not start a second ad-consent flow outside the request gate',
    (tester) async {
      var consentInfoRequests = 0;
      final umpChannel = MethodChannel(
        _umpChannelName,
        StandardMethodCodec(UserMessagingCodec()),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(umpChannel, (call) async {
            switch (call.method) {
              case 'ConsentInformation#requestConsentInfoUpdate':
                consentInfoRequests++;
                return null;
              case 'ConsentInformation#isConsentFormAvailable':
                return false;
              default:
                throw PlatformException(
                  code: 'unexpected_ump_call',
                  message: call.method,
                );
            }
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
    },
    skip: !_testsEnabled,
  );

  testWidgets(
    'verified teen and adult roles set the UMP under-age consent parameter',
    (tester) async {
      final umpRequests = <ConsentRequestParameters>[];
      final umpChannel = MethodChannel(
        _umpChannelName,
        StandardMethodCodec(UserMessagingCodec()),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(umpChannel, (call) async {
            switch (call.method) {
              case 'ConsentInformation#requestConsentInfoUpdate':
                final arguments = call.arguments as Map;
                umpRequests.add(
                  arguments['params'] as ConsentRequestParameters,
                );
                return null;
              case 'ConsentInformation#isConsentFormAvailable':
                return false;
              default:
                throw PlatformException(
                  code: 'unexpected_ump_call',
                  message: call.method,
                );
            }
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(umpChannel, null),
      );

      for (final scenario in [
        (role: 'teen', underAgeOfConsent: true),
        (role: 'adult', underAgeOfConsent: false),
      ]) {
        final snapshot = routeAuthenticatedProfile(
          userId: 'user-a',
          profile: {
            'id': 'user-a',
            'role': scenario.role,
            'account_status': 'active',
            'onboarding_completed': true,
          },
        );
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [authStartupSnapshotProvider.overrideWithValue(snapshot)],
        );

        expect(
          await container.read(adStartupStateProvider.future),
          AdStartupResult.ready,
        );
        expect(
          umpRequests.last.tagForUnderAgeOfConsent,
          scenario.underAgeOfConsent,
          reason: '${scenario.role} UMP consent request',
        );
        container.dispose();
      }

      expect(umpRequests, hasLength(2));
    },
    skip: !_testsEnabled,
  );

  testWidgets('consent timeout exposes fallback without blocking the app', (
    tester,
  ) async {
    final consent = Completer<void>();
    var sdkStarted = false;
    final harness = _StartupHarness(
      tester: tester,
      repository: _FakeMonetizationRepository({
        'allowed': true,
        'reason': 'Eligible.',
        'request_non_personalized': true,
      }),
      coordinator: AdStartupCoordinator(
        ensureConsent: () => consent.future,
        initializeMobileAds: () async => sdkStarted = true,
      ),
      identityReader: _activeIdentity,
    );
    addTearDown(harness.dispose);

    await harness.pumpAds();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.textContaining('Ads unavailable'), findsOneWidget);
    expect(harness.repository.eligibilityCalls, 0);
    expect(_callsFor('loadBannerAd'), isEmpty);
    expect(_callsFor('loadRewardedAd'), isEmpty);
    expect(sdkStarted, isFalse);

    consent.complete();
  }, skip: !_testsEnabled);

  testWidgets('consent failure fails closed for both ad widgets', (
    tester,
  ) async {
    final harness = _StartupHarness(
      tester: tester,
      repository: _FakeMonetizationRepository({
        'allowed': true,
        'reason': 'Eligible.',
        'request_non_personalized': true,
      }),
      coordinator: AdStartupCoordinator(
        ensureConsent: () => Future<void>.error(StateError('consent failed')),
        initializeMobileAds: () async {},
      ),
      identityReader: _activeIdentity,
    );
    addTearDown(harness.dispose);

    await harness.pumpAds();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Ads unavailable'), findsOneWidget);
    expect(harness.repository.eligibilityCalls, 0);
    expect(_callsFor('loadBannerAd'), isEmpty);
    expect(_callsFor('loadRewardedAd'), isEmpty);
  }, skip: !_testsEnabled);

  testWidgets(
    'session change while startup is pending uses the current session',
    (tester) async {
      final consent = Completer<void>();
      final sdk = Completer<void>();
      var identity = _activeIdentity();
      final repository = _FakeMonetizationRepository({
        'allowed': true,
        'reason': 'Eligible.',
        'request_non_personalized': true,
      }, currentUserId: () => identity.userId);
      final harness = _StartupHarness(
        tester: tester,
        repository: repository,
        coordinator: AdStartupCoordinator(
          ensureConsent: () => consent.future,
          initializeMobileAds: () => sdk.future,
        ),
        identityReader: () => identity,
      );
      addTearDown(harness.dispose);

      await harness.pumpAds();
      identity = _activeIdentity(userId: 'user-b');
      harness.authEvents.add(const AuthState(AuthChangeEvent.signedIn, null));
      await tester.pump();
      expect(repository.eligibilityCalls, 0);

      consent.complete();
      await tester.pump();
      await tester.pump();
      sdk.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(repository.eligibilityCalls, 2);
      expect(repository.eligibilityUserIds, ['user-b', 'user-b']);
      expect(_callsFor('loadBannerAd'), hasLength(1));
      expect(_callsFor('loadRewardedAd'), hasLength(1));
    },
    skip: !_testsEnabled,
  );

  testWidgets('logout while startup is pending cannot request ads', (
    tester,
  ) async {
    final consent = Completer<void>();
    final sdk = Completer<void>();
    AdSessionIdentity? identity = _activeIdentity();
    final repository = _FakeMonetizationRepository({
      'allowed': true,
      'reason': 'Eligible.',
      'request_non_personalized': true,
    });
    final harness = _StartupHarness(
      tester: tester,
      repository: repository,
      coordinator: AdStartupCoordinator(
        ensureConsent: () => consent.future,
        initializeMobileAds: () => sdk.future,
      ),
      identityReader: () => identity,
    );
    addTearDown(harness.dispose);

    await harness.pumpAds();
    identity = null;
    harness.authEvents.add(const AuthState(AuthChangeEvent.signedOut, null));
    await tester.pump();
    consent.complete();
    await tester.pump();
    await tester.pump();
    sdk.complete();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(repository.eligibilityCalls, 0);
    expect(_callsFor('loadBannerAd'), isEmpty);
    expect(_callsFor('loadRewardedAd'), isEmpty);
  }, skip: !_testsEnabled);

  testWidgets(
    'signed-out and unknown eligibility are denied; teen and adult use server privacy decisions',
    (tester) async {
      final scenarios =
          <
            ({
              String label,
              AdSessionIdentity? identity,
              Map<String, dynamic> eligibility,
              bool shouldLoad,
              bool? expectedNonPersonalized,
            })
          >[
            (
              label: 'signed out',
              identity: null,
              eligibility: {
                'allowed': false,
                'reason': 'Authentication required.',
                'request_non_personalized': true,
              },
              shouldLoad: false,
              expectedNonPersonalized: null,
            ),
            (
              label: 'unknown age or role',
              identity: _activeIdentity(),
              eligibility: {
                'allowed': true,
                'reason': 'Eligible with age-restricted settings.',
                'request_non_personalized': true,
              },
              shouldLoad: true,
              expectedNonPersonalized: true,
            ),
            (
              label: 'verified teen',
              identity: _activeIdentity(),
              eligibility: {
                'allowed': true,
                'reason': 'Eligible.',
                'request_non_personalized': true,
              },
              shouldLoad: true,
              expectedNonPersonalized: true,
            ),
            (
              label: 'eligible adult',
              identity: _activeIdentity(),
              eligibility: {
                'allowed': true,
                'reason': 'Eligible.',
                'request_non_personalized': false,
              },
              shouldLoad: true,
              expectedNonPersonalized: false,
            ),
          ];

      for (final scenario in scenarios) {
        await tester.pumpWidget(const SizedBox.shrink());
        _nativeCalls.clear();
        final repository = _FakeMonetizationRepository(scenario.eligibility);
        final harness = _StartupHarness(
          tester: tester,
          repository: repository,
          coordinator: AdStartupCoordinator(
            ensureConsent: () async {},
            initializeMobileAds: () async {},
          ),
          identityReader: () => scenario.identity,
        );
        await harness.pumpAds();
        await tester.pump();
        await tester.pump();

        expect(
          repository.eligibilityCalls,
          scenario.identity == null ? 0 : 2,
          reason: scenario.label,
        );
        expect(
          _callsFor('loadBannerAd').isNotEmpty,
          scenario.shouldLoad,
          reason: scenario.label,
        );
        expect(
          _callsFor('loadRewardedAd').isNotEmpty,
          scenario.shouldLoad,
          reason: scenario.label,
        );
        if (scenario.expectedNonPersonalized != null) {
          expect(
            (_callsFor('loadBannerAd').single.arguments as Map)['request']
                .nonPersonalizedAds,
            scenario.expectedNonPersonalized,
            reason: scenario.label,
          );
          expect(
            (_callsFor('loadRewardedAd').single.arguments as Map)['request']
                .nonPersonalizedAds,
            scenario.expectedNonPersonalized,
            reason: scenario.label,
          );
        }

        await harness.dispose();
      }
    },
    skip: !_testsEnabled,
  );
}
