import 'package:flutter/material.dart';
import 'package:flutter_mort/features/history/models/payment_history.dart';

class MortPaymentHistoryFilters extends StatelessWidget {
  const MortPaymentHistoryFilters({
    super.key,
    required this.filter,
    required this.year,
    required this.onFilterChanged,
    required this.onYearChanged,
  });

  final MortPaymentHistoryFilter filter;
  final int year;
  final ValueChanged<MortPaymentHistoryFilter> onFilterChanged;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<MortPaymentHistoryFilter>(
          value: filter,
          onChanged: (value) {
            if (value != null) onFilterChanged(value);
          },
          items: const [
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.all,
              child: Text('All'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.jobs,
              child: Text('Jobs'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.payments,
              child: Text('Payments'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.receipts,
              child: Text('Receipts'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.earnings,
              child: Text('Earnings'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.tips,
              child: Text('Tips'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.refunds,
              child: Text('Refunds'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.failed,
              child: Text('Failed'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.adjustments,
              child: Text('Adjustments'),
            ),
            DropdownMenuItem(
              value: MortPaymentHistoryFilter.disputed,
              child: Text('Disputed'),
            ),
          ],
        ),
        DropdownButton<int>(
          value: year,
          onChanged: (value) {
            if (value != null) onYearChanged(value);
          },
          items: [
            for (final value in [year - 1, year, year + 1])
              DropdownMenuItem(value: value, child: Text('$value')),
          ],
        ),
      ],
    );
  }
}
