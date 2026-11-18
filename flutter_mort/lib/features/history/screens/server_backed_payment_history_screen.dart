import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_mort/core/utils/formatters.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/history/models/payment_history.dart';
import 'package:flutter_mort/features/history/screens/job_payment_history_screen.dart';

class ServerBackedPaymentHistoryScreen extends ConsumerStatefulWidget {
  const ServerBackedPaymentHistoryScreen({super.key});

  @override
  ConsumerState<ServerBackedPaymentHistoryScreen> createState() =>
      _ServerBackedPaymentHistoryScreenState();
}

class _ServerBackedPaymentHistoryScreenState
    extends ConsumerState<ServerBackedPaymentHistoryScreen> {
  List<MortPaymentHistoryEntry> _entries = const [];
  String? _nextCursor;
  Object? _loadError;
  bool _loading = true;
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final page = await ref
          .read(stripeMarketplaceRepositoryProvider)
          .financialHistory(cursor: reset ? null : _nextCursor, limit: 50);
      final mapped = page.items.map(_entryFromDto).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _entries = reset ? mapped : [..._entries, ...mapped];
        _nextCursor = page.nextCursor;
        _hasNextPage = page.nextCursor != null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MortPaymentHistoryEntry _entryFromDto(Map<String, dynamic> item) {
    final eventKind = item['event_kind']?.toString() ?? '';
    final eventType = item['event_type']?.toString() ?? '';
    final rawStatus = item['status']?.toString() ?? 'unknown';
    final displaySubtitle = item['display_subtitle']?.toString();
    final currency = item['currency_code']?.toString().toUpperCase() ?? 'USD';
    final amountValue = item['amount_cents'];
    final amount = amountValue is num
        ? amountValue.toInt()
        : int.tryParse(amountValue?.toString() ?? '') ?? 0;
    final receiptId = item['receipt_id']?.toString();
    final orderNumber = item['order_number']?.toString();
    final subtitleParts = [
      if (displaySubtitle != null && displaySubtitle.isNotEmpty)
        displaySubtitle,
      rawStatus.replaceAll('_', ' '),
    ];
    return MortPaymentHistoryEntry(
      id: item['event_id']?.toString() ?? '',
      title: item['title']?.toString() ?? 'Payment activity',
      occurredAt: item['occurred_at']?.toString() ?? '',
      status: _paymentState(rawStatus, eventKind),
      amountCents: amount,
      currencyCode: RegExp(r'^[A-Z]{3}$').hasMatch(currency) ? currency : 'USD',
      kind: _historyKind(eventKind, eventType),
      receiptId: receiptId,
      receiptNumber: orderNumber ?? receiptId,
      displaySubtitle: subtitleParts
          .where((part) => part.isNotEmpty)
          .join(' · '),
    );
  }

  MortPaymentHistoryKind _historyKind(String eventKind, String eventType) {
    if (eventKind == 'tip' || eventType == 'tip_principal') {
      return MortPaymentHistoryKind.tip;
    }
    if (eventKind == 'dispute') return MortPaymentHistoryKind.disputed;
    if (eventKind == 'payout' ||
        eventType == 'worker_compensation' ||
        eventType == 'transfer' ||
        eventType == 'TEEN_EARNINGS') {
      return MortPaymentHistoryKind.payout;
    }
    if (eventType == 'adult_refund' ||
        eventType == 'provider_refund' ||
        eventType == 'REFUND') {
      return MortPaymentHistoryKind.refund;
    }
    if (eventType == 'adjustment' || eventType == 'ADJUSTMENT') {
      return MortPaymentHistoryKind.adjustment;
    }
    if (eventType == 'reversal' || eventType == 'REVERSAL') {
      return MortPaymentHistoryKind.reversal;
    }
    if (eventKind == 'receipt' && eventType == 'ADULT_JOB_PAYMENT') {
      return MortPaymentHistoryKind.payment;
    }
    if (eventKind == 'ledger' && eventType == 'job_funding_principal') {
      return MortPaymentHistoryKind.payment;
    }
    if (eventKind == 'payment_attempt' || eventKind == 'ledger') {
      return MortPaymentHistoryKind.payment;
    }
    return MortPaymentHistoryKind.job;
  }

  MortPaymentState _paymentState(String status, String eventKind) {
    final normalized = status.replaceAll('_', '').toUpperCase();
    return switch (normalized) {
      'SUCCEEDED' ||
      'PAID' ||
      'CREDIT' ||
      'DEBIT' ||
      'COMPLETED' => MortPaymentState.succeeded,
      'PROCESSING' => MortPaymentState.processing,
      'REQUIRESACTION' => MortPaymentState.requiresAction,
      'PENDING' ||
      'OPEN' ||
      'NEEDSRESPONSE' ||
      'UNDERREVIEW' => MortPaymentState.pending,
      'DECLINED' => MortPaymentState.declined,
      'FAILED' || 'FUNDINGFAILED' => MortPaymentState.failed,
      'CANCELLED' || 'CANCELED' => MortPaymentState.cancelled,
      _ =>
        eventKind == 'receipt'
            ? MortPaymentState.succeeded
            : MortPaymentState.unknown,
    };
  }

  Future<void> _showReceipt(String receiptId) async {
    try {
      final document = await ref
          .read(stripeMarketplaceRepositoryProvider)
          .financialDocument(receiptId);
      if (!mounted) return;
      final centsValue = document['amount_cents'];
      final cents = centsValue is num
          ? centsValue.toInt()
          : int.tryParse(centsValue?.toString() ?? '') ?? 0;
      final currency = document['currency_code']?.toString() ?? 'USD';
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MORT financial receipt',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text('Receipt: ${document['receipt_id'] ?? receiptId}'),
                Text('Order: ${document['order_number'] ?? 'Not provided'}'),
                Text(
                  'Type: ${document['document_type'] ?? 'Financial document'}',
                ),
                Text('Date: ${document['document_date'] ?? 'Not provided'}'),
                Text('Status: ${document['status'] ?? 'Unknown'}'),
                Text('Amount: ${formatCents(cents, currency: currency)}'),
                if (document['masked_provider_reference'] != null)
                  Text(
                    'Provider reference: ${document['masked_provider_reference']}',
                  ),
                const SizedBox(height: 12),
                const Text(
                  'This receipt is a MORT record, not an escrow statement or a guarantee that funds were held until work completion.',
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Receipt unavailable. MORT could not retrieve an authorized financial document.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return JobPaymentHistoryScreen(
      entries: _entries,
      isLoading: _loading,
      loadError: _loadError,
      hasNextPage: _hasNextPage,
      onLoadMore: _hasNextPage && !_loading ? () => _load() : null,
      onViewReceipt: _showReceipt,
    );
  }
}
