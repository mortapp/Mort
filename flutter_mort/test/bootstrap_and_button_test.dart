import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup failure renders an honest retry action', (tester) async {
    var attempts = 0;
    Future<void> initialize() async {
      attempts++;
      throw StateError('offline');
    }

    await tester.pumpWidget(
      ProviderScope(child: MortBootstrap(initialize: initialize)),
    );
    await tester.pumpAndSettle();

    expect(find.text('MORT could not start'), findsOneWidget);
    expect(find.text('Retry startup'), findsOneWidget);
    await tester.tap(find.text('Retry startup'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('startup waits for initialization before rendering app', (
    tester,
  ) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(child: MortBootstrap(initialize: () => completer.future)),
    );

    expect(find.text('Restoring your session...'), findsOneWidget);
    expect(completer.isCompleted, isFalse);
    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Earn nearby. Move smart.'), findsOneWidget);
  });

  testWidgets('busy button prevents repeat taps and shows progress', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MortButton(
            label: 'Submit',
            busyLabel: 'Submitting...',
            busy: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Submitting...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Submitting...'));
    expect(taps, 0);
  });
}
