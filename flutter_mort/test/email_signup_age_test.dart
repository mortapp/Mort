import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/utils/date_of_birth.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'email signup validates strict calendar dates and the 13th birthday',
    () {
      final today = DateTime.utc(2026, 11, 22);
      final birthday = DateOfBirthRules.validateForSignup(
        '11/22/2013',
        today: today,
      );
      expect(DateOfBirthParser.toIsoDate(birthday.date!), '2013-11-22');
      for (final value in [
        null,
        '',
        '11/23/2013',
        '02/29/2011',
        '01/01/2027',
      ]) {
        expect(
          DateOfBirthRules.validateForSignup(value, today: today).isValid,
          isFalse,
        );
      }
    },
  );

  test('signup checks age before sending ISO date metadata to Auth', () {
    final source = File(
      'lib/data/repositories/auth_repository.dart',
    ).readAsStringSync();
    final validate = source.indexOf('DateOfBirthRules.validateForSignup');
    final signup = source.indexOf('client.auth.signUp');
    final metadata = source.indexOf(
      "data: {'date_of_birth': DateOfBirthParser.toIsoDate(validatedDate)}",
    );
    expect(validate, greaterThanOrEqualTo(0));
    expect(signup, greaterThan(validate));
    expect(metadata, greaterThan(signup));
  });

  testWidgets('date of birth is requested on signup but not sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
        ),
      ),
    );
    expect(find.text('Date of birth (MM/DD/YYYY)'), findsOneWidget);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: UnifiedAuthScreen())),
    );
    expect(find.text('Date of birth (MM/DD/YYYY)'), findsNothing);
  });
}
