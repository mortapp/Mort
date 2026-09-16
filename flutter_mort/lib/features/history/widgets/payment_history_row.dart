import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_spacing.dart';
import 'package:flutter_mort/core/utils/formatters.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/history/models/payment_history.dart';

class MortPaymentHistoryRow extends StatelessWidget {
  const MortPaymentHistoryRow({
    super.key,
    required this.entry,
    this.onViewReceipt,
    this.onAddTip,
  });

  final MortPaymentHistoryEntry entry;
  final VoidCallback? onViewReceipt;
  final VoidCallback? onAddTip;

  @override
  Widget build(BuildContext context) {
    final issued =
        entry.receiptNumber != null &&
        entry.status == MortPaymentState.succeeded;
    return MortCard(
      child: Semantics(
        container: true,
        label: '${entry.title}. ${entry.status.label}.',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              entry.status.icon,
              color: entry.status.color,
              semanticLabel: entry.status.semanticLabel,
            ),
            const SizedBox(width: MortSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (entry.displaySubtitle != null)
                    Text(entry.displaySubtitle!),
                  Text(
                    _date(entry.occurredAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  MortPaymentStateBadge(state: entry.status),
                  const SizedBox(height: MortSpacing.xs),
                  Text(
                    formatCents(entry.amountCents),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MortColors.paymentSilverHigh,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!issued)
                    Text(switch (entry.status) {
                      MortPaymentState.failed ||
                      MortPaymentState.declined ||
                      MortPaymentState.cancelled => 'NO RECEIPT ISSUED',
                      MortPaymentState.pending ||
                      MortPaymentState.processing ||
                      MortPaymentState.requiresAction =>
                        'NO COMPLETED RECEIPT YET',
                      _ => 'Receipt unavailable',
                    }, style: Theme.of(context).textTheme.bodySmall),
                  if (issued || onAddTip != null) ...[
                    const SizedBox(height: MortSpacing.xs),
                    Wrap(
                      spacing: MortSpacing.sm,
                      children: [
                        if (issued)
                          TextButton.icon(
                            onPressed: onViewReceipt,
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('View Receipt'),
                          ),
                        if (onAddTip != null)
                          TextButton.icon(
                            onPressed: onAddTip,
                            icon: const Icon(Icons.favorite_border),
                            label: const Text('Add a tip'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(String value) {
    final date = DateTime.tryParse(value);
    return date == null
        ? value
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
