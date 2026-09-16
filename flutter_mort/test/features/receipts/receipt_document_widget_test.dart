import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/receipts/models/receipt_document.dart';
import 'package:flutter_mort/features/receipts/widgets/receipt_document_view.dart';

void main() {
  group('receipt document widget', () {
    testWidgets('renders all required receipt types and semantics', (
      tester,
    ) async {
      const document = MortReceiptDocument(
        receiptType: MortReceiptType.adultJobPayment,
        status: MortReceiptStatus.approved,
        orderNumber: '0042',
        receiptNumber: 'K-260915-04827',
        occurredAt: '2026-09-15T18:42:00Z',
        jobTitle: 'Lawn Mowing',
        serviceSummaryLines: [
          'Front + backyard mowing',
          'Bagged clippings included',
        ],
        payerHandle: '@verylongusername',
        workerHandle: '@michael',
        currencyCode: 'USD',
        lineItems: [
          MortReceiptLineItem(label: 'BASE JOB PAY', amountCents: 2200),
          MortReceiptLineItem(label: 'TIP', amountCents: 500),
          MortReceiptLineItem(label: 'MORT SERVICE FEE', amountCents: 176),
        ],
        authoritativeTotalCents: 2876,
        maskedPaymentMethod: '•••• 4242',
        maskedTransactionReference: 'ch_••••4242',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: MortReceiptDocumentView(document: document)),
          ),
        ),
      );

      expect(find.text('MORT'), findsOneWidget);
      expect(find.text('GET IN MOTION'), findsOneWidget);
      expect(find.text('JOB PAYMENT RECEIPT'), findsOneWidget);
      expect(find.text('ORDER # 0042'), findsOneWidget);
      expect(find.text('RECEIPT # K-260915-04827'), findsOneWidget);
      expect(find.text('Front + backyard mowing'), findsOneWidget);
      expect(find.text('Bagged clippings included'), findsOneWidget);
      expect(find.text('TOTAL PAID'), findsOneWidget);
      expect(find.text('•••• 4242'), findsOneWidget);
      expect(find.text('ch_••••4242'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Adult job payment receipt')),
        findsOneWidget,
      );
    });

    testWidgets('supports compact width and 200% text scale without overflow', (
      tester,
    ) async {
      const document = MortReceiptDocument(
        receiptType: MortReceiptType.teenEarnings,
        status: MortReceiptStatus.credited,
        orderNumber: '0042',
        receiptNumber: 'K-260915-04827',
        occurredAt: '2026-09-15T18:42:00Z',
        jobTitle:
            'Very long title that should still wrap on mobile and stay readable',
        serviceSummaryLines: [
          'Long multiline service summary to validate scaling and wrapping',
        ],
        payerHandle: '@veryverylongpayerhandle',
        workerHandle: '@veryverylongworkerhandle',
        lineItems: [
          MortReceiptLineItem(label: 'BASE EARNINGS', amountCents: 125075),
          MortReceiptLineItem(label: 'TIP', amountCents: 2500),
          MortReceiptLineItem(label: 'MORT DEDUCTION', amountCents: 10000),
          MortReceiptLineItem(label: 'NET EARNINGS', amountCents: 120575),
        ],
        authoritativeTotalCents: 120575,
      );

      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: MortReceiptDocumentView(document: document)),
            ),
          ),
        ),
      );

      expect(find.text('TEEN EARNINGS RECEIPT'), findsOneWidget);
      expect(find.text('NET EARNINGS'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders linked late tip and refund documents distinctly', (
      tester,
    ) async {
      const tipDocument = MortReceiptDocument(
        receiptType: MortReceiptType.lateTip,
        status: MortReceiptStatus.credited,
        orderNumber: '0042',
        receiptNumber: 'TIP-1001',
        occurredAt: '2026-09-16T09:00:00Z',
        jobTitle: 'Late tip',
        serviceSummaryLines: ['Thank you for the extra support'],
        payerHandle: '@marcus',
        workerHandle: '@michael',
        lineItems: [MortReceiptLineItem(label: 'TIP AMOUNT', amountCents: 400)],
        authoritativeTotalCents: 400,
        linkedReceiptNumber: 'K-260915-04827',
      );
      const refundDocument = MortReceiptDocument(
        receiptType: MortReceiptType.fullRefund,
        status: MortReceiptStatus.refunded,
        orderNumber: '0042',
        receiptNumber: 'REF-1002',
        occurredAt: '2026-09-17T10:00:00Z',
        jobTitle: 'Refund',
        serviceSummaryLines: ['Customer cancelled job before start'],
        payerHandle: '@marcus',
        workerHandle: '@michael',
        lineItems: [MortReceiptLineItem(label: 'REFUND', amountCents: 2200)],
        authoritativeTotalCents: 2200,
        linkedReceiptNumber: 'K-260915-04827',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MortReceiptDocumentView(document: tipDocument),
                  const SizedBox(height: 12),
                  MortReceiptDocumentView(document: refundDocument),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('LATE TIP RECEIPT'), findsOneWidget);
      expect(find.text('REFUND RECEIPT'), findsOneWidget);
      expect(find.textContaining('K-260915-04827'), findsAtLeastNWidgets(2));
    });
  });
}
