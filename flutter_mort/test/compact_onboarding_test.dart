import 'package:flutter/material.dart';
import 'package:flutter_mort/core/widgets/date_of_birth_field.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_mort/features/onboarding/compact_onboarding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact onboarding renders five steps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CompactOnboardingScreen())),
    );

    expect(find.text('Setup — 1 of 5'), findsOneWidget);
    expect(
      find.text('Enter your date of birth to determine eligibility.'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.byType(DateOfBirthField), findsOneWidget);
    expect(find.text('Age must be 13 or older'), findsNothing);
  });

  testWidgets('auth screens expose versioned legal acknowledgement links', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignInScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Terms'), findsWidgets);
    expect(find.textContaining('Privacy Policy'), findsWidgets);
    expect(find.byType(CheckboxListTile), findsWidgets);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignUpScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Terms'), findsWidgets);
    expect(find.textContaining('Privacy Policy'), findsWidgets);
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });
}
