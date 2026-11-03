import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shipping Flutter assets do not include the retired rose raster', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('mort_arrow_rose_gold.png')));
  });

  test('auth presentation never renders an internal policy version', () {
    final auth = File(
      'lib/features/auth/unified_auth_screen.dart',
    ).readAsStringSync();
    expect(auth, isNot(contains(r'$mortOnboardingAcknowledgementVersion')));
  });

  test('Google auth button uses Rork styling not Material white', () {
    final googleAuth = File(
      'lib/features/auth/google_auth_screens.dart',
    ).readAsStringSync();
    expect(googleAuth, contains('MortColors.cardAlt'));
    expect(googleAuth, contains('MortColors.text'));
    expect(googleAuth, contains('MortColors.borderSilver'));
    expect(googleAuth, isNot(contains('Colors.white')));
  });

  test('Google button shows correct text for Sign In vs Sign Up', () {
    final googleAuth = File(
      'lib/features/auth/google_auth_screens.dart',
    ).readAsStringSync();
    expect(googleAuth, contains('Continue with Google'));
    expect(googleAuth, contains('Sign up with Google'));
    expect(googleAuth, contains('signUp'));
  });
}
