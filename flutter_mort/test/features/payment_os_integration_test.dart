import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_mort/features/history/screens/job_payment_history_screen.dart';
import 'package:flutter_mort/features/history/models/payment_history.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_mort/features/payments/models/fair_pay.dart';
import 'package:flutter_mort/features/payments/screens/payment_review_screen.dart';
import 'package:flutter_mort/features/payments/widgets/fair_pay_panel.dart';
import 'package:flutter_mort/features/payments/widgets/payment_state_panel.dart';
import 'package:flutter_mort/features/receipts/screens/receipt_detail_screen.dart';

void main() {
  testWidgets('Settings reaches Job & payment history and back', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/settings/payment-history',
          builder: (_, _) => const JobPaymentHistoryScreen(),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.ensureVisible(find.text('Job & payment history'));
    await tester.tap(find.text('Job & payment history'));
    await tester.pumpAndSettle();
    expect(find.text('Job & payment history'), findsOneWidget);
    expect(find.text('No payment activity'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Control your account'), findsOneWidget);
  });

  testWidgets(
    'history preserves controls and distinguishes attempts without receipts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobPaymentHistoryScreen(
            entries: [
              MortPaymentHistoryEntry(
                id: 'failed',
                title: 'Declined job',
                occurredAt: '2026-09-15T12:00:00Z',
                status: MortPaymentState.declined,
                amountCents: 125075,
                kind: MortPaymentHistoryKind.payment,
              ),
            ],
          ),
        ),
      );
      expect(find.text('NO RECEIPT ISSUED'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump();
      expect(find.text('No matching activity'), findsOneWidget);
    },
  );

  testWidgets(
    'payment review exposes tip selector and authoritative review rows',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PaymentReviewScreen(basePayCents: 125075, serviceFeeCents: 500),
        ),
      );
      expect(find.text('BASE PAY'), findsOneWidget);
      expect(find.text('MORT SERVICE FEE'), findsOneWidget);
      expect(find.text('No tip'), findsOneWidget);
      await tester.tap(find.text(r'$5'));
      await tester.pump();
      expect(find.text(r'$5'), findsOneWidget);
    },
  );

  testWidgets('all payment states render without offering unsafe actions', (
    tester,
  ) async {
    for (final state in MortPaymentState.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MortPaymentStatePanel(state: state)),
        ),
      );
      expect(find.text(state.label), findsOneWidget);
      expect(find.bySemanticsLabel(state.semanticLabel), findsOneWidget);
    }
  });

  testWidgets('red Fair Pay renders a blocked policy warning', (tester) async {
    const assessment = MortFairPayAssessment(
      recommendedRangeCents: RangeValues(2000, 3000),
      hardMinimumCents: 1500,
      actualCents: 1200,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MortFairPayPanel(assessment: assessment)),
      ),
    );
    expect(find.text('RED'), findsOneWidget);
    expect(
      find.text(
        'This amount is below MORT’s hard minimum. Increase base pay before posting.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'receipt route without an authoritative document stays fail-closed',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ReceiptDetailScreen(receiptNumber: 'R-123')),
      );
      expect(find.text('Receipt backend unavailable'), findsOneWidget);
      expect(
        find.text(
          'MORT cannot resolve receipt R-123 from an authorized receipt backend.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('new payment UI remains usable at compact width and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PaymentReviewScreen(basePayCents: 2200, serviceFeeCents: 176),
        ),
      ),
    );
    expect(find.byType(PaymentReviewScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('financial reads stay behind authenticated Edge adapters', () {
    final source = File(
      'lib/data/repositories/stripe_marketplace_repository.dart',
    ).readAsStringSync();
    expect(source, contains("'stripe-list-financial-history'"));
    expect(source, contains("'stripe-get-financial-document'"));
    expect(source, isNot(contains("'get_my_financial_history_v1'")));
    expect(source, isNot(contains("'get_my_financial_document_v1'")));
  });
}
