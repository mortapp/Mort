import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    '${Directory.current.path}/lib/features/mort_screens.dart',
  ).readAsStringSync();
  final rulesCopy = File(
    '${Directory.current.path}/lib/features/onboarding/mort_rules_copy.dart',
  ).readAsStringSync();
  final compactOnboarding = File(
    '${Directory.current.path}/lib/features/onboarding/compact_onboarding.dart',
  ).readAsStringSync();
  final safety = File(
    '${Directory.current.path}/lib/features/safety/trust_safety_screens.dart',
  ).readAsStringSync();
  final permissions = File(
    '${Directory.current.path}/lib/features/settings/native_permissions_screen.dart',
  ).readAsStringSync();
  final safetyStart = source.indexOf('class _SafetyRulesScreenState');
  final safetyEnd = source.indexOf('\nclass ', safetyStart + 1);
  final legacySafety = source.substring(
    safetyStart,
    safetyEnd < 0 ? source.length : safetyEnd,
  );

  test(
    'legacy safety widget records legal acceptance through the supported RPC',
    () {
      // The legacy screen is not routed in production, but remains test- and
      // deep-link-reachable; it must still use exact server-issued versions.
      expect(legacySafety, contains('legalContractRepositoryProvider'));
      expect(legacySafety, contains('.legalRequirements()'));
      expect(legacySafety, contains('await legalRepo.acceptLegalVersion('));
      expect(legacySafety, contains("legalResponse['ok'] != true"));
      expect(legacySafety, contains("item['required'] == true"));
      expect(
        legacySafety,
        contains("item['acceptance_id'] == null"),
        reason: 'must only accept outstanding, not-yet-accepted versions',
      );
      expect(legacySafety, contains("item['version_id']"));
      expect(
        legacySafety,
        isNot(contains('.recordOnboardingAcknowledgement(')),
      );
      expect(legacySafety, isNot(contains('.saveOnboardingProgress(')));
    },
  );

  test(
    'four-step onboarding submits exact outstanding versions through the completion RPC',
    () {
      // Flutter records each required current document using its exact
      // server-issued version ID before asking v2 to complete onboarding.
      expect(compactOnboarding, contains('legalContractRepositoryProvider'));
      expect(compactOnboarding, contains('.legalRequirements()'));
      expect(compactOnboarding, contains("legalResponse['ok'] != true"));
      expect(compactOnboarding, contains("item['required'] == true"));
      expect(compactOnboarding, contains("item['acceptance_id'] == null"));
      expect(
        compactOnboarding,
        contains('await legalRepo.acceptLegalVersion('),
      );
      expect(compactOnboarding, contains("item['version_id']"));
      expect(compactOnboarding, contains("'legal_version_ids': outstanding"));
      expect(compactOnboarding, contains('.completeOnboardingV2('));
      expect(
        compactOnboarding,
        isNot(contains('.recordOnboardingAcknowledgement(')),
      );
      expect(compactOnboarding, isNot(contains('.completeOnboarding()')));
    },
  );

  test(
    'the anti-grooming rule text has one single source of truth for both screens',
    () {
      // Both SafetyRulesScreen and CompactOnboardingScreen must reference
      // the same MortRulesCopy constants rather than each carrying their
      // own copy of this legal-adjacent wording, which could otherwise
      // drift apart silently on a future edit to just one of them.
      expect(source, contains('MortRulesCopy.antiGroomingTitle'));
      expect(source, contains('MortRulesCopy.antiGroomingBody'));
      expect(source, contains('MortRulesCopy.pilotTermsTitle'));
      expect(source, contains('MortRulesCopy.privacyTitle'));
      expect(source, contains('MortRulesCopy.communityTitle'));
      expect(source, contains('MortRulesCopy.prohibitedTitle'));
      expect(source, contains('MortRulesCopy.safetyRulesTitle'));
      expect(compactOnboarding, contains('MortRulesCopy.antiGroomingTitle'));
      expect(compactOnboarding, contains('MortRulesCopy.antiGroomingBody'));

      expect(
        rulesCopy,
        contains('zero tolerance for adults who target, groom'),
      );
      expect(rulesCopy, contains('preserve account, device, and IP evidence'));
      expect(rulesCopy, contains('to law enforcement'));
      expect(rulesCopy, contains('does not support and will never protect'));
      expect(rulesCopy, contains('Report or Safety Ping -- reporting never'));
    },
  );

  test('the anti-grooming checkbox is a hard requirement on both screens', () {
    expect(source, contains('_antiGroomingAcknowledged'));
    expect(
      source,
      contains('_safetyRules &&\n      _antiGroomingAcknowledged;'),
    );
    expect(compactOnboarding, contains('_antiGroomingAcknowledged'));
  });

  test('safety surfaces use restrained monochrome state colors', () {
    expect(safety, isNot(contains('MortColors.neon')));
    expect(safety, isNot(contains('MortColors.roseGold')));
    expect(permissions, isNot(contains('MortColors.neon')));
    expect(permissions, isNot(contains('MortColors.roseGold')));
  });
}
