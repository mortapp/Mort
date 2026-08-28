enum MortReleaseProfile {
  development('development'),
  automatedTest('automated_test'),
  reviewerDemo('reviewer_demo'),
  closedTest('closed_test'),
  productionCandidate('production_candidate'),
  production('production');

  const MortReleaseProfile(this.value);

  final String value;

  static MortReleaseProfile? tryParse(String value) {
    for (final profile in values) {
      if (profile.value == value) return profile;
    }
    return null;
  }

  bool get requiresHostedBackend => switch (this) {
    development || automatedTest => false,
    reviewerDemo || closedTest || productionCandidate || production => true,
  };

  bool get isReleaseBuild => switch (this) {
    development || automatedTest => false,
    reviewerDemo || closedTest || productionCandidate || production => true,
  };
}

class MortReleaseConfiguration {
  const MortReleaseConfiguration({
    required this.profile,
    required this.releaseStage,
    required this.operationalMode,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabaseProjectRef,
    required this.expectedSupabaseProjectRef,
    required this.googleAuthEnabled,
    required this.appleAuthEnabled,
    required this.oauthCallback,
    required this.publicMarketplaceEnabled,
    required this.marketplacePaymentsEnabled,
    required this.paymentProviderMode,
    required this.identityVerificationEnabled,
    required this.remotePushEnabled,
    required this.crashReportingEnabled,
    required this.chatbotAiEnabled,
    required this.deterministicChatbotFallbackEnabled,
    required this.adsEnabled,
    required this.iapEnabled,
    required this.reviewerModeEnabled,
    required this.productionActivationApproved,
    required this.supportRoute,
    required this.adminRoute,
    required this.termsVersion,
    required this.privacyVersion,
    required this.communityGuidelinesVersion,
    required this.safetyRulesVersion,
    required this.minimumSupportedAppVersion,
    required this.maintenanceMode,
    required this.debugEndpointsEnabled,
  });

  final MortReleaseProfile profile;
  final String releaseStage;
  final String operationalMode;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabaseProjectRef;
  final String expectedSupabaseProjectRef;
  final bool googleAuthEnabled;
  final bool appleAuthEnabled;
  final String oauthCallback;
  final bool publicMarketplaceEnabled;
  final bool marketplacePaymentsEnabled;
  final String paymentProviderMode;
  final bool identityVerificationEnabled;
  final bool remotePushEnabled;
  final bool crashReportingEnabled;
  final bool chatbotAiEnabled;
  final bool deterministicChatbotFallbackEnabled;
  final bool adsEnabled;
  final bool iapEnabled;
  final bool reviewerModeEnabled;
  final bool productionActivationApproved;
  final String supportRoute;
  final String adminRoute;
  final String termsVersion;
  final String privacyVersion;
  final String communityGuidelinesVersion;
  final String safetyRulesVersion;
  final String minimumSupportedAppVersion;
  final bool maintenanceMode;
  final bool debugEndpointsEnabled;

  bool get hostedBackendConfigured =>
      supabaseUrl == 'https://$expectedSupabaseProjectRef.supabase.co' &&
      supabaseProjectRef == expectedSupabaseProjectRef &&
      supabaseAnonKey.trim().isNotEmpty;

  List<String> get validationErrors {
    final errors = <String>[];
    if (operationalMode.trim().isEmpty) {
      errors.add('operational mode is missing');
    }
    if (profile.requiresHostedBackend && !hostedBackendConfigured) {
      errors.add('hosted Supabase public configuration is missing or wrong');
    }
    if (googleAuthEnabled &&
        oauthCallback != 'com.mortapp.mobile://app/auth-callback') {
      errors.add('Google Auth must use the approved native PKCE callback');
    }
    if (appleAuthEnabled &&
        oauthCallback != 'com.mortapp.mobile://app/auth-callback') {
      errors.add('Apple Auth must use the approved native PKCE callback');
    }
    if (!_isSafeInternalRoute(supportRoute)) {
      errors.add('support route must be a non-secret internal app route');
    }
    if (!_isSafeInternalRoute(adminRoute)) {
      errors.add('admin route must be a non-secret internal app route');
    }
    if (!_isSemanticVersion(minimumSupportedAppVersion)) {
      errors.add('minimum supported app version is invalid');
    }
    for (final entry in {
      'terms': termsVersion,
      'privacy': privacyVersion,
      'community guidelines': communityGuidelinesVersion,
      'safety rules': safetyRulesVersion,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        errors.add('${entry.key} version is missing');
      }
    }
    if (!deterministicChatbotFallbackEnabled) {
      errors.add('deterministic support fallback must remain enabled');
    }
    if (!_supportedPaymentModes.contains(paymentProviderMode)) {
      errors.add('payment provider mode is unknown');
    }
    if (marketplacePaymentsEnabled && paymentProviderMode == 'disabled') {
      errors.add('payments enabled without a configured provider mode');
    }
    if (!marketplacePaymentsEnabled && paymentProviderMode == 'stripe_live') {
      errors.add('live payment mode cannot be selected while payments are off');
    }
    if (productionActivationApproved &&
        profile != MortReleaseProfile.production) {
      errors.add('production activation approval is valid only in production');
    }
    if (publicMarketplaceEnabled && profile != MortReleaseProfile.production) {
      errors.add('public marketplace is valid only in production');
    }
    if (reviewerModeEnabled && profile != MortReleaseProfile.reviewerDemo) {
      errors.add('reviewer mode is valid only in the reviewer/demo profile');
    }
    if (profile == MortReleaseProfile.reviewerDemo && !reviewerModeEnabled) {
      errors.add('reviewer/demo profile requires reviewer mode');
    }
    if (profile == MortReleaseProfile.closedTest && reviewerModeEnabled) {
      errors.add('closed-test profile must exclude reviewer/demo routes');
    }
    if (profile.isReleaseBuild && debugEndpointsEnabled) {
      errors.add('debug endpoints are forbidden in release builds');
    }
    if ((profile == MortReleaseProfile.reviewerDemo ||
            profile == MortReleaseProfile.closedTest) &&
        adsEnabled) {
      errors.add(
        'ads are not approved for this release -- real ad traffic is '
        'reserved for production_candidate/production while closed_test '
        'stays on test inventory or ads disabled',
      );
    }
    if (profile.isReleaseBuild && iapEnabled) {
      errors.add('IAP is not approved for this release');
    }

    switch (profile) {
      case MortReleaseProfile.development:
        if (publicMarketplaceEnabled || productionActivationApproved) {
          errors.add('development cannot activate the public marketplace');
        }
        break;
      case MortReleaseProfile.automatedTest:
        if (publicMarketplaceEnabled ||
            productionActivationApproved ||
            identityVerificationEnabled ||
            remotePushEnabled ||
            crashReportingEnabled ||
            chatbotAiEnabled ||
            reviewerModeEnabled) {
          errors.add(
            'automated test cannot enable external production systems',
          );
        }
        break;
      case MortReleaseProfile.reviewerDemo:
        if (releaseStage != 'closed_test' ||
            publicMarketplaceEnabled ||
            productionActivationApproved ||
            identityVerificationEnabled ||
            marketplacePaymentsEnabled) {
          errors.add('reviewer/demo must remain an isolated closed test');
        }
        break;
      case MortReleaseProfile.closedTest:
        if (releaseStage != 'closed_test' ||
            publicMarketplaceEnabled ||
            productionActivationApproved ||
            identityVerificationEnabled ||
            marketplacePaymentsEnabled) {
          errors.add('closed test cannot activate public or provider gates');
        }
        break;
      case MortReleaseProfile.productionCandidate:
        if (releaseStage != 'production_pilot') {
          errors.add('production candidate must use production_pilot stage');
        }
        if (publicMarketplaceEnabled || productionActivationApproved) {
          errors.add('production candidate must keep public activation closed');
        }
        if (!remotePushEnabled || !crashReportingEnabled) {
          errors.add(
            'production candidate requires verified push and crash providers',
          );
        }
        break;
      case MortReleaseProfile.production:
        if (releaseStage != 'production_public') {
          errors.add('production profile must use production_public stage');
        }
        if (!publicMarketplaceEnabled || !productionActivationApproved) {
          errors.add('production requires explicit public activation approval');
        }
        if (!identityVerificationEnabled) {
          errors.add('production requires verified adult identity integration');
        }
        if (!remotePushEnabled || !crashReportingEnabled) {
          errors.add('production requires verified push and crash providers');
        }
        if (_isUnapprovedLegalVersion(termsVersion) ||
            _isUnapprovedLegalVersion(privacyVersion) ||
            _isUnapprovedLegalVersion(communityGuidelinesVersion) ||
            _isUnapprovedLegalVersion(safetyRulesVersion)) {
          errors.add(
            'production requires owner-approved legal document versions',
          );
        }
        break;
    }
    return List.unmodifiable(errors);
  }

  Map<String, String> get safeDiagnostics => {
    'Release profile': profile.value,
    'Release stage': releaseStage,
    'Operational mode': operationalMode,
    'Hosted backend': _enabled(hostedBackendConfigured),
    'Google Auth': _enabled(googleAuthEnabled),
    'Apple Auth': _enabled(appleAuthEnabled),
    'Public marketplace request': _enabled(publicMarketplaceEnabled),
    'Marketplace payments': _enabled(marketplacePaymentsEnabled),
    'Payment provider mode': paymentProviderMode,
    'Identity verification': _enabled(identityVerificationEnabled),
    'Remote push': _enabled(remotePushEnabled),
    'Crash reporting': _enabled(crashReportingEnabled),
    'External support AI': _enabled(chatbotAiEnabled),
    'Deterministic support': _enabled(deterministicChatbotFallbackEnabled),
    'Ads': _enabled(adsEnabled),
    'IAP': _enabled(iapEnabled),
    'Reviewer mode': _enabled(reviewerModeEnabled),
    'Production activation': _enabled(productionActivationApproved),
    'Maintenance mode': _enabled(maintenanceMode),
    'Minimum app version': minimumSupportedAppVersion,
    'Terms version': termsVersion,
    'Privacy version': privacyVersion,
    'Community version': communityGuidelinesVersion,
    'Safety version': safetyRulesVersion,
  };

  static const _supportedPaymentModes = {
    'disabled',
    'preference_only',
    'stripe_test',
    'stripe_live',
  };

  static bool _isSafeInternalRoute(String value) =>
      value.startsWith('/') && !value.contains('://') && !value.contains('..');

  static bool _isSemanticVersion(String value) =>
      RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value);

  static bool _isUnapprovedLegalVersion(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('draft') ||
        normalized.contains('required') ||
        normalized.contains('pending');
  }

  static String _enabled(bool value) => value ? 'enabled' : 'disabled';
}
