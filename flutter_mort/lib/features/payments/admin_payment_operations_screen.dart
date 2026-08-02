import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

class AdminPaymentOperationsScreen extends ConsumerStatefulWidget {
  const AdminPaymentOperationsScreen({super.key});

  @override
  ConsumerState<AdminPaymentOperationsScreen> createState() =>
      _AdminPaymentOperationsScreenState();
}

class _AdminPaymentOperationsScreenState
    extends ConsumerState<AdminPaymentOperationsScreen> {
  late Future<Map<String, dynamic>> _queue;
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _queue = ref
        .read(stripeMarketplaceRepositoryProvider)
        .paymentOperationsQueue();
  }

  Future<void> _review(Map<String, dynamic> dispute) async {
    final input = await showDialog<_PaymentReviewInput>(
      context: context,
      builder: (_) => _PaymentReviewDialog(
        maximumAmountCents: _int(dispute['amount_cents']),
      ),
    );
    if (input == null) return;
    await _run(() async {
      await ref
          .read(stripeMarketplaceRepositoryProvider)
          .reviewPaymentDispute(
            disputeId: dispute['dispute_id'].toString(),
            decisionType: input.decisionType,
            rationale: input.rationale,
            recommendedAmountCents: input.recommendedAmountCents,
          );
      return 'Human recommendation recorded. No transfer or refund was performed.';
    });
  }

  Future<void> _prepare(Map<String, dynamic> dispute) => _run(() async {
    final result = await ref
        .read(stripeMarketplaceRepositoryProvider)
        .prepareDisputeResolution(dispute['dispute_id'].toString());
    return 'Server resolution prepared as ${result['resolution_id']}. No provider operation was performed.';
  });

  Future<void> _execute(Map<String, dynamic> resolution) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Execute test-mode resolution?'),
        content: Text(
          'Resolution ${resolution['resolution_id']} will request '
          '${_money(resolution['transfer_amount_cents'], resolution['currency_code'])} as a transfer and '
          '${_money(resolution['refund_amount_cents'], resolution['currency_code'])} as a refund. '
          'The server will reject the reviewer acting as the financial operator. This is not a legal finding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm test execution'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final result = await ref
          .read(stripeMarketplaceRepositoryProvider)
          .executePreparedResolution(resolution['resolution_id'].toString());
      return 'Provider result: ${_label(result['status'])}. Refresh before taking another action.';
    });
  }

  Future<void> _run(Future<String> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      _notice = await operation();
      setState(_reload);
    } catch (error) {
      _notice = userFacingError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Restricted payment operations',
        title: 'Payment review and resolution',
        subtitle:
            'Human review and provider execution are separate, audited roles. All money and payout destinations come from server records.',
      ),
      const MortSafetyBanner(
        message:
            'Stripe live execution is disabled. AI cannot decide disputes, approve compensation, transfer funds, or issue refunds.',
      ),
      if (_notice != null) ...[
        const SizedBox(height: MortSpacing.sm),
        MortCard(color: MortColors.cardAlt, child: Text(_notice!)),
      ],
      const SizedBox(height: MortSpacing.md),
      FutureBuilder<Map<String, dynamic>>(
        future: _queue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MortLoading(label: 'Loading assigned payment work...');
          }
          if (snapshot.hasError) {
            return MortErrorState(
              title: 'Payment operations unavailable',
              message: userFacingError(snapshot.error),
              action: MortButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: () => setState(_reload),
              ),
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          if (data['ok'] != true) {
            return const MortErrorState(
              title: 'Restricted role required',
              message:
                  'An active payment reviewer or payment operations assignment is required. Admin status alone is not enough.',
            );
          }
          final disputes = _maps(data['disputes']);
          final resolutions = _maps(data['resolutions']);
          final incidents = _maps(data['incidents']);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MortBadge(
                label: 'Stripe ${_label(data['environment'])}',
                color: MortColors.warning,
              ),
              const SizedBox(height: MortSpacing.md),
              const MortSectionTitle(title: 'Assigned human reviews'),
              if (disputes.isEmpty)
                const MortEmptyState(
                  title: 'No assigned disputes',
                  message:
                      'Only active, unexpired reviewer assignments appear here.',
                )
              else
                for (final dispute in disputes) ...[
                  _DisputeCard(
                    dispute: dispute,
                    busy: _busy,
                    canReview: data['can_review'] == true,
                    onOpen: () =>
                        context.push('/disputes/${dispute['dispute_id']}'),
                    onReview: () => _review(dispute),
                    onPrepare: () => _prepare(dispute),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              const SizedBox(height: MortSpacing.md),
              const MortSectionTitle(title: 'Prepared server resolutions'),
              if (resolutions.isEmpty)
                const MortEmptyState(
                  title: 'No prepared resolutions',
                  message:
                      'A human recommendation must be recorded and prepared before a separate operator can act.',
                )
              else
                for (final resolution in resolutions) ...[
                  _ResolutionCard(
                    resolution: resolution,
                    busy: _busy,
                    canExecute: data['can_execute'] == true,
                    onExecute: () => _execute(resolution),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              const SizedBox(height: MortSpacing.md),
              const MortSectionTitle(title: 'Financial incidents'),
              if (incidents.isEmpty)
                const MortEmptyState(
                  title: 'No open financial incidents',
                  message:
                      'Provider outages, negative balances, payout failures, chargeback exposure, and reconciliation mismatches appear here only for assigned financial roles.',
                )
              else
                for (final incident in incidents) ...[
                  _FinancialIncidentCard(incident: incident),
                  const SizedBox(height: MortSpacing.sm),
                ],
            ],
          );
        },
      ),
    ],
  );
}

class _FinancialIncidentCard extends StatelessWidget {
  const _FinancialIncidentCard({required this.incident});

  final Map<String, dynamic> incident;

  @override
  Widget build(BuildContext context) => MortCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: MortSpacing.sm,
          runSpacing: MortSpacing.xs,
          children: [
            MortBadge(
              label: _label(incident['severity']),
              color: {'high', 'critical'}.contains(incident['severity'])
                  ? MortColors.danger
                  : MortColors.warning,
            ),
            MortBadge(label: _label(incident['status'])),
          ],
        ),
        const SizedBox(height: MortSpacing.sm),
        Text('Incident ${incident['incident_id']}'),
        Text('Category: ${_label(incident['category'])}'),
        Text('Safe code: ${_label(incident['safe_code'])}'),
        if (incident['amount_cents'] != null)
          Text(
            'Affected amount: ${_money(incident['amount_cents'], incident['currency_code'])}',
          ),
        if (incident['requires_two_person_review'] == true)
          const Text('Resolution requires independent financial review.'),
      ],
    ),
  );
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({
    required this.dispute,
    required this.busy,
    required this.canReview,
    required this.onOpen,
    required this.onReview,
    required this.onPrepare,
  });

  final Map<String, dynamic> dispute;
  final bool busy;
  final bool canReview;
  final VoidCallback onOpen;
  final VoidCallback onReview;
  final VoidCallback onPrepare;

  @override
  Widget build(BuildContext context) {
    final status = dispute['status']?.toString() ?? '';
    final preparedEligible = {
      'resolved_payment_recommended',
      'resolved_partial_payment_recommended',
    }.contains(status);
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortBadge(label: _label(status)),
          const SizedBox(height: MortSpacing.sm),
          Text('Case ${dispute['dispute_id']}'),
          Text(
            'Agreed obligation: ${_money(dispute['amount_cents'], dispute['currency_code'])}',
          ),
          Text('Classification: ${_label(dispute['classification_status'])}'),
          if (dispute['latest_decision_type'] != null)
            Text(
              'Latest recommendation: ${_label(dispute['latest_decision_type'])}',
            ),
          const SizedBox(height: MortSpacing.sm),
          Wrap(
            spacing: MortSpacing.sm,
            runSpacing: MortSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onOpen,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Review private case'),
              ),
              OutlinedButton.icon(
                onPressed: canReview && !busy ? onReview : null,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Record recommendation'),
              ),
              FilledButton.icon(
                onPressed: canReview && preparedEligible && !busy
                    ? onPrepare
                    : null,
                icon: const Icon(Icons.lock_clock_outlined),
                label: const Text('Prepare resolution'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({
    required this.resolution,
    required this.busy,
    required this.canExecute,
    required this.onExecute,
  });

  final Map<String, dynamic> resolution;
  final bool busy;
  final bool canExecute;
  final VoidCallback onExecute;

  @override
  Widget build(BuildContext context) {
    final separated = resolution['operator_separation_required'] != true;
    final executable =
        resolution['status'] == 'reviewed_pending_financial_execution';
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortBadge(label: _label(resolution['status'])),
          const SizedBox(height: MortSpacing.sm),
          Text('Resolution ${resolution['resolution_id']}'),
          Text(
            'Transfer: ${_money(resolution['transfer_amount_cents'], resolution['currency_code'])}',
          ),
          Text(
            'Refund: ${_money(resolution['refund_amount_cents'], resolution['currency_code'])}',
          ),
          Text('Basis: ${_label(resolution['eligibility_path'])}'),
          const SizedBox(height: MortSpacing.sm),
          FilledButton.icon(
            onPressed: canExecute && separated && executable && !busy
                ? onExecute
                : null,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(
              separated
                  ? 'Confirm provider execution'
                  : 'Different operator required',
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentReviewDialog extends StatefulWidget {
  const _PaymentReviewDialog({required this.maximumAmountCents});

  final int maximumAmountCents;

  @override
  State<_PaymentReviewDialog> createState() => _PaymentReviewDialogState();
}

class _PaymentReviewDialogState extends State<_PaymentReviewDialog> {
  final _rationale = TextEditingController();
  final _amount = TextEditingController();
  String _decision = 'request_more_evidence';
  String? _error;

  @override
  void dispose() {
    _rationale.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final rationale = _rationale.text.trim();
    final amount = _amount.text.trim().isEmpty
        ? null
        : int.tryParse(_amount.text.trim());
    final needsAmount = _decision == 'recommend_partial_payment';
    if (rationale.length < 20) {
      setState(
        () =>
            _error = 'Enter a substantive rationale of at least 20 characters.',
      );
      return;
    }
    if (needsAmount &&
        (amount == null || amount < 0 || amount > widget.maximumAmountCents)) {
      setState(
        () => _error =
            'Enter a valid partial amount in cents within the agreed obligation.',
      );
      return;
    }
    Navigator.pop(
      context,
      _PaymentReviewInput(
        decisionType: _decision,
        rationale: rationale,
        recommendedAmountCents: needsAmount ? amount : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record human recommendation'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _decision,
            decoration: const InputDecoration(labelText: 'Recommendation'),
            items:
                const {
                      'request_more_evidence': 'Request more evidence',
                      'recommend_payment': 'Recommend full payment',
                      'recommend_partial_payment': 'Recommend partial payment',
                      'no_platform_determination': 'No platform determination',
                      'confirm_payment_received': 'Confirm payment received',
                    }.entries
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.key,
                        child: Text(item.value),
                      ),
                    )
                    .toList(),
            onChanged: (value) =>
                setState(() => _decision = value ?? _decision),
          ),
          const SizedBox(height: MortSpacing.sm),
          TextField(
            controller: _rationale,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            decoration: const InputDecoration(labelText: 'Human rationale'),
          ),
          if (_decision == 'recommend_partial_payment')
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Recommended amount in cents',
                helperText: 'Maximum ${widget.maximumAmountCents} cents',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: MortSpacing.sm),
              child: Text(
                _error!,
                style: const TextStyle(color: MortColors.danger),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Record only')),
    ],
  );
}

class _PaymentReviewInput {
  const _PaymentReviewInput({
    required this.decisionType,
    required this.rationale,
    this.recommendedAmountCents,
  });

  final String decisionType;
  final String rationale;
  final int? recommendedAmountCents;
}

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList();

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _money(Object? cents, Object? currency) => NumberFormat.simpleCurrency(
  name: currency?.toString() ?? 'USD',
).format(_int(cents) / 100);

String _label(Object? value) => value
    .toString()
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
