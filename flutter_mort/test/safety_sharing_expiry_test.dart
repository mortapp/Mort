import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/safety/safety_sharing_countdown.dart';

void main() {
  testWidgets('Sharing display expires locally without awaiting another RPC', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 27);
    await tester.pumpWidget(
      MaterialApp(
        home: SafetySharingCountdown(
          expiresAt: now.add(const Duration(seconds: 2)),
          now: () => now,
        ),
      ),
    );
    expect(find.text('Live sharing: 0:02 remaining'), findsOneWidget);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Live sharing: Off'), findsOneWidget);
    expect(find.textContaining('remaining'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
