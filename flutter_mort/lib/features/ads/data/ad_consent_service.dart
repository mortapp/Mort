import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/observability/structured_log.dart';
import '../../../core/utils/date_of_birth.dart';
import '../../../core/utils/retryable_initialization.dart';
import '../../../data/models/profile.dart';

/// Do not initialize third-party ads for youth, unknown age, signed-out users,
/// a stale profile from another session, or an account that is not active.
bool isEligibleAdultAdAccount(Profile? profile, String? userId, DateTime now) {
  final dob = profile?.dob;
  return userId != null &&
      profile != null &&
      profile.id == userId &&
      profile.isAdult &&
      profile.isActive &&
      profile.onboardingCompleted &&
      (profile.verificationStatus == 'approved' ||
          profile.verificationStatus == 'verified') &&
      dob != null &&
      DateOfBirthParser.ageOn(dob, now) >= 18;
}

class AdRequestGate {
  AdRequestGate({
    required Future<bool> Function() refreshConsent,
    required Future<void> Function() initializeAds,
  }) : _refreshConsent = refreshConsent,
       _initializeAds = initializeAds;

  static final instance = AdRequestGate(
    refreshConsent: _refreshGoogleConsent,
    initializeAds: () async {
      await MobileAds.instance.initialize();
    },
  );

  final Future<bool> Function() _refreshConsent;
  final Future<void> Function() _initializeAds;
  final _sdkInitialization = RetryableInitialization();
  Future<bool>? _pendingConsent;

  Future<bool> prepare({required bool Function() stillEligible}) async {
    if (!stillEligible()) return false;
    try {
      final consent = _pendingConsent ??= Future<bool>.sync(_refreshConsent)
          .whenComplete(() {
            _pendingConsent = null;
          });
      if (!await consent || !stillEligible()) return false;
      await _sdkInitialization.run(_initializeAds);
      return stillEligible();
    } catch (_) {
      MortStructuredLog.instance.record(
        'mort.ads.request_gate_failed',
        level: MortLogLevel.warning,
        attributes: const {'provider': 'admob', 'outcome': 'blocked'},
      );
      return false;
    }
  }

  static Future<bool> _refreshGoogleConsent() async {
    final information = ConsentInformation.instance;
    final update = Completer<bool>();
    information.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      () => update.complete(true),
      (_) => update.complete(false),
    );
    if (!await update.future) return false;
    // Do not serve ads where Google requires a user-facing privacy options
    // control until MORT has a reviewed, working entry point for that control.
    if (await information.getPrivacyOptionsRequirementStatus() !=
        PrivacyOptionsRequirementStatus.notRequired) {
      return false;
    }
    final form = Completer<bool>();
    await ConsentForm.loadAndShowConsentFormIfRequired(
      (error) => form.complete(error == null),
    );
    return await form.future && await information.canRequestAds();
  }
}
