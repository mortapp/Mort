import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/utils/formatters.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import '../models/receipt_document.dart';

class MortReceiptDocumentView extends StatelessWidget {
  const MortReceiptDocumentView({super.key, required this.document});

  final MortReceiptDocument document;

  @override
  Widget build(BuildContext context) {
    final presentation = mortReceiptStatusPresentation(document.status);

    return Semantics(
      container: true,
      label: document.semanticSummary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth > 0 ? maxWidth : 560,
              ),
              child: Padding(
                padding: EdgeInsets.all(maxWidth < 360 ? 12 : 16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MortColors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MortColors.receiptEdge),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MortColors.receiptPaper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: MortColors.receiptEdge,
                        width: 1.5,
                      ),
                    ),
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: MortColors.receiptInk,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ReceiptBrandHeader(
                              title: document.typeTitle,
                              statusPresentation: presentation,
                            ),
                            const SizedBox(height: 12),
                            const Divider(
                              color: MortColors.receiptRule,
                              thickness: 1,
                              height: 1,
                            ),
                            const SizedBox(height: 12),
                            _MetadataBlock(
                              orderNumber: document.orderNumber,
                              receiptNumber: document.receiptNumber,
                              date: _formatDate(document.occurredAt),
                              time: _formatTime(document.occurredAt),
                            ),
                            const SizedBox(height: 12),
                            ..._buildHeaderDetails(context, document),
                            if (document.serviceLines.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'SERVICE',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      letterSpacing: 1.5,
                                      color: MortColors.receiptMutedInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              ...document.serviceLines.map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    line,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: MortColors.receiptInk,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(
                              color: MortColors.receiptRule,
                              height: 1,
                            ),
                            const SizedBox(height: 12),
                            ..._buildLineItems(context, document),
                            const SizedBox(height: 12),
                            const Divider(
                              color: MortColors.receiptRule,
                              height: 1,
                            ),
                            const SizedBox(height: 12),
                            if (document.receiptType ==
                                MortReceiptType.storePurchase) ...[
                              _ReceiptTotalRow(
                                label: 'SUBTOTAL',
                                value: formatCents(
                                  document.authoritativeTotalCents,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _ReceiptTotalRow(
                              label: document.displayTotalLabel,
                              value: formatCents(
                                document.authoritativeTotalCents,
                              ),
                            ),
                            if (document.receiptType ==
                                    MortReceiptType.adultJobPayment ||
                                document.receiptType ==
                                    MortReceiptType.storePurchase) ...[
                              const SizedBox(height: 12),
                              _ReceiptDetailBlock(
                                label: 'PAYMENT METHOD',
                                value:
                                    document.maskedPaymentMethod ??
                                    'Masked payment method',
                              ),
                              const SizedBox(height: 8),
                              _ReceiptDetailBlock(
                                label: 'TRANSACTION REF',
                                value:
                                    document.maskedTransactionReference ??
                                    'Masked reference',
                              ),
                            ],
                            if (document.receiptType ==
                                MortReceiptType.teenEarnings) ...[
                              const SizedBox(height: 12),
                              _ReceiptDetailBlock(
                                label: 'EARNINGS STATUS',
                                value: 'Posted to teen',
                              ),
                            ],
                            if (document.receiptType ==
                                    MortReceiptType.storePurchase &&
                                document.providerName != null) ...[
                              const SizedBox(height: 8),
                              _ReceiptDetailBlock(
                                label: 'PROVIDER',
                                value: document.providerName!,
                              ),
                            ],
                            if (document.receiptType ==
                                    MortReceiptType.lateTip ||
                                document.receiptType ==
                                    MortReceiptType.fullRefund ||
                                document.receiptType ==
                                    MortReceiptType.partialRefund ||
                                document.receiptType ==
                                    MortReceiptType.adjustment ||
                                document.receiptType ==
                                    MortReceiptType.reversal) ...[
                              const SizedBox(height: 12),
                              if (document.linkedReceiptNumber != null) ...[
                                _ReceiptDetailBlock(
                                  label: 'LINKED RECEIPT',
                                  value: document.linkedReceiptNumber!,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildHeaderDetails(
    BuildContext context,
    MortReceiptDocument document,
  ) {
    switch (document.receiptType) {
      case MortReceiptType.adultJobPayment:
        return [
          _ReceiptDetailBlock(label: 'JOB', value: document.jobTitle),
          const SizedBox(height: 12),
          _ReceiptDetailBlock(
            label: 'PAYER',
            value: document.payerHandle ?? '@payer',
          ),
          const SizedBox(height: 8),
          _ReceiptDetailBlock(
            label: 'WORKER',
            value: document.workerHandle ?? '@worker',
          ),
        ];
      case MortReceiptType.teenEarnings:
        return [
          _ReceiptDetailBlock(label: 'JOB', value: document.jobTitle),
          const SizedBox(height: 12),
          _ReceiptDetailBlock(
            label: 'POSTED BY',
            value: document.accountDisplay,
          ),
          const SizedBox(height: 8),
          _ReceiptDetailBlock(
            label: 'WORKER',
            value: document.workerHandle ?? '@worker',
          ),
        ];
      case MortReceiptType.storePurchase:
        return [
          _ReceiptDetailBlock(label: 'ACCOUNT', value: document.accountDisplay),
        ];
      case MortReceiptType.lateTip:
        return [
          _ReceiptDetailBlock(
            label: 'RECIPIENT',
            value: document.workerHandle ?? '@worker',
          ),
        ];
      case MortReceiptType.fullRefund:
      case MortReceiptType.partialRefund:
      case MortReceiptType.adjustment:
      case MortReceiptType.reversal:
        return [
          _ReceiptDetailBlock(
            label: 'ORIGINAL',
            value: document.linkedReceiptNumber ?? 'Original receipt',
          ),
        ];
    }
  }

  List<Widget> _buildLineItems(
    BuildContext context,
    MortReceiptDocument document,
  ) {
    if (document.lineItems.isEmpty) {
      return const [SizedBox.shrink()];
    }

    return document.lineItems.map((item) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.label.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MortColors.receiptMutedInk,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                formatCents(item.amountCents),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MortColors.receiptInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  static String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ReceiptBrandHeader extends StatelessWidget {
  const _ReceiptBrandHeader({
    required this.title,
    required this.statusPresentation,
  });

  final String title;
  final MortReceiptStatusPresentation statusPresentation;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MORT',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: MortColors.receiptInk,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              Text(
                'GET IN MOTION',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: MortColors.receiptMutedInk,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: MortColors.receiptInk,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: Align(
            alignment: Alignment.topRight,
            child: MortPaymentStatusBadge(
              label: statusPresentation.label,
              color: statusPresentation.color,
              icon: statusPresentation.icon,
              semanticLabel: statusPresentation.semanticLabel,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataBlock extends StatelessWidget {
  const _MetadataBlock({
    required this.orderNumber,
    required this.receiptNumber,
    required this.date,
    required this.time,
  });

  final String orderNumber;
  final String receiptNumber;
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReceiptLabelValue(label: 'ORDER #', value: orderNumber),
        const SizedBox(height: 8),
        _ReceiptLabelValue(label: 'RECEIPT #', value: receiptNumber),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ReceiptLabelValue(label: 'DATE', value: date),
            ),
            Expanded(
              child: _ReceiptLabelValue(label: 'TIME', value: time),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReceiptDetailBlock extends StatelessWidget {
  const _ReceiptDetailBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: MortColors.receiptMutedInk,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: MortColors.receiptInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ReceiptLabelValue extends StatelessWidget {
  const _ReceiptLabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: MortColors.receiptInk,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ReceiptTotalRow extends StatelessWidget {
  const _ReceiptTotalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: MortColors.receiptMutedInk,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: MortColors.receiptInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
