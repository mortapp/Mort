import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/payments/models/payment_state.dart';

void main() {
  group('payment state widgets', () {
    test('includes all required states', () {
      expect(
        MortPaymentState.values,
        containsAll([
          MortPaymentState.ready,
          MortPaymentState.processing,
          MortPaymentState.requiresAction,
          MortPaymentState.pending,
          MortPaymentState.succeeded,
          MortPaymentState.declined,
          MortPaymentState.failed,
          MortPaymentState.cancelled,
          MortPaymentState.unknown,
          MortPaymentState.providerUnavailable,
          MortPaymentState.duplicateBlocked,
        ]),
      );
    });

    testWidgets('exposes a clear semantic label and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MortPaymentStateBadge(state: MortPaymentState.succeeded),
            ),
          ),
        ),
      );

      expect(find.text('Succeeded'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Succeeded')).label,
        'Payment state Succeeded',
      );
    });

    testWidgets('keeps payment state legible at 200% scale', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: MortPaymentStateBadge(
                  state: MortPaymentState.requiresAction,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Requires action'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
