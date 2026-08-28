import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/observability/structured_log.dart';

/// Wraps Google's User Messaging Platform (UMP) SDK so ad consent is
/// requested and honored before any ad request is made. MORT never shows
/// ads on sensitive screens regardless of consent state -- this only
/// governs whether a shown ad may be personalized.
class AdConsentService {
  const AdConsentService();

  /// Requests the latest consent info and, if required by the user's
  /// region (EEA/UK-style consent rules), shows Google's consent form.
  /// Completes once it is safe to request ads -- consent obtained, not
  /// required, or the request/form failed. Failures fail closed to
  /// non-personalized ads rather than blocking the ad slot entirely; MORT's
  /// own sensitive-placement gating applies regardless of consent outcome.
  Future<void> ensureConsent({bool underAgeOfConsent = false}) {
    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    final params = ConsentRequestParameters(
      tagForUnderAgeOfConsent: underAgeOfConsent,
    );

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadAndShowForm(finish);
        } else {
          finish();
        }
      },
      (FormError error) {
        MortStructuredLog.instance.record(
          'mort.ads.consent_info_update_failed',
          level: MortLogLevel.warning,
          attributes: {'error_code': error.errorCode.toString()},
        );
        finish();
      },
    );

    return completer.future;
  }

  void _loadAndShowForm(void Function() finish) {
    ConsentForm.loadConsentForm(
      (ConsentForm form) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          form.show((FormError? dismissError) {
            if (dismissError != null) {
              MortStructuredLog.instance.record(
                'mort.ads.consent_form_dismiss_error',
                level: MortLogLevel.warning,
                attributes: {'error_code': dismissError.errorCode.toString()},
              );
            }
            finish();
          });
        } else {
          finish();
        }
      },
      (FormError error) {
        MortStructuredLog.instance.record(
          'mort.ads.consent_form_load_failed',
          level: MortLogLevel.warning,
          attributes: {'error_code': error.errorCode.toString()},
        );
        finish();
      },
    );
  }

  /// Whether ads must be requested as non-personalized right now, per the
  /// last consent outcome. MORT additionally forces this to true for every
  /// Teen and every user of unknown age regardless of what this returns --
  /// see [AdMobService].
  Future<bool> requiresNonPersonalizedAds() async {
    final status = await ConsentInformation.instance.getConsentStatus();
    return status != ConsentStatus.obtained;
  }
}
