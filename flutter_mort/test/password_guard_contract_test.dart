import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/auth/password_guard.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  group('password-guard error mapping', () {
    test('server codes map to specific user-facing messages', () {
      expect(
        PasswordGuard.errorFor({'code': 'leaked_password_compromised'}).message,
        contains('public data breach'),
      );
      expect(
        PasswordGuard.errorFor({'code': 'password_too_short'}).message,
        'Use at least 12 characters.',
      );
      final unavailable = PasswordGuard.errorFor({
        'code': 'leaked_password_check_unavailable',
      });
      expect(unavailable.code, 'leaked_password_check_unavailable');
      expect(unavailable.message, contains('Try again'));
      expect(
        PasswordGuard.errorFor({'code': 'dob_under_minimum_age'}).message,
        'An account cannot be created for someone under 13.',
      );
    });

    test('unknown failures do not leak raw server text', () {
      final error = PasswordGuard.errorFor('<html>', status: 502);
      expect(error.code, 'password_guard_failed');
      expect(error.message, isNot(contains('<html>')));
    });
  });

  group('sign-up date of birth', () {
    final today = DateTime(2026, 11, 16);
    test('requires a full, real, past date', () {
      expect(signUpDateOfBirthError('', today: today), isNotNull);
      expect(signUpDateOfBirthError('02/30/2010', today: today), isNotNull);
      expect(signUpDateOfBirthError('01/01/2030', today: today), isNotNull);
    });
    test('blocks under-13 and accepts 13+', () {
      expect(
        signUpDateOfBirthError('11/17/2013', today: today),
        'An account cannot be created for someone under 13.',
      );
      expect(signUpDateOfBirthError('11/16/2013', today: today), isNull);
      expect(signUpDateOfBirthError('05/17/1990', today: today), isNull);
    });
  });

  test('no client code sets passwords outside password-guard', () {
    // The database rejects password writes without a password-guard
    // attestation, so direct Auth calls would fail at runtime.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (RegExp(r'auth\s*\.\s*signUp\(').hasMatch(source) ||
          RegExp(r'UserAttributes\([^)]*password\s*:').hasMatch(source)) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
    final repo = File(
      'lib/data/repositories/auth_repository.dart',
    ).readAsStringSync();
    expect(repo, contains('PasswordGuard(SupabaseService.client).signUp('));
    expect(repo, contains('.updatePassword(password)'));
    expect(repo, isNot(contains('LeakedPasswordCheck')));
  });

  testMortWidgets('sign-up collects date of birth before password', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: mortTestTheme(MortTheme.dark()),
          home: const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('signup-date-of-birth')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testMortWidgets('sign-in does not show the date of birth field', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: mortTestTheme(MortTheme.dark()),
          home: const UnifiedAuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('signup-date-of-birth')), findsNothing);
  });
}
