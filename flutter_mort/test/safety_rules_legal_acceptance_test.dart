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
  final legalScreens = File(
    '${Directory.current.path}/lib/features/legal/legal_screens.dart',
  ).readAsStringSync();
  final legalRepository = File(
    '${Directory.current.path}/lib/data/repositories/legal_contract_repository.dart',
  ).readAsStringSync();

  test(
    'the real reachable onboarding safety step actually records legal acceptance',
    () {
      // Before this fix, no screen in the live sign-up flow ever called
      // acceptLegalVersion / submit_legal_acceptance, so
      // complete_my_onboarding()'s published_legal_acceptance_required gate
      // could never be satisfied by a real new user.
      expect(source, contains('legalContractRepositoryProvider'));
      expect(source, contains('.legalRequirements()'));
      expect(source, contains('.acceptLegalVersion('));
      expect(
        source,
        contains("item['acceptance_id'] == null"),
        reason: 'must only accept outstanding, not-yet-accepted versions',
      );
      // Legal acceptance is recorded before the acknowledgement/progress
      // save, not after, so a failure here correctly blocks completion.
      final acceptIndex = source.indexOf('.acceptLegalVersion(');
      final acknowledgementIndex = source.indexOf(
        '.recordOnboardingAcknowledgement(',
      );
      expect(acceptIndex, greaterThan(0));
      expect(acknowledgementIndex, greaterThan(acceptIndex));
    },
  );

  test('four-step onboarding gates completion on exact legal acceptances', () {
    // The existing Legal Center clickwrap records each exact version and
    // content hash. Onboarding must send users there and fail closed until
    // the live requirements RPC reports no outstanding acceptance.
    expect(compactOnboarding, contains('legalContractRepositoryProvider'));
    expect(compactOnboarding, contains('.legalRequirements()'));
    expect(compactOnboarding, contains("item['acceptance_id'] == null"));
    expect(compactOnboarding, contains("context.push('/legal-center')"));
    expect(compactOnboarding, contains('if (outstanding.isNotEmpty)'));
    expect(compactOnboarding, contains('.completeOnboardingV2('));
    expect(legalScreens, contains(".acceptLegalVersion("));
    expect(legalRepository, contains("'p_document_version_id': versionId"));
    final guardIndex = compactOnboarding.indexOf('if (outstanding.isNotEmpty)');
    final completionIndex = compactOnboarding.indexOf('.completeOnboardingV2(');
    expect(guardIndex, greaterThan(0));
    expect(completionIndex, greaterThan(guardIndex));
    expect(compactOnboarding, isNot(contains('.completeOnboarding()')));
  });

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
