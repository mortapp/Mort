export 'package:flutter_mort/features/payments/models/payment_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_mort/features/payments/models/payment_state.dart';

enum MortPaymentHistoryKind {
  job,
  payment,
  payout,
  refund,
  adjustment,
  tip,
  reversal,
  disputed,
}

enum MortPaymentHistoryFilter {
  all,
  jobs,
  payments,
  receipts,
  earnings,
  tips,
  refunds,
  failed,
  adjustments,
  disputed,
}

class MortPaymentHistoryEntry {
  const MortPaymentHistoryEntry({
    required this.id,
    required this.title,
    required this.occurredAt,
    required this.status,
    required this.amountCents,
    required this.kind,
    this.receiptNumber,
    this.displaySubtitle,
  });

  final String id;
  final String title;
  final String occurredAt;
  final MortPaymentState status;
  final int amountCents;
  final MortPaymentHistoryKind kind;
  final String? receiptNumber;
  final String? displaySubtitle;

  static List<MortPaymentHistoryEntry> sortByNewest(
    List<MortPaymentHistoryEntry> entries,
  ) {
    final sorted = [...entries];
    sorted.sort((a, b) {
      final aDate =
          DateTime.tryParse(a.occurredAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b.occurredAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    final haystack = [
      title,
      displaySubtitle ?? '',
      receiptNumber ?? '',
      kind.name,
    ].join(' ').toLowerCase();
    return haystack.contains(normalized);
  }

  bool matchesYear(int year) =>
      (DateTime.tryParse(occurredAt)?.year ?? 0) == year;

  bool matchesFilter(MortPaymentHistoryFilter filter) {
    switch (filter) {
      case MortPaymentHistoryFilter.all:
        return true;
      case MortPaymentHistoryFilter.jobs:
        return kind == MortPaymentHistoryKind.job;
      case MortPaymentHistoryFilter.payments:
        return kind == MortPaymentHistoryKind.payment;
      case MortPaymentHistoryFilter.receipts:
        return receiptNumber != null && status == MortPaymentState.succeeded;
      case MortPaymentHistoryFilter.earnings:
        return kind == MortPaymentHistoryKind.payout;
      case MortPaymentHistoryFilter.tips:
        return kind == MortPaymentHistoryKind.tip;
      case MortPaymentHistoryFilter.refunds:
        return kind == MortPaymentHistoryKind.refund;
      case MortPaymentHistoryFilter.failed:
        return status == MortPaymentState.failed ||
            status == MortPaymentState.declined ||
            status == MortPaymentState.cancelled;
      case MortPaymentHistoryFilter.adjustments:
        return kind == MortPaymentHistoryKind.adjustment ||
            kind == MortPaymentHistoryKind.reversal;
      case MortPaymentHistoryFilter.disputed:
        return kind == MortPaymentHistoryKind.disputed;
    }
  }
}

class MortPaymentHistoryView extends StatelessWidget {
  const MortPaymentHistoryView({
    super.key,
    required this.entries,
    required this.selectedYear,
    required this.searchQuery,
    required this.currentFilter,
    required this.isLoading,
    required this.hasNextPage,
    this.onLoadMore,
  });

  final List<MortPaymentHistoryEntry> entries;
  final int selectedYear;
  final String searchQuery;
  final MortPaymentHistoryFilter currentFilter;
  final bool isLoading;
  final bool hasNextPage;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final filteredEntries = entries.where((entry) {
      final matchesYear = entry.matchesYear(selectedYear);
      final matchesFilter = entry.matchesFilter(currentFilter);
      final matchesSearch = entry.matchesSearch(searchQuery);
      return matchesYear && matchesFilter && matchesSearch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Timeline'),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (filteredEntries.isEmpty)
          const Text('No payment activity')
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredEntries.length,
            separatorBuilder: (context, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = filteredEntries[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.radio_button_checked, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title),
                        if (entry.displaySubtitle != null)
                          Text(entry.displaySubtitle!),
                      ],
                    ),
                  ),
                  Text('${entry.amountCents ~/ 100}'),
                ],
              );
            },
          ),
          if (hasNextPage)
            TextButton(onPressed: onLoadMore, child: const Text('Load more')),
        ],
      ],
    );
  }
}
