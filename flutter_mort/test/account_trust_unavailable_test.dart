import 'package:flutter/material.dart';
import 'package:flutter_mort/core/errors/mort_error.dart';
import 'package:flutter_mort/data/repositories/account_trust_repository.dart';
import 'package:flutter_mort/features/trust/account_trust_screens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'missing production trust RPCs fail locally without a backend call',
    () async {
      final repository = AccountTrustRepository();
      final unavailable = isA<MortCodedError>().having(
        (error) => error.code,
        'code',
        'account_trust_unavailable',
      );

      await expectLater(repository.getMyProfile(), throwsA(unavailable));
      await expectLater(repository.getEligibility(), throwsA(unavailable));
      await expectLater(
        repository.requestSchoolAffiliation('student@example.edu'),
        throwsA(unavailable),
      );
    },
  );

  testWidgets('account trust screen says status is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AccountTrustScreen()));

    expect(find.text('Trust status unavailable'), findsOneWidget);
    expect(
      find.textContaining('No account-trust status was loaded or verified.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('school affiliation screen cannot submit or claim success', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SchoolEmailVerificationScreen()),
    );

    expect(find.text('School affiliation unavailable'), findsOneWidget);
    expect(
      find.textContaining(
        'No request was submitted and no school affiliation was confirmed.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Check approved domain'), findsNothing);
  });
}
