import 'package:flutter_mort/core/config/release_profile.dart';
import 'package:flutter_test/flutter_test.dart';

MortReleaseConfiguration configuration({
  required MortReleaseProfile profile,
  String? releaseStage,
  bool googleAuthEnabled = false,
  bool appleAuthEnabled = false,
  bool publicMarketplaceEnabled = false,
  bool marketplacePaymentsEnabled = false,
  String paymentProviderMode = 'disabled',
  bool identityVerificationEnabled = false,
  bool remotePushEnabled = false,
  bool crashReportingEnabled = false,
  bool chatbotAiEnabled = false,
  bool deterministicChatbotFallbackEnabled = true,
  bool adsEnabled = false,
  bool iapEnabled = false,
  bool reviewerModeEnabled = false,
  bool productionActivationApproved = false,
  String termsVersion = 'draft-2026-07',
  String privacyVersion = 'draft-2026-07',
  String communityVersion = 'draft-2026-07',
  String safetyVersion = 'draft-2026-07',
  bool debugEndpointsEnabled = false,
}) {
  final hosted = profile.requiresHostedBackend;
  return MortReleaseConfiguration(
    profile: profile,
    releaseStage: releaseStage ?? profile.value,
    operationalMode: profile.value,
    supabaseUrl: hosted ? 'https://rakjydmgwwgtdislanbt.supabase.co' : '',
    supabaseAnonKey: hosted ? 'public-anon-key' : '',
    supabaseProjectRef: hosted ? 'rakjydmgwwgtdislanbt' : '',
    expectedSupabaseProjectRef: 'rakjydmgwwgtdislanbt',
    googleAuthEnabled: googleAuthEnabled,
    appleAuthEnabled: appleAuthEnabled,
    oauthCallback: 'com.mortapp.mobile://app/auth-callback',
    publicMarketplaceEnabled: publicMarketplaceEnabled,
    marketplacePaymentsEnabled: marketplacePaymentsEnabled,
    paymentProviderMode: paymentProviderMode,
    identityVerificationEnabled: identityVerificationEnabled,
    remotePushEnabled: remotePushEnabled,
    crashReportingEnabled: crashReportingEnabled,
    chatbotAiEnabled: chatbotAiEnabled,
    deterministicChatbotFallbackEnabled: deterministicChatbotFallbackEnabled,
    adsEnabled: adsEnabled,
    iapEnabled: iapEnabled,
    reviewerModeEnabled: reviewerModeEnabled,
    productionActivationApproved: productionActivationApproved,
    supportRoute: '/support',
    adminRoute: '/admin/home',
    termsVersion: termsVersion,
    privacyVersion: privacyVersion,
    communityGuidelinesVersion: communityVersion,
    safetyRulesVersion: safetyVersion,
    minimumSupportedAppVersion: '0.9.11',
    maintenanceMode: false,
    debugEndpointsEnabled: debugEndpointsEnabled,
  );
}

void main() {
  test('defines the six authoritative release profiles', () {
    expect(MortReleaseProfile.values.map((profile) => profile.value), [
      'development',
      'automated_test',
      'reviewer_demo',
      'closed_test',
      'production_candidate',
      'production',
    ]);
  });

  test(
    'development and automated test are safe without hosted credentials',
    () {
      expect(
        configuration(profile: MortReleaseProfile.development).validationErrors,
        isEmpty,
      );
      expect(
        configuration(
          profile: MortReleaseProfile.automatedTest,
          releaseStage: 'internal_test',
          debugEndpointsEnabled: true,
        ).validationErrors,
        isEmpty,
      );
    },
  );

  test('reviewer demo is isolated from production capabilities', () {
    expect(
      configuration(
        profile: MortReleaseProfile.reviewerDemo,
        releaseStage: 'closed_test',
        googleAuthEnabled: true,
        reviewerModeEnabled: true,
      ).validationErrors,
      isEmpty,
    );
    expect(
      configuration(
        profile: MortReleaseProfile.reviewerDemo,
        releaseStage: 'closed_test',
        reviewerModeEnabled: true,
        publicMarketplaceEnabled: true,
      ).validationErrors,
      isNotEmpty,
    );
  });

  test('closed test excludes reviewer routes and provider gates', () {
    expect(
      configuration(
        profile: MortReleaseProfile.closedTest,
        releaseStage: 'closed_test',
        googleAuthEnabled: true,
      ).validationErrors,
      isEmpty,
    );
    expect(
      configuration(
        profile: MortReleaseProfile.closedTest,
        releaseStage: 'closed_test',
        reviewerModeEnabled: true,
      ).validationErrors,
      contains('reviewer mode is valid only in the reviewer/demo profile'),
    );
  });

  test('production candidate requires push and crash while staying closed', () {
    final invalid = configuration(
      profile: MortReleaseProfile.productionCandidate,
      releaseStage: 'production_pilot',
    );
    expect(invalid.validationErrors, isNotEmpty);

    final valid = configuration(
      profile: MortReleaseProfile.productionCandidate,
      releaseStage: 'production_pilot',
      remotePushEnabled: true,
      crashReportingEnabled: true,
    );
    expect(valid.validationErrors, isEmpty);
  });

  test(
    'production requires provider, server activation, and approved legal versions',
    () {
      final valid = configuration(
        profile: MortReleaseProfile.production,
        releaseStage: 'production_public',
        publicMarketplaceEnabled: true,
        identityVerificationEnabled: true,
        remotePushEnabled: true,
        crashReportingEnabled: true,
        productionActivationApproved: true,
        termsVersion: 'terms-2026-08-approved',
        privacyVersion: 'privacy-2026-08-approved',
        communityVersion: 'community-2026-08-approved',
        safetyVersion: 'safety-2026-08-approved',
      );
      expect(valid.validationErrors, isEmpty);

      final invalid = configuration(
        profile: MortReleaseProfile.production,
        releaseStage: 'production_public',
        publicMarketplaceEnabled: true,
        identityVerificationEnabled: true,
        remotePushEnabled: true,
        crashReportingEnabled: true,
      );
      expect(invalid.validationErrors, isNotEmpty);
    },
  );

  test(
    'payments, ads, IAP, callbacks, and deterministic fallback fail closed',
    () {
      final invalid = configuration(
        profile: MortReleaseProfile.closedTest,
        releaseStage: 'closed_test',
        marketplacePaymentsEnabled: true,
        adsEnabled: true,
        iapEnabled: true,
        deterministicChatbotFallbackEnabled: false,
      );
      expect(invalid.validationErrors.length, greaterThanOrEqualTo(4));
    },
  );

  test('safe diagnostics contain status but no public key or backend URL', () {
    final diagnostics = configuration(
      profile: MortReleaseProfile.closedTest,
      releaseStage: 'closed_test',
    ).safeDiagnostics;
    final values = diagnostics.values.join(' ');
    expect(values, isNot(contains('public-anon-key')));
    expect(values, isNot(contains('supabase.co')));
    expect(diagnostics['Hosted backend'], 'enabled');
  });
}
