import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary teen destinations use open headers instead of hero cards', () {
    final shell = File('lib/features/teen/teen_shell.dart').readAsStringSync();

    expect(shell, contains('return MortHeader('));
    expect(shell, isNot(contains('return MortGlassHeader(')));
  });

  test('primary product surfaces select the approved atmosphere strength', () {
    final screens = File('lib/features/mort_screens.dart').readAsStringSync();
    final profile = File(
      'lib/features/teen/teen_profile_screen.dart',
    ).readAsStringSync();

    expect(
      screens,
      contains(
        'class _MessagesScreenState extends ConsumerState<MessagesScreen>',
      ),
    );
    expect(
      screens,
      contains('atmosphereIntensity: MortAtmosphereIntensity.midnight'),
    );
    expect(profile, contains('MortAtmosphereIntensity.quiet'));
  });

  test('onboarding guidance is open content rather than another card', () {
    final onboarding = File(
      'lib/features/onboarding/compact_onboarding.dart',
    ).readAsStringSync();
    final noticeStart = onboarding.indexOf('class _OnboardingNotice');
    final dividerStart = onboarding.indexOf('class _OnboardingDivider');
    final noticeSource = onboarding.substring(noticeStart, dividerStart);

    expect(noticeSource, isNot(contains('MortCard(')));
  });
}
