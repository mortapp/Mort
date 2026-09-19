import 'package:flutter/material.dart';

class MortReceiptLineItem {
  const MortReceiptLineItem({
    required this.label,
    required this.amountCents,
    this.currencyCode = 'USD',
  });

  final String label;
  final int amountCents;
  final String currencyCode;
}

enum MortReceiptType {
  adultJobPayment,
  teenEarnings,
  storePurchase,
  lateTip,
  fullRefund,
  partialRefund,
  adjustment,
  reversal,
}

enum MortReceiptStatus { approved, credited, refunded, adjusted, reversed }

extension MortReceiptStatusX on MortReceiptStatus {
  bool get isIssuedReceipt => switch (this) {
    MortReceiptStatus.approved => true,
    MortReceiptStatus.credited => true,
    MortReceiptStatus.refunded => true,
    MortReceiptStatus.adjusted => true,
    MortReceiptStatus.reversed => true,
  };
}

class MortReceiptStatusPresentation {
  const MortReceiptStatusPresentation({
    required this.label,
    required this.icon,
    required this.color,
    required this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String semanticLabel;
}

MortReceiptStatusPresentation mortReceiptStatusPresentation(
  MortReceiptStatus status,
) {
  return switch (status) {
    MortReceiptStatus.approved => const MortReceiptStatusPresentation(
      label: 'APPROVED',
      icon: Icons.check_circle_rounded,
      color: Color(0xFF46C483),
      semanticLabel: 'Payment status Approved',
    ),
    MortReceiptStatus.credited => const MortReceiptStatusPresentation(
      label: 'CREDITED',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF46C483),
      semanticLabel: 'Payment status Credited',
    ),
    MortReceiptStatus.refunded => const MortReceiptStatusPresentation(
      label: 'REFUNDED',
      icon: Icons.undo_rounded,
      color: Color(0xFFE5605E),
      semanticLabel: 'Payment status Refunded',
    ),
    MortReceiptStatus.adjusted => const MortReceiptStatusPresentation(
      label: 'ADJUSTED',
      icon: Icons.tune_rounded,
      color: Color(0xFF8FB4D9),
      semanticLabel: 'Payment status Adjusted',
    ),
    MortReceiptStatus.reversed => const MortReceiptStatusPresentation(
      label: 'REVERSED',
      icon: Icons.restart_alt_rounded,
      color: Color(0xFFD9A94F),
      semanticLabel: 'Payment status Reversed',
    ),
  };
}

class MortReceiptDocument {
  const MortReceiptDocument({
    required this.receiptType,
    required this.status,
    required this.orderNumber,
    required this.receiptNumber,
    required this.occurredAt,
    this.jobTitle = '',
    this.serviceSummaryLines = const [],
    this.payerHandle,
    this.workerHandle,
    this.accountHandle,
    this.currencyCode = 'USD',
    this.lineItems = const [],
    required this.authoritativeTotalCents,
    this.totalLabel,
    this.maskedPaymentMethod,
    this.maskedTransactionReference,
    this.providerName,
    this.linkedReceiptNumber,
    this.originalTotalCents,
    this.refundAmountCents,
    this.remainingPaidCents,
  });

  final MortReceiptType receiptType;
  final MortReceiptStatus status;
  final String orderNumber;
  final String receiptNumber;
  final String occurredAt;
  final String jobTitle;
  final List<String> serviceSummaryLines;
  final String? payerHandle;
  final String? workerHandle;
  final String? accountHandle;
  final String currencyCode;
  final List<MortReceiptLineItem> lineItems;
  final int authoritativeTotalCents;
  final String? totalLabel;
  final String? maskedPaymentMethod;
  final String? maskedTransactionReference;
  final String? providerName;
  final String? linkedReceiptNumber;
  final int? originalTotalCents;
  final int? refundAmountCents;
  final int? remainingPaidCents;

  List<String> get serviceLines => serviceSummaryLines.isEmpty
      ? const ['Service summary unavailable']
      : serviceSummaryLines;

  String get typeTitle => switch (receiptType) {
    MortReceiptType.adultJobPayment => 'JOB PAYMENT RECEIPT',
    MortReceiptType.teenEarnings => 'TEEN EARNINGS RECEIPT',
    MortReceiptType.storePurchase => 'MORT PURCHASE RECEIPT',
    MortReceiptType.lateTip => 'LATE TIP RECEIPT',
    MortReceiptType.fullRefund => 'REFUND RECEIPT',
    MortReceiptType.partialRefund => 'PARTIAL REFUND RECEIPT',
    MortReceiptType.adjustment => 'ADJUSTMENT RECEIPT',
    MortReceiptType.reversal => 'REVERSAL RECEIPT',
  };

  String get semanticSummary => switch (receiptType) {
    MortReceiptType.adultJobPayment =>
      'Adult job payment receipt $receiptNumber. Order number $orderNumber.',
    MortReceiptType.teenEarnings =>
      'Teen earnings receipt $receiptNumber. Order number $orderNumber.',
    MortReceiptType.storePurchase =>
      'Purchase receipt $receiptNumber. Order number $orderNumber.',
    MortReceiptType.lateTip => 'Late tip receipt $receiptNumber.',
    MortReceiptType.fullRefund => 'Refund receipt $receiptNumber.',
    MortReceiptType.partialRefund => 'Partial refund receipt $receiptNumber.',
    MortReceiptType.adjustment => 'Adjustment receipt $receiptNumber.',
    MortReceiptType.reversal => 'Reversal receipt $receiptNumber.',
  };

  String get displayTotalLabel =>
      totalLabel ??
      switch (receiptType) {
        MortReceiptType.adultJobPayment => 'TOTAL PAID',
        MortReceiptType.teenEarnings => 'NET EARNINGS',
        MortReceiptType.storePurchase => 'TOTAL',
        MortReceiptType.lateTip => 'TOTAL',
        MortReceiptType.fullRefund => 'TOTAL REFUNDED',
        MortReceiptType.partialRefund => 'TOTAL REFUNDED',
        MortReceiptType.adjustment => 'TOTAL ADJUSTED',
        MortReceiptType.reversal => 'TOTAL REVERSED',
      };

  String get accountDisplay => accountHandle ?? payerHandle ?? '@mort';

  static List<MortReceiptStatus> get values => MortReceiptStatus.values;
}
