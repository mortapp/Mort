import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/safety/safety_contact_call.dart';
import 'package:flutter_mort/features/safety/staff_safety_context_button.dart';

void main() {
  testWidgets(
    'Staff context requires a reason and closes without disposed controller errors',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await requestSafetyReviewReason(
                    context,
                    'Review private evidence',
                  );
                },
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'short');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Enter at least 10 characters.'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(
        find.byType(TextField),
        'Reviewing evidence for this assigned case.',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(result, 'Reviewing evidence for this assigned case.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Known contact call refuses dialer service codes and does not save a number',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    openKnownSafetyContactCall(context, 'Guardian'),
                child: const Text('Call guardian'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Call guardian'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '*1234567#');
      await tester.tap(find.text('Open Phone Call'));
      await tester.pump();
      expect(find.text('Enter a complete phone number.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Call guardian'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
