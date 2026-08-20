import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/monetization_repository.dart';

class AdMobDecision {
  const AdMobDecision({
    required this.canShow,
    required this.reason,
    this.adUnitId,
    this.requestNonPersonalized = true,
  });

  final bool canShow;
  final String reason;
  final String? adUnitId;

  /// Fail-safe default is true (non-personalized) -- this only ever
  /// becomes false once the server-authoritative `get_ad_eligibility` RPC
  /// confirms an adult with personalized ads explicitly allowed.
  final bool requestNonPersonalized;
}

class AdMobService {
  const AdMobService();

  // Google's own official, publicly-documented sample ad unit IDs -- safe
  // to hardcode, meant exactly for this purpose. Used whenever
  // AppConfig.useTestAds is true (the default), so a build that forgets to
  // pass USE_TEST_ADS=false never accidentally serves a real production ad
  // slot; conversely one that forgets to pass real production ids while
  // USE_TEST_ADS=false is caught by AppConfig.validationErrors instead of
  // silently falling back to test ads in a real release.
  static const _testAndroidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _testAndroidRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const _testIosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const _testIosRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  static const sensitivePlacements = {
    'auth',
    'onboarding',
    'age_gate',
    'safety_ping',
    'report',
    'messages',
    'guardian_approval',
    'proof_upload',
    'verification',
    'payment_preference',
    'admin',
    'paywall',
  };

  AdMobDecision bannerDecision({
    required String placement,
    bool userAdFree = false,
  }) {
    if (sensitivePlacements.contains(placement)) {
      return const AdMobDecision(
        canShow: false,
        reason: 'Sensitive screen ads are blocked.',
      );
    }
    if (!AppConfig.nativeAdsCompiledIn) {
      return const AdMobDecision(
        canShow: false,
        reason: 'Ads are not included in this release.',
      );
    }
    if (!AppConfig.adsEnabled) {
      return const AdMobDecision(canShow: false, reason: 'ADS_ENABLED=false.');
    }
    if (!AppConfig.supportsNativeAds) {
      return const AdMobDecision(
        canShow: false,
        reason: 'AdMob is disabled on web.',
      );
    }
    if (userAdFree) {
      return const AdMobDecision(
        canShow: false,
        reason: 'User has an ad-free entitlement.',
      );
    }
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final configuredAdUnitId = isIos
        ? AppConfig.admobIosBannerAdUnitId
        : AppConfig.admobAndroidBannerAdUnitId;
    final adUnitId = AppConfig.useTestAds
        ? (isIos ? _testIosBannerAdUnitId : _testAndroidBannerAdUnitId)
        : configuredAdUnitId;
    if (adUnitId.isEmpty) {
      return const AdMobDecision(
        canShow: false,
        reason: 'No banner ad unit id configured.',
      );
    }
    return AdMobDecision(
      canShow: true,
      adUnitId: adUnitId,
      reason: AppConfig.useTestAds
          ? 'Ready for native test ads.'
          : 'Ready for live ads after review.',
    );
  }

  AdMobDecision rewardedDecision({
    required String placement,
    bool userAdFree = false,
  }) {
    if (sensitivePlacements.contains(placement)) {
      return const AdMobDecision(
        canShow: false,
        reason: 'Rewarded ads are blocked here.',
      );
    }
    if (!AppConfig.nativeAdsCompiledIn) {
      return const AdMobDecision(
        canShow: false,
        reason: 'Ads are not included in this release.',
      );
    }
    if (!AppConfig.adsEnabled) {
      return const AdMobDecision(canShow: false, reason: 'ADS_ENABLED=false.');
    }
    if (!AppConfig.supportsNativeAds) {
      return const AdMobDecision(
        canShow: false,
        reason: 'Rewarded ads are disabled on web.',
      );
    }
    if (userAdFree) {
      return const AdMobDecision(
        canShow: false,
        reason: 'User has an ad-free entitlement.',
      );
    }
    final isIosRewarded = defaultTargetPlatform == TargetPlatform.iOS;
    final configuredRewardedAdUnitId = isIosRewarded
        ? AppConfig.admobIosRewardedAdUnitId
        : AppConfig.admobAndroidRewardedAdUnitId;
    final adUnitId = AppConfig.useTestAds
        ? (isIosRewarded
              ? _testIosRewardedAdUnitId
              : _testAndroidRewardedAdUnitId)
        : configuredRewardedAdUnitId;
    if (adUnitId.isEmpty) {
      return const AdMobDecision(
        canShow: false,
        reason: 'No rewarded ad unit id configured.',
      );
    }
    return AdMobDecision(
      canShow: true,
      adUnitId: adUnitId,
      reason: AppConfig.useTestAds
          ? 'Ready for native rewarded test ads.'
          : 'Ready for live rewarded ads after review.',
    );
  }

  /// Re-checks a locally-approved [decision] against the server-authoritative
  /// `get_ad_eligibility` RPC (consent readiness, ad-free entitlement, role/
  /// age-driven personalization) before an ad is actually requested. The
  /// server can only narrow a local decision, never widen it: if the local
  /// check already said no, this is not called. On any RPC error this fails
  /// closed -- ad blocked, non-personalized assumed -- rather than trusting
  /// the client-only decision.
  Future<AdMobDecision> confirmWithServer({
    required AdMobDecision decision,
    required MonetizationRepository repository,
    required String placement,
    required String adFormat,
  }) async {
    if (!decision.canShow) return decision;
    try {
      final result = await repository.adEligibility(placement, adFormat);
      final allowed = result['allowed'] == true;
      final nonPersonalized = result['request_non_personalized'] != false;
      if (!allowed) {
        return AdMobDecision(
          canShow: false,
          reason: (result['reason'] as String?) ?? 'Not eligible.',
        );
      }
      return AdMobDecision(
        canShow: true,
        adUnitId: decision.adUnitId,
        reason: decision.reason,
        requestNonPersonalized: nonPersonalized,
      );
    } catch (_) {
      return const AdMobDecision(
        canShow: false,
        reason: 'Could not confirm ad eligibility.',
      );
    }
  }
}
