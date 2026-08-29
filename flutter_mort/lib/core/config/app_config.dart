import 'package:flutter/foundation.dart';

import 'release_profile.dart';

class AppConfig {
  const AppConfig._();

  static const expectedSupabaseProjectRef = 'rakjydmgwwgtdislanbt';

  static const appName = 'MORT';
  static const slogan = 'Earn nearby. Move smart.';
  static const releaseStage = String.fromEnvironment(
    'MORT_RELEASE_STAGE',
    defaultValue: 'development',
  );
  static const configuredReleaseProfile = String.fromEnvironment(
    'MORT_RELEASE_PROFILE',
    defaultValue: '',
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
  static const marketplacePaymentsEnabled = bool.fromEnvironment(
    'MORT_MARKETPLACE_PAYMENTS_ENABLED',
    defaultValue: false,
  );
  static const remotePushEnabled = bool.fromEnvironment(
    'MORT_REMOTE_PUSH_ENABLED',
    defaultValue: false,
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseAndroidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseIosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const crashReportingEnabled = bool.fromEnvironment(
    'MORT_CRASH_REPORTING_ENABLED',
    defaultValue: false,
  );
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const productAnalyticsEnabled = bool.fromEnvironment(
    'MORT_PRODUCT_ANALYTICS_ENABLED',
    defaultValue: false,
  );
  static const paymentProviderMode = String.fromEnvironment(
    'MORT_PAYMENT_PROVIDER_MODE',
    defaultValue: 'disabled',
  );
  static const chatbotAiEnabled = bool.fromEnvironment(
    'MORT_SUPPORT_AI_ENABLED',
    defaultValue: false,
  );
  static const deterministicChatbotFallbackEnabled = bool.fromEnvironment(
    'MORT_DETERMINISTIC_SUPPORT_ENABLED',
    defaultValue: true,
  );
  static const publicActivationApproved = bool.fromEnvironment(
    'MORT_PUBLIC_ACTIVATION_APPROVED',
    defaultValue: false,
  );
  static const playReviewModeEnabled = bool.fromEnvironment(
    'PLAY_REVIEW_MODE_ENABLED',
    defaultValue: false,
  );
  static const supabaseProjectRef = String.fromEnvironment(
    'MORT_SUPABASE_PROJECT_REF',
    defaultValue: '',
  );
  static const supportRoute = String.fromEnvironment(
    'MORT_SUPPORT_ROUTE',
    defaultValue: '/support',
  );
  static const adminRoute = String.fromEnvironment(
    'MORT_ADMIN_ROUTE',
    defaultValue: '/admin/home',
  );
  static const termsVersion = String.fromEnvironment(
    'MORT_TERMS_VERSION',
    defaultValue: 'draft-2026-07',
  );
  static const privacyVersion = String.fromEnvironment(
    'MORT_PRIVACY_VERSION',
    defaultValue: 'draft-2026-07',
  );
  static const communityGuidelinesVersion = String.fromEnvironment(
    'MORT_COMMUNITY_GUIDELINES_VERSION',
    defaultValue: 'draft-2026-07',
  );
  static const safetyRulesVersion = String.fromEnvironment(
    'MORT_SAFETY_RULES_VERSION',
    defaultValue: 'draft-2026-07',
  );
  static const minimumSupportedAppVersion = String.fromEnvironment(
    'MORT_MINIMUM_SUPPORTED_APP_VERSION',
    defaultValue: '0.9.11',
  );
  static const maintenanceMode = bool.fromEnvironment(
    'MORT_MAINTENANCE_MODE',
    defaultValue: false,
  );
  static const debugEndpointsEnabled = bool.fromEnvironment(
    'MORT_DEBUG_ENDPOINTS_ENABLED',
    defaultValue: false,
  );
  static const supportedReleaseStages = <String>{
    'development',
    'internal_test',
    'closed_test',
    'production_pilot',
    'production_public',
  };
  static const supportedReleaseProfiles = <String>{
    'development',
    'automated_test',
    'reviewer_demo',
    'closed_test',
    'production_candidate',
    'production',
  };

  static String get releaseProfileName => configuredReleaseProfile.isNotEmpty
      ? configuredReleaseProfile
      : switch (releaseStage) {
          'internal_test' => 'automated_test',
          'closed_test' when playReviewModeEnabled => 'reviewer_demo',
          'closed_test' => 'closed_test',
          'production_pilot' => 'production_candidate',
          'production_public' => 'production',
          _ => 'development',
        };

  static MortReleaseProfile get releaseProfile =>
      MortReleaseProfile.tryParse(releaseProfileName) ??
      MortReleaseProfile.development;

  static bool get hasKnownReleaseProfile =>
      supportedReleaseProfiles.contains(releaseProfileName);
  static bool get hasKnownReleaseStage =>
      supportedReleaseStages.contains(releaseStage);
  static String get stageName => switch (releaseStage) {
    'internal_test' => 'Internal Test',
    'closed_test' => 'MORT',
    'production_pilot' => 'Production Pilot',
    'production_public' => 'Public Marketplace',
    _ => 'Development',
  };
  static bool get showReleaseStageLabel => releaseStage != 'production_public';
  static const iOSBundleId = 'com.mortapp.mobile';
  static const androidPackage = 'com.mortapp.mobile';
  static const expectedNativeAuthRedirectUrl =
      'com.mortapp.mobile://app/auth-callback';
  static const authRedirectUrl = String.fromEnvironment(
    'MORT_AUTH_REDIRECT_URL',
    defaultValue: expectedNativeAuthRedirectUrl,
  );
  static const authConfirmationRedirectUrl = String.fromEnvironment(
    'MORT_AUTH_CONFIRM_REDIRECT_URL',
    defaultValue: 'com.mortapp.mobile://app/auth-confirm',
  );
  static const passwordRecoveryRedirectUrl = String.fromEnvironment(
    'MORT_PASSWORD_RECOVERY_REDIRECT_URL',
    defaultValue: 'com.mortapp.mobile://app/auth-recovery',
  );
  static const googleAuthEnabled = bool.fromEnvironment(
    'GOOGLE_AUTH_ENABLED',
    defaultValue: false,
  );
  static const appleAuthEnabled = bool.fromEnvironment(
    'APPLE_AUTH_ENABLED',
    defaultValue: false,
  );
  static const publicWebOrigin = String.fromEnvironment(
    'MORT_PUBLIC_WEB_ORIGIN',
    defaultValue: 'https://mort-web.vercel.app',
  );

  static String get resolvedAuthRedirectUrl => kIsWeb
      ? Uri.base.resolve('/auth-callback').replace(query: null).toString()
      : authRedirectUrl;

  static String get resolvedAuthConfirmationRedirectUrl => kIsWeb
      ? Uri.base.resolve('/auth/confirm').replace(query: null).toString()
      : authConfirmationRedirectUrl;

  static String get resolvedPasswordRecoveryRedirectUrl => kIsWeb
      ? Uri.base.resolve('/auth/recovery').replace(query: null).toString()
      : passwordRecoveryRedirectUrl;

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

  // Defaults are the real, confirmed MORT production AdMob identifiers
  // (public identifiers, not secrets -- same category as the package name).
  // A dart-define can still override them if the AdMob app/units are ever
  // recreated. USE_TEST_ADS (default true) governs whether these are
  // actually used or Google's own test ad unit ids are, so simply having
  // real values configured here does not by itself serve real ads.
  static const admobAndroidAppId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_ID',
    defaultValue: 'ca-app-pub-9883419411387958~1048817736',
  );
  static const admobAndroidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-9883419411387958/8216077490',
  );
  static const admobAndroidRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-9883419411387958/1877899853',
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
  static const nativeAdsCompiledIn = true;
  static const nativeBillingCompiledIn = false;
  static const nativeStripePaymentSheetCompiledIn = false;
  static const webPreviewMode = bool.fromEnvironment(
    'WEB_PREVIEW_MODE',
    defaultValue: false,
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.trim().isNotEmpty;

  static String get firebaseApiKey =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? firebaseIosApiKey
      : firebaseAndroidApiKey;

  static String get firebaseAppId => defaultTargetPlatform == TargetPlatform.iOS
      ? firebaseIosAppId
      : firebaseAndroidAppId;

  static bool get isFirebaseClientConfigured =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      firebaseProjectId.trim().isNotEmpty &&
      firebaseMessagingSenderId.trim().isNotEmpty &&
      firebaseApiKey.trim().isNotEmpty &&
      firebaseAppId.trim().isNotEmpty;

  static bool get isSentryConfigured =>
      Uri.tryParse(sentryDsn)?.isScheme('https') == true &&
      Uri.parse(sentryDsn).host.isNotEmpty;

  static MortReleaseConfiguration get releaseConfiguration =>
      MortReleaseConfiguration(
        profile: releaseProfile,
        releaseStage: releaseStage,
        operationalMode: operationalMode,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        supabaseProjectRef: supabaseProjectRef,
        expectedSupabaseProjectRef: expectedSupabaseProjectRef,
        googleAuthEnabled: googleAuthEnabled,
        appleAuthEnabled: appleAuthEnabled,
        oauthCallback: authRedirectUrl,
        publicMarketplaceEnabled: publicMarketplaceEnabled,
        marketplacePaymentsEnabled: marketplacePaymentsEnabled,
        paymentProviderMode: paymentProviderMode,
        identityVerificationEnabled: identityVerificationEnabled,
        remotePushEnabled: remotePushEnabled,
        crashReportingEnabled: crashReportingEnabled,
        chatbotAiEnabled: chatbotAiEnabled,
        deterministicChatbotFallbackEnabled:
            deterministicChatbotFallbackEnabled,
        adsEnabled: adsEnabled,
        iapEnabled: iapEnabled,
        reviewerModeEnabled: playReviewModeEnabled,
        productionActivationApproved: publicActivationApproved,
        supportRoute: supportRoute,
        adminRoute: adminRoute,
        termsVersion: termsVersion,
        privacyVersion: privacyVersion,
        communityGuidelinesVersion: communityGuidelinesVersion,
        safetyRulesVersion: safetyRulesVersion,
        minimumSupportedAppVersion: minimumSupportedAppVersion,
        maintenanceMode: maintenanceMode,
        debugEndpointsEnabled: debugEndpointsEnabled,
      );

  static Map<String, String> get safeReleaseDiagnostics => {
    ...releaseConfiguration.safeDiagnostics,
    'Firebase client config': isFirebaseClientConfigured
        ? 'configured'
        : 'not configured',
    'Crash provider': crashReportingEnabled && isSentryConfigured
        ? 'configured'
        : 'disabled',
    'Product analytics': productAnalyticsEnabled ? 'enabled' : 'disabled',
  };

  static List<String> get validationErrors {
    final errors = <String>[...releaseConfiguration.validationErrors];
    if (!hasKnownReleaseProfile) {
      errors.add('unknown release profile');
    }
    if (!hasKnownReleaseStage) {
      errors.add('unknown release stage');
    }
    if (operationalMode.trim().isEmpty) {
      errors.add('operational mode is missing');
    }

    final isRelease = releaseStage != 'development';
    if (isRelease) {
      if (!isSupabaseConfigured) {
        errors.add('hosted Supabase public configuration is missing');
      }
      if (supabaseProjectRef != expectedSupabaseProjectRef ||
          supabaseUrl != 'https://$expectedSupabaseProjectRef.supabase.co') {
        errors.add('Supabase project does not match the approved MORT project');
      }
      if (iapEnabled || nativeBillingCompiledIn) {
        errors.add('native billing must be absent from this release');
      }
      // Ads SDK being compiled in is a deliberate, owner-authorized product
      // decision (MORT ships real Banner/Rewarded ads) -- no longer
      // prohibited. What must still fail closed: if a release build turns
      // ads on at all, it must actually be configured for the platform it's
      // building for, rather than silently shipping a broken ad slot.
      if (adsEnabled && useTestAds) {
        errors.add(
          'ads are enabled for this release but USE_TEST_ADS was not set to false -- this would serve Google test ads to real users',
        );
      }
      if (adsEnabled && !kIsWeb) {
        final adUnitIdMissing = defaultTargetPlatform == TargetPlatform.iOS
            ? admobIosAppId.isEmpty || admobIosBannerAdUnitId.isEmpty
            : admobAndroidAppId.isEmpty || admobAndroidBannerAdUnitId.isEmpty;
        if (adUnitIdMissing) {
          errors.add(
            'ads are enabled for this release but the platform AdMob app/ad unit ids are not configured',
          );
        }
      }
      if (marketplacePaymentsEnabled) {
        errors.add('marketplace payments are not approved for this release');
      }
      if (googleAuthEnabled &&
          authRedirectUrl != expectedNativeAuthRedirectUrl) {
        errors.add('Google Auth must use the approved native callback');
      }
      if (appleAuthEnabled &&
          authRedirectUrl != expectedNativeAuthRedirectUrl) {
        errors.add('Apple Auth must use the approved native callback');
      }
    }

    if (releaseStage == 'closed_test' && publicMarketplaceEnabled) {
      errors.add('closed test cannot open the public marketplace');
    }
    if (remotePushEnabled && !isFirebaseClientConfigured) {
      errors.add(
        'remote push is enabled without complete Firebase client configuration',
      );
    }
    if (crashReportingEnabled && !isSentryConfigured) {
      errors.add('crash reporting is enabled without a valid Sentry DSN');
    }
    if ((releaseStage == 'production_pilot' ||
            releaseStage == 'production_public') &&
        playReviewModeEnabled) {
      errors.add('reviewer mode must be excluded from production builds');
    }
    if (releaseStage == 'production_pilot') {
      if (publicMarketplaceEnabled || publicActivationApproved) {
        errors.add('production pilot must keep public activation closed');
      }
      if (!remotePushEnabled) {
        errors.add(
          'production pilot requires a configured remote push provider',
        );
      }
      if (!crashReportingEnabled) {
        errors.add('production pilot requires a configured crash provider');
      }
    }
    if (releaseStage == 'production_public') {
      if (!publicMarketplaceEnabled || !publicActivationApproved) {
        errors.add('public activation is not approved');
      }
      if (!identityVerificationEnabled) {
        errors.add('public mode requires production identity verification');
      }
      if (!remotePushEnabled || !crashReportingEnabled) {
        errors.add('public mode requires push and crash providers');
      }
    }
    return List.unmodifiable(errors);
  }

  static void assertValidReleaseConfiguration() {
    final errors = validationErrors;
    if (errors.isEmpty) return;
    throw StateError(
      'Invalid MORT release configuration: ${errors.join('; ')}.',
    );
  }

  static bool get supportsNativePurchases => false;

  static bool get supportsNativeAds => nativeAdsCompiledIn && !kIsWeb;

  static bool get supportsStripePaymentSheet => false;
}
