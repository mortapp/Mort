import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    '${Directory.current.path}/lib/features/mort_screens.dart',
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

  test('the anti-grooming rule is explicit and required to continue', () {
    expect(source, contains('_antiGroomingAcknowledged'));
    expect(source, contains('zero tolerance for adults who target, groom'));
    expect(source, contains('preserve account, device, and IP evidence'));
    expect(source, contains('to law enforcement'));
    expect(source, contains('does not support and will never protect'));
    expect(source, contains('Report or Safety Ping -- reporting never'));
    // The new checkbox is a hard requirement, not decorative -- it must
    // gate the same _allAcknowledged flag the Finish button checks.
    expect(
      source,
      contains('_safetyRules &&\n      _antiGroomingAcknowledged;'),
    );
  });
}
