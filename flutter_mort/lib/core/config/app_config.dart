import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const appName = 'MORT';
  static const slogan = 'Earn nearby. Move smart.';
  static const releaseStage = String.fromEnvironment(
    'MORT_RELEASE_STAGE',
    defaultValue: 'development',
  );
  static const operationalMode = String.fromEnvironment(
    'MORT_OPERATIONAL_MODE',
    defaultValue: 'development',
  );
  static const publicMarketplaceEnabled = bool.fromEnvironment(
    'MORT_PUBLIC_MARKETPLACE_ENABLED',
    defaultValue: false,
  );
  static const identityVerificationEnabled = bool.fromEnvironment(
    'MORT_IDENTITY_VERIFICATION_ENABLED',
    defaultValue: false,
  );
  static const supportedReleaseStages = <String>{
    'development',
    'internal_test',
    'closed_test',
    'production_pilot',
    'production_public',
  };
  static bool get hasKnownReleaseStage =>
      supportedReleaseStages.contains(releaseStage);
  static String get stageName => switch (releaseStage) {
    'internal_test' => 'Internal Test',
    'closed_test' => 'Closed Pilot',
    'production_pilot' => 'Production Pilot',
    'production_public' => 'Public Marketplace',
    _ => 'Development',
  };
  static bool get showReleaseStageLabel => releaseStage != 'production_public';
  static const iOSBundleId = 'com.mortapp.mobile';
  static const androidPackage = 'com.mortapp.mobile';
  static const authRedirectUrl = String.fromEnvironment(
    'MORT_AUTH_REDIRECT_URL',
    defaultValue: 'mort://app/auth-callback',
  );
  static const publicWebOrigin = String.fromEnvironment(
    'MORT_PUBLIC_WEB_ORIGIN',
    defaultValue: 'https://mort-web.vercel.app',
  );

  static String get resolvedAuthRedirectUrl =>
      kIsWeb ? Uri.base.resolve('/auth-callback').toString() : authRedirectUrl;

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const revenueCatEntitlementPlus = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_PLUS',
    defaultValue: 'mort_plus',
  );
  static const revenueCatEntitlementAdFree = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_AD_FREE',
    defaultValue: 'mort_ad_free',
  );
  static const revenueCatEntitlementAdultPro = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ADULT_PRO',
    defaultValue: 'mort_adult_pro',
  );
  static const revenueCatEntitlementGuardianPlus = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_GUARDIAN_PLUS',
    defaultValue: 'mort_guardian_plus',
  );
  static const revenueCatEntitlementUsernameToken = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_USERNAME_TOKEN',
    defaultValue: 'mort_username_change_token',
  );
  static const revenueCatEntitlementJobBoost = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_JOB_BOOST',
    defaultValue: 'mort_job_boost',
  );
  static const revenueCatEntitlementProfileStylePack = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_PROFILE_STYLE_PACK',
    defaultValue: 'mort_profile_style_pack',
  );

  static const admobIosAppId = String.fromEnvironment('ADMOB_IOS_APP_ID');
  static const admobIosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_AD_UNIT_ID',
  );
  static const admobIosRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_AD_UNIT_ID',
  );
  static const admobIosInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID',
  );
  static const admobIosNativeAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_NATIVE_AD_UNIT_ID',
  );

  static const admobAndroidAppId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_ID',
  );
  static const admobAndroidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_AD_UNIT_ID',
  );
  static const admobAndroidRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_AD_UNIT_ID',
  );
  static const admobAndroidInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID',
  );
  static const admobAndroidNativeAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_NATIVE_AD_UNIT_ID',
  );

  static const adsEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );
  static const useTestAds = bool.fromEnvironment(
    'USE_TEST_ADS',
    defaultValue: true,
  );
  static const iapEnabled = bool.fromEnvironment(
    'IAP_ENABLED',
    defaultValue: false,
  );
  static const nativeAdsCompiledIn = false;
  static const nativeBillingCompiledIn = true;
  static const nativeStripePaymentSheetCompiledIn = true;
  static const webPreviewMode = bool.fromEnvironment(
    'WEB_PREVIEW_MODE',
    defaultValue: false,
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.trim().isNotEmpty;

  static bool get supportsNativePurchases =>
      nativeBillingCompiledIn &&
      iapEnabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  static bool get supportsNativeAds => nativeAdsCompiledIn && !kIsWeb;

  static bool get supportsStripePaymentSheet =>
      nativeStripePaymentSheetCompiledIn && !kIsWeb;
}
