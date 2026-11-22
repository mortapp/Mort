import 'dart:async';

import 'package:flutter_mort/core/utils/retryable_initialization.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/features/ads/data/ad_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'optional initialization coalesces and can retry after failure',
    () async {
      final task = RetryableInitialization();
      final attempt = Completer<void>();
      var calls = 0;
      Future<void> initialize() {
        calls++;
        return attempt.future;
      }

      final first = task.run(initialize);
      final second = task.run(initialize);
      expect(identical(first, second), isTrue);
      final error = expectLater(first, throwsStateError);
      attempt.completeError(StateError('fixture failure'));
      await error;
      await task.run(() async => calls++);
      await task.run(() async => calls++);
      expect(calls, 2);
    },
  );

  test(
    'no SDK calls when ineligible, consent fails, or session changes',
    () async {
      var eligible = false;
      var consentCalls = 0;
      var sdkCalls = 0;
      var consent = Completer<bool>();
      final gate = AdRequestGate(
        refreshConsent: () {
          consentCalls++;
          return consent.future;
        },
        initializeAds: () async => sdkCalls++,
      );

      expect(await gate.prepare(stillEligible: () => eligible), isFalse);
      expect(consentCalls, 0);
      eligible = true;
      final denied = gate.prepare(stillEligible: () => eligible);
      consent.completeError(StateError('provider unavailable'));
      expect(await denied, isFalse);
      consent = Completer<bool>();
      final stale = gate.prepare(stillEligible: () => eligible);
      eligible = false;
      consent.complete(true);
      expect(await stale, isFalse);
      expect(consentCalls, 2);
      expect(sdkCalls, 0);
    },
  );

  test('ad SDK only initializes after current consent and only once', () async {
    final consent = Completer<bool>();
    final sdk = Completer<void>();
    final started = Completer<void>();
    final events = <String>[];
    final gate = AdRequestGate(
      refreshConsent: () {
        events.add('consent');
        return consent.future;
      },
      initializeAds: () {
        events.add('sdk');
        started.complete();
        return sdk.future;
      },
    );
    var eligible = true;
    final first = gate.prepare(stillEligible: () => eligible);
    final second = gate.prepare(stillEligible: () => true);
    expect(events, ['consent']);
    consent.complete(true);
    await started.future;
    eligible = false;
    sdk.complete();
    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(events, ['consent', 'sdk']);
  });

  test('youth, absent DOB, inactive and stale profiles cannot start ads', () {
    Profile fixture({
      UserRole role = UserRole.adult,
      String? birthday = '1990-01-01',
      String status = 'active',
      bool onboarded = true,
    }) => Profile(
      id: 'disposable-fixture',
      role: role,
      displayName: null,
      username: null,
      dob: birthday == null ? null : DateTime.parse(birthday),
      city: null,
      state: null,
      onboardingCompleted: onboarded,
      accountStatus: status,
      verificationStatus: 'unverified',
      paymentPreference: 'unset',
    );
    final today = DateTime(2026, 11, 22);
    bool eligible(Profile? profile, [String? subject = 'disposable-fixture']) =>
        isEligibleAdultAdAccount(profile, subject, today);
    expect(eligible(fixture()), isTrue);
    expect(eligible(fixture(role: UserRole.teen)), isFalse);
    expect(eligible(fixture(birthday: '2009-01-01')), isFalse);
    expect(eligible(fixture(birthday: null)), isFalse);
    expect(eligible(fixture(status: 'suspended')), isFalse);
    expect(eligible(fixture(onboarded: false)), isFalse);
    expect(eligible(fixture(), 'different-fixture'), isFalse);
    expect(eligible(fixture(), null), isFalse);
    expect(eligible(null), isFalse);
  });
}
