enum AccountTrustLevel {
  basic(0, 'Basic account'),
  secured(1, 'Account secured'),
  affiliation(2, 'Affiliation verified'),
  digitalGovernmentCredential(3, 'Government digital ID verified'),
  providerIdentity(4, 'Provider identity verified'),
  enhancedAdultScreening(5, 'Enhanced adult screening');

  const AccountTrustLevel(this.value, this.title);

  factory AccountTrustLevel.fromValue(int value) {
    return values.firstWhere(
      (level) => level.value == value,
      orElse: () => AccountTrustLevel.basic,
    );
  }

  final int value;
  final String title;
}

class TrustIndicator {
  const TrustIndicator({
    required this.key,
    required this.category,
    required this.label,
    required this.status,
    required this.whatWasChecked,
    required this.whatWasNotChecked,
    required this.grantsMarketplaceAccess,
    required this.doesNotGuaranteeSafety,
    this.checkedAt,
    this.expiresAt,
    this.environment,
  });

  factory TrustIndicator.fromMap(Map<String, dynamic> map) {
    return TrustIndicator(
      key: _text(map['key'], fallback: 'unknown_signal'),
      category: _text(map['category'], fallback: 'other'),
      label: _text(map['label'], fallback: 'Trust signal'),
      status: _text(map['status'], fallback: 'unknown'),
      whatWasChecked: _text(
        map['what_was_checked'],
        fallback: 'No check description was returned.',
      ),
      whatWasNotChecked: _text(
        map['what_was_not_checked'],
        fallback: 'This signal does not guarantee identity or safety.',
      ),
      checkedAt: map['checked_at'] as String?,
      expiresAt: map['expires_at'] as String?,
      grantsMarketplaceAccess: map['grants_marketplace_access'] == true,
      doesNotGuaranteeSafety: map['does_not_guarantee_safety'] != false,
      environment: map['environment'] as String?,
    );
  }

  final String key;
  final String category;
  final String label;
  final String status;
  final String whatWasChecked;
  final String whatWasNotChecked;
  final String? checkedAt;
  final String? expiresAt;
  final bool grantsMarketplaceAccess;
  final bool doesNotGuaranteeSafety;
  final String? environment;
}

class MarketplaceTrustEligibility {
  const MarketplaceTrustEligibility({
    required this.allowed,
    required this.requiredLevel,
    required this.currentLevel,
    required this.missingRequirements,
    required this.reasonCodes,
    required this.supportRoute,
    required this.productionMarketplaceEnabled,
    required this.guardianModeOptional,
    required this.testMode,
    this.action,
    this.retryAfter,
    this.policyVersion,
  });

  factory MarketplaceTrustEligibility.fromMap(Map<String, dynamic> map) {
    return MarketplaceTrustEligibility(
      allowed: map['allowed'] == true,
      action: map['action'] as String?,
      requiredLevel: _integer(map['required_level']),
      currentLevel: _integer(map['current_level']),
      missingRequirements: _strings(map['missing_requirements']),
      reasonCodes: _strings(map['reason_codes']),
      retryAfter: map['retry_after'] as String?,
      supportRoute: _text(
        map['support_route'],
        fallback: '/support/account-trust',
      ),
      policyVersion: _nullableInteger(map['policy_version']),
      productionMarketplaceEnabled:
          map['production_marketplace_enabled'] == true,
      guardianModeOptional: map['guardian_mode_optional'] != false,
      testMode: map['test_mode'] == true,
    );
  }

  final bool allowed;
  final String? action;
  final int requiredLevel;
  final int currentLevel;
  final List<String> missingRequirements;
  final List<String> reasonCodes;
  final String? retryAfter;
  final String supportRoute;
  final int? policyVersion;
  final bool productionMarketplaceEnabled;
  final bool guardianModeOptional;
  final bool testMode;
}

class AccountTrustProfile {
  const AccountTrustProfile({
    required this.currentLevel,
    required this.levelKey,
    required this.levelTitle,
    required this.signalEnvironment,
    required this.indicators,
    required this.contactStatus,
    required this.accountSecurity,
    required this.identityStatus,
    required this.marketplaceEligibility,
    required this.riskProfile,
    required this.availability,
    required this.guardianModeOptional,
    required this.schoolNamePublicByDefault,
    required this.residentialAddressPublic,
    required this.emailOrPhonePublic,
    required this.peopleSearchUsed,
    required this.safetyGuarantee,
    required this.policyVersion,
    this.calculatedAt,
  });

  factory AccountTrustProfile.fromMap(Map<String, dynamic> map) {
    return AccountTrustProfile(
      currentLevel: _integer(map['current_level']),
      levelKey: _text(map['level_key'], fallback: 'TRUST_LEVEL_0'),
      levelTitle: _text(map['level_title'], fallback: 'Basic account'),
      signalEnvironment: _text(
        map['signal_environment'],
        fallback: 'production',
      ),
      indicators: _maps(map['indicators']).map(TrustIndicator.fromMap).toList(),
      contactStatus: _map(map['contact_status']),
      accountSecurity: _map(map['account_security']),
      identityStatus: _text(
        map['identity_status'],
        fallback: 'not_identity_verified',
      ),
      marketplaceEligibility: MarketplaceTrustEligibility.fromMap(
        _map(map['marketplace_eligibility']),
      ),
      riskProfile: _map(map['risk_profile']),
      availability: _map(map['availability']),
      guardianModeOptional: map['guardian_mode_optional'] != false,
      schoolNamePublicByDefault: map['school_name_public_by_default'] == true,
      residentialAddressPublic: map['residential_address_public'] == true,
      emailOrPhonePublic: map['email_or_phone_public'] == true,
      peopleSearchUsed: map['people_search_used'] == true,
      safetyGuarantee: map['safety_guarantee'] == true,
      policyVersion: _integer(map['policy_version']),
      calculatedAt: map['calculated_at'] as String?,
    );
  }

  final int currentLevel;
  final String levelKey;
  final String levelTitle;
  final String signalEnvironment;
  final List<TrustIndicator> indicators;
  final Map<String, dynamic> contactStatus;
  final Map<String, dynamic> accountSecurity;
  final String identityStatus;
  final MarketplaceTrustEligibility marketplaceEligibility;
  final Map<String, dynamic> riskProfile;
  final Map<String, dynamic> availability;
  final bool guardianModeOptional;
  final bool schoolNamePublicByDefault;
  final bool residentialAddressPublic;
  final bool emailOrPhonePublic;
  final bool peopleSearchUsed;
  final bool safetyGuarantee;
  final int policyVersion;
  final String? calculatedAt;

  AccountTrustLevel get level => AccountTrustLevel.fromValue(currentLevel);
  bool get passkeysEnabledByServer =>
      accountSecurity['passkeys_enabled_by_server'] == true;
  bool get productionMarketplaceEnabled =>
      availability['production_marketplace_enabled'] == true;
  bool get providerIdentityAvailable =>
      availability['provider_identity_available'] == true;
  bool get appleWalletEnabled => availability['apple_wallet_enabled'] == true;
  bool get androidDigitalCredentialsEnabled =>
      availability['android_digital_credentials_enabled'] == true;
}

Map<String, dynamic> _map(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

List<Map<String, dynamic>> _maps(dynamic value) {
  return value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];
}

List<String> _strings(dynamic value) {
  return value is List ? value.whereType<String>().toList() : <String>[];
}

int _integer(dynamic value) => _nullableInteger(value) ?? 0;

int? _nullableInteger(dynamic value) => value is num ? value.toInt() : null;

String _text(dynamic value, {required String fallback}) {
  return value is String && value.trim().isNotEmpty ? value : fallback;
}
