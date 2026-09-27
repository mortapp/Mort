import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/safety/emergency_panel.dart';

void main() {
  testWidgets('Calling remains available without teen alert authority', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmergencyPanel(
            canSendContacts: false,
            onAlert: () async => throw StateError('must not run'),
            onShare: () async => throw StateError('must not run'),
            onCallEmergency: () async {
              calls++;
            },
          ),
        ),
      ),
    );
    expect(find.text('Alert My Safety Contacts'), findsNothing);
    expect(find.text('Share Live Location'), findsNothing);
    await tester.tap(find.text('Call 911'));
    await tester.pump();
    expect(calls, 1);
  });
  testWidgets(
    'Opening Emergency sends nothing and keeps native call available',
    (tester) async {
      var alerts = 0;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmergencyPanel(
              onAlert: () async {
                alerts++;
                return const SafetyActionReceipt(
                  guardianQueued: 1,
                  trustedQueued: 1,
                );
              },
              onCallEmergency: () async {
                calls++;
              },
              onShare: () async => const SafetyActionReceipt(),
            ),
          ),
        ),
      );
      expect(alerts, 0);
      expect(find.text('Need help?'), findsOneWidget);
      await tester.tap(find.text('Call 911'));
      await tester.pump();
      expect(calls, 1);
      expect(alerts, 0);
      await tester.tap(find.text('Alert My Safety Contacts'));
      await tester.pump();
      expect(alerts, 1);
      expect(find.textContaining('Guardian: queued'), findsOneWidget);
      expect(find.textContaining('Trusted contact: queued'), findsOneWidget);
      expect(find.text('Guardian notified'), findsNothing);
    },
  );
  testWidgets('Pending alert cannot disable emergency call or claim delivery', (
    tester,
  ) async {
    final pending = Completer<SafetyActionReceipt>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmergencyPanel(
            onAlert: () => pending.future,
            onCallEmergency: () async {
              calls++;
            },
            onShare: () async => const SafetyActionReceipt(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Alert My Safety Contacts'));
    await tester.pump();
    expect(find.text('Safety alert waiting to send'), findsOneWidget);
    await tester.tap(find.text('Call 911'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Safety alert recorded'), findsNothing);
    pending.completeError(StateError('Connection lost'));
    await tester.pump();
    expect(find.textContaining('not confirmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Small Emergency panel with large text scrolls every critical action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: EmergencyPanel(
                onAlert: () async => const SafetyActionReceipt(),
                onCallEmergency: () async {},
                onShare: () async => const SafetyActionReceipt(),
                onLeave: () async {},
              ),
            ),
          ),
        ),
      );
      for (final label in [
        'Alert My Safety Contacts',
        'Call 911',
        'Leave This Job',
        'Share Live Location',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        expect(find.text(label).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
