import 'package:flutter_mort/data/models/account_trust.dart';
import 'package:flutter_mort/services/passkey_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parses precise trust profile without converting affiliation to identity',
    () {
      final profile = AccountTrustProfile.fromMap({
        'ok': true,
        'current_level': 2,
        'level_key': 'TRUST_LEVEL_2',
        'level_title': 'Affiliation verified',
        'signal_environment': 'sandbox',
        'indicators': [
          {
            'key': 'school_affiliation',
            'category': 'affiliation',
            'label': 'TEST MODE: School affiliation verified',
            'status': 'verified',
            'what_was_checked': 'Access to an approved sandbox school domain.',
            'what_was_not_checked':
                'Government identity, age, enrollment, and safety.',
            'grants_marketplace_access': false,
            'does_not_guarantee_safety': true,
            'environment': 'sandbox',
          },
        ],
        'contact_status': {
          'email_verified': true,
          'phone_verified': false,
          'email_or_phone_is_legal_identity': false,
        },
        'account_security': {
          'passkey_count': 0,
          'passkeys_enabled_by_server': false,
          'device_biometrics_are_local_account_security_only': true,
        },
        'identity_status': 'not_identity_verified',
        'marketplace_eligibility': {
          'allowed': false,
          'required_level': 4,
          'current_level': 2,
          'missing_requirements': ['approved_production_marketplace_policy'],
          'reason_codes': ['production_marketplace_closed'],
          'support_route': '/support/account-trust',
          'production_marketplace_enabled': false,
          'guardian_mode_optional': true,
          'test_mode': true,
        },
        'risk_profile': {
          'risk_level': 'low',
          'risk_reasons': <String>[],
          'recommended_action': 'none',
          'human_review_required': false,
          'not_a_criminal_accusation': true,
        },
        'availability': {
          'production_marketplace_enabled': false,
          'identity_document_collection_enabled': false,
          'provider_identity_available': false,
          'apple_wallet_enabled': false,
          'android_digital_credentials_enabled': false,
        },
        'guardian_mode_optional': true,
        'school_name_public_by_default': false,
        'residential_address_public': false,
        'email_or_phone_public': false,
        'people_search_used': false,
        'safety_guarantee': false,
        'policy_version': 1,
      });

      expect(profile.level, AccountTrustLevel.affiliation);
      expect(profile.identityStatus, 'not_identity_verified');
      expect(profile.marketplaceEligibility.allowed, isFalse);
      expect(profile.productionMarketplaceEnabled, isFalse);
      expect(profile.indicators.single.grantsMarketplaceAccess, isFalse);
      expect(profile.indicators.single.doesNotGuaranteeSafety, isTrue);
      expect(profile.schoolNamePublicByDefault, isFalse);
      expect(profile.residentialAddressPublic, isFalse);
      expect(profile.peopleSearchUsed, isFalse);
    },
  );

  test('non-web passkey detector reports no browser ceremony', () async {
    final capability = await detectPasskeyCapability();

    expect(capability.browserApiAvailable, isFalse);
    expect(capability.canUseBrowserPasskeys, isFalse);
  });
}
