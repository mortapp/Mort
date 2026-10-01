import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/school_directory_entry.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/school_directory_repository.dart';
import 'package:flutter_mort/features/trust/account_trust_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSchoolVerification extends SchoolDirectoryRepository {
  int verifyCalls = 0;

  @override
  Future<List<SchoolDirectoryEntry>> search(String query) async => const [
    SchoolDirectoryEntry(
      id: 'school-a',
      officialName: 'Pike High School',
      displayName: 'Pike High School',
      city: 'Indianapolis',
      state: 'IN',
      schoolType: 'high_school',
    ),
  ];

  @override
  Future<bool> isEmailEligible({
    required String schoolId,
    required String email,
  }) async => email.toLowerCase() == 'teen@school.example';

  @override
  Future<Map<String, dynamic>> verifyCurrentEmail({
    required String schoolId,
    required String email,
  }) async {
    verifyCalls++;
    return {'ok': true, 'code': 'school_email_verified'};
  }
}

void main() {
  testWidgets(
    'school email screen rejects wrong domain and verifies selected school',
    (tester) async {
      final fake = _FakeSchoolVerification();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolDirectoryRepositoryProvider.overrideWithValue(fake),
          ],
          child: MaterialApp(
            theme: MortTheme.classic(),
            home: const SchoolEmailVerificationScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Find your school'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pike High School'));
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Change school'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'teen@gmail.com');
      await tester.tap(find.text('Verify school email'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not match a verified student domain'),
        findsOneWidget,
      );
      expect(fake.verifyCalls, 0);

      await tester.enterText(
        find.byType(TextField).first,
        'teen@school.example',
      );
      await tester.tap(find.text('Verify school email'));
      await tester.pumpAndSettle();
      expect(
        find.text('School email verified for Pike High School.'),
        findsOneWidget,
      );
      expect(fake.verifyCalls, 1);
    },
  );
}
