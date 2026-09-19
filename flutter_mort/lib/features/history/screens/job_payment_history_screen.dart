import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_spacing.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/history/models/payment_history.dart';
import '../widgets/payment_history_filters.dart';
import '../widgets/payment_history_row.dart';

class JobPaymentHistoryScreen extends StatefulWidget {
  const JobPaymentHistoryScreen({
    super.key,
    this.entries = const [],
    this.isLoading = false,
    this.backendUnavailable = false,
    this.isOffline = false,
    this.loadError,
    this.onLoadMore,
    this.hasNextPage = false,
  });

  final List<MortPaymentHistoryEntry> entries;
  final bool isLoading;
  final bool backendUnavailable;
  final bool isOffline;
  final Object? loadError;
  final VoidCallback? onLoadMore;
  final bool hasNextPage;

  @override
  State<JobPaymentHistoryScreen> createState() =>
      _JobPaymentHistoryScreenState();
}

class _JobPaymentHistoryScreenState extends State<JobPaymentHistoryScreen> {
  late final TextEditingController _searchController;
  late MortPaymentHistoryFilter _filter;
  late int _year;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()..addListener(_changed);
    _filter = MortPaymentHistoryFilter.all;
    _year = widget.entries.isEmpty
        ? DateTime.now().year
        : DateTime.tryParse(widget.entries.first.occurredAt)?.year ??
              DateTime.now().year;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  List<MortPaymentHistoryEntry> get _filtered {
    final entries = MortPaymentHistoryEntry.sortByNewest(widget.entries);
    return entries.where((entry) {
      return entry.matchesYear(_year) &&
          entry.matchesFilter(_filter) &&
          entry.matchesSearch(_searchController.text);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Payments',
          title: 'Job & payment history',
          subtitle:
              'A chronological record of authoritative payment attempts and issued receipts.',
        ),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Search history',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortPaymentHistoryFilters(
          filter: _filter,
          year: _year,
          onFilterChanged: (value) => setState(() => _filter = value),
          onYearChanged: (value) => setState(() => _year = value),
        ),
        const SizedBox(height: MortSpacing.md),
        if (widget.backendUnavailable)
          const MortErrorState(
            title: 'Payment history is not available yet',
            message:
                'MORT does not have an authoritative payment-history backend for this account.',
          )
        else if (widget.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (widget.isOffline)
          const MortSafetyBanner(
            message: 'You are offline. Showing only locally available records.',
          ),
        if (!widget.isLoading && widget.loadError != null)
          MortErrorState(
            title: 'History unavailable',
            message:
                'MORT could not load authoritative history. Try again when connected.',
          )
        else if (!widget.isLoading &&
            !widget.backendUnavailable &&
            _filtered.isEmpty)
          MortEmptyState(
            title: widget.entries.isEmpty
                ? 'No payment activity'
                : 'No matching activity',
            message: widget.entries.isEmpty
                ? 'Completed jobs and payment attempts will appear here.'
                : 'Try another search, year, or filter.',
            icon: Icons.receipt_long_outlined,
          )
        else if (!widget.backendUnavailable)
          for (final entry in _filtered) ...[
            MortPaymentHistoryRow(entry: entry),
            const SizedBox(height: MortSpacing.sm),
          ],
        if (widget.hasNextPage)
          MortButton(
            label: 'Load more',
            icon: Icons.expand_more,
            style: MortButtonStyle.secondary,
            onPressed: widget.onLoadMore,
          ),
      ],
    );
  }
}
