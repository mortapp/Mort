import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';

class AdMobDecision {
  const AdMobDecision({
    required this.canShow,
    required this.reason,
    this.adUnitId,
  });

  final bool canShow;
  final String reason;
  final String? adUnitId;
}

class AdMobService {
  const AdMobService();

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
    final adUnitId = defaultTargetPlatform == TargetPlatform.iOS
        ? AppConfig.admobIosBannerAdUnitId
        : AppConfig.admobAndroidBannerAdUnitId;
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
    final adUnitId = defaultTargetPlatform == TargetPlatform.iOS
        ? AppConfig.admobIosRewardedAdUnitId
        : AppConfig.admobAndroidRewardedAdUnitId;
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
}
