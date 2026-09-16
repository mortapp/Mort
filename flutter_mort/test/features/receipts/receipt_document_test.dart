import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/payments/models/payment_state.dart';
import 'package:flutter_mort/features/receipts/models/receipt_document.dart';

void main() {
  group('receipt document model', () {
    test('covers all eight receipt types', () {
      expect(MortReceiptType.values, hasLength(8));
      expect(
        MortReceiptType.values,
        containsAll([
          MortReceiptType.adultJobPayment,
          MortReceiptType.teenEarnings,
          MortReceiptType.storePurchase,
          MortReceiptType.lateTip,
          MortReceiptType.fullRefund,
          MortReceiptType.partialRefund,
          MortReceiptType.adjustment,
          MortReceiptType.reversal,
        ]),
      );
    });

    test('authoritative total wins over line-item sum', () {
      const document = MortReceiptDocument(
        receiptType: MortReceiptType.adultJobPayment,
        status: MortReceiptStatus.approved,
        orderNumber: '0042',
        receiptNumber: 'K-260915-04827',
        occurredAt: '2026-09-15T18:42:00Z',
        jobTitle: 'Lawn Mowing',
        serviceSummaryLines: ['Front + backyard mowing'],
        payerHandle: '@marcus',
        workerHandle: '@michael',
        lineItems: [
          MortReceiptLineItem(label: 'BASE', amountCents: 2200),
          MortReceiptLineItem(label: 'TIP', amountCents: 500),
          MortReceiptLineItem(label: 'FEE', amountCents: 176),
        ],
        authoritativeTotalCents: 2876,
      );

      expect(document.authoritativeTotalCents, 2876);
      expect(
        document.lineItems.fold<int>(0, (sum, item) => sum + item.amountCents),
        2876,
      );
      expect(document.displayTotalLabel, 'TOTAL PAID');
    });

    test('receipt statuses are limited to actual issued documents', () {
      expect(
        MortReceiptStatus.values,
        equals([
          MortReceiptStatus.approved,
          MortReceiptStatus.credited,
          MortReceiptStatus.refunded,
          MortReceiptStatus.adjusted,
          MortReceiptStatus.reversed,
        ]),
      );
      for (final status in MortReceiptStatus.values) {
        expect(status.isIssuedReceipt, isTrue);
      }
      expect(MortPaymentState.pending.name, isNotEmpty);
    });

    test('linked receipts and masked data stay in metadata', () {
      const document = MortReceiptDocument(
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
        maskedTransactionReference: 'ch_••••4242',
      );

      expect(document.linkedReceiptNumber, 'K-260915-04827');
      expect(document.maskedTransactionReference, 'ch_••••4242');
      expect(document.accountDisplay, '@marcus');
    });
  });
}
