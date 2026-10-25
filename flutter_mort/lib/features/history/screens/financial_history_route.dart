import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/providers.dart';
import '../models/payment_history.dart';
import 'job_payment_history_screen.dart';

/// Loads the signed-in user's authoritative history through the authenticated
/// Edge Function adapter. Provider failures render an explicit unavailable
/// state rather than a false empty history.
class FinancialHistoryRoute extends ConsumerStatefulWidget {
  const FinancialHistoryRoute({super.key});

  @override
  ConsumerState<FinancialHistoryRoute> createState() =>
      _FinancialHistoryRouteState();
}

class _FinancialHistoryRouteState extends ConsumerState<FinancialHistoryRoute> {
  final _entries = <MortPaymentHistoryEntry>[];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNextPage = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref
          .read(stripeMarketplaceRepositoryProvider)
          .financialHistory(cursor: append ? _cursor : null);
      if (!mounted) return;
      setState(() {
        final loaded = page.items.map(_historyEntry);
        if (append) {
          _entries.addAll(loaded);
        } else {
          _entries
            ..clear()
            ..addAll(loaded);
        }
        _cursor = page.nextCursor;
        _hasNextPage = _cursor != null;
        _loading = false;
        _loadingMore = false;
        _unavailable = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _unavailable = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => JobPaymentHistoryScreen(
    entries: _entries,
    isLoading: _loading,
    backendUnavailable: _unavailable,
    onRetry: () => unawaited(_load()),
    hasNextPage: _hasNextPage,
    onLoadMore: _loadingMore ? null : () => unawaited(_load(append: true)),
  );
}

MortPaymentHistoryEntry _historyEntry(Map<String, dynamic> item) {
  final eventKind = item['event_kind']?.toString() ?? '';
  final eventType = item['event_type']?.toString() ?? '';
  final kind = switch (eventKind) {
    'receipt' => MortPaymentHistoryKind.payment,
    'payment_attempt' => MortPaymentHistoryKind.payment,
    'payout' => MortPaymentHistoryKind.payout,
    'tip' => MortPaymentHistoryKind.tip,
    'refund' => MortPaymentHistoryKind.refund,
    'dispute' => MortPaymentHistoryKind.disputed,
    'ledger' => switch (eventType) {
      'tip_principal' => MortPaymentHistoryKind.tip,
      'adult_refund' || 'provider_refund' => MortPaymentHistoryKind.refund,
      'adjustment' => MortPaymentHistoryKind.adjustment,
      'reversal' => MortPaymentHistoryKind.reversal,
      'worker_compensation' || 'transfer' => MortPaymentHistoryKind.payout,
      _ => MortPaymentHistoryKind.payment,
    },
    _ => MortPaymentHistoryKind.job,
  };
  final rawStatus = item['status']?.toString().toLowerCase() ?? '';
  final status = switch (rawStatus) {
    'ready' => MortPaymentState.ready,
    'processing' => MortPaymentState.processing,
    'requires_action' => MortPaymentState.requiresAction,
    'pending' => MortPaymentState.pending,
    'succeeded' || 'paid' => MortPaymentState.succeeded,
    'declined' => MortPaymentState.declined,
    'failed' => MortPaymentState.failed,
    'cancelled' || 'canceled' => MortPaymentState.cancelled,
    'provider_unavailable' => MortPaymentState.providerUnavailable,
    _ => MortPaymentState.unknown,
  };
  final amount = item['amount_cents'];

  return MortPaymentHistoryEntry(
    id: item['event_id']?.toString() ?? '',
    title: item['title']?.toString() ?? 'Payment activity',
    occurredAt: item['occurred_at']?.toString() ?? '',
    status: status,
    amountCents: amount is num ? amount.toInt() : 0,
    kind: kind,
    receiptNumber: item['receipt_id']?.toString(),
    displaySubtitle: item['display_subtitle']?.toString(),
  );
}
