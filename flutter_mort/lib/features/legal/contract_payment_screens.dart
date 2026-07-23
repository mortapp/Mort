import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';

class JobContractsScreen extends ConsumerWidget {
  const JobContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Job agreements',
          title: 'Exact work, pay, and safety terms',
          subtitle:
              'MORT creates a fixed agreement after an application is accepted. Material changes require both parties.',
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: ref.read(legalContractRepositoryProvider).contracts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Agreements unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final contracts = snapshot.data ?? const [];
            if (contracts.isEmpty) {
              return const MortEmptyState(
                title: 'No job agreements yet',
                message:
                    'An agreement appears here after an application is accepted.',
              );
            }
            return Column(
              children: [
                for (final contract in contracts) ...[
                  MortCard(
                    onTap: () => context.push('/contracts/${contract['id']}'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _contractTitle(contract),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _label(contract['classification_status']),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        MortBadge(
                          label: _label(contract['status']),
                          color: contract['status'] == 'active'
                              ? MortColors.neon
                              : MortColors.warning,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class JobContractScreen extends ConsumerStatefulWidget {
  const JobContractScreen({super.key, required this.contractId});

  final String contractId;

  @override
  ConsumerState<JobContractScreen> createState() => _JobContractScreenState();
}

class _JobContractScreenState extends ConsumerState<JobContractScreen> {
  final _confirmation = TextEditingController();
  bool _affirmative = false;
  bool _busy = false;
  late Future<Map<String, dynamic>> _future = _load();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final repository = ref.read(legalContractRepositoryProvider);
    final values = await Future.wait([
      repository.contractVersions(widget.contractId),
      repository.contractAcceptances(widget.contractId),
    ]);
    return {'versions': values[0], 'acceptances': values[1]};
  }

  Future<void> _confirm(String versionId) async {
    if (!_affirmative || _confirmation.text.trim().length < 8 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(legalContractRepositoryProvider)
          .confirmContractVersion(
            versionId: versionId,
            confirmation: _confirmation.text,
          );
      if (!mounted) return;
      _confirmation.clear();
      _affirmative = false;
      setState(() => _future = _load());
      MortToast.show(
        context,
        'Agreement confirmation saved. Both parties are required.',
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Immutable agreement',
          title: 'Job contract review',
          subtitle:
              'One party cannot silently change pay, scope, hours, location, hazards, expenses, or payment timing.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Agreement unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final versions =
                snapshot.data?['versions'] as List<Map<String, dynamic>>? ??
                const [];
            final acceptances =
                snapshot.data?['acceptances'] as List<Map<String, dynamic>>? ??
                const [];
            if (versions.isEmpty) {
              return const MortEmptyState(
                title: 'No agreement version',
                message: 'An authorized agreement version is not available.',
              );
            }
            final version = versions.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortCard(
                  color: MortColors.cardAlt,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Version ${version['version_number']} | ${_label(version['status'])}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: MortSpacing.xs),
                      Text(
                        'Integrity protected. Both parties review the same saved version.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
                _AgreementSection(
                  title: 'Parties and scope',
                  rows: {
                    'Teen': version['teen_public_identifier'],
                    'Adult or business': version['adult_public_identifier'],
                    'Agreed scope': version['agreed_scope'],
                    'Excluded work': _list(version['excluded_work']),
                    'Completion': version['completion_requirements'],
                    'Proof': version['proof_requirements'],
                  },
                ),
                _AgreementSection(
                  title: 'Time, place, and payment',
                  rows: {
                    'Service date': compactDate(version['service_date']),
                    'Start window': formatDateTime(version['start_window']),
                    'Expected end': formatDateTime(
                      version['expected_end_window'],
                    ),
                    'Location type': version['location_type'],
                    'Exact-location state':
                        version['exact_location_release_state'],
                    'Amount': _amount(version),
                    'Maximum hours':
                        version['maximum_approved_hours'] ?? 'Not applicable',
                    'Payment preference': version['payment_preference'],
                    'Payment due': version['payment_due_rule'],
                    'Authorized expenses': _list(
                      version['authorized_expenses'],
                    ),
                  },
                ),
                _AgreementSection(
                  title: 'Safety and changes',
                  rows: {
                    'Equipment': version['equipment'],
                    'Hazards': version['hazards'],
                    'People present': version['expected_people_present'],
                    'Supervision': version['supervision'],
                    'Cancellation': version['cancellation_terms'],
                    'Material changes': version['material_change_process'],
                    'Disputes': version['dispute_process'],
                    'Safety agreement': version['safety_agreement_version'],
                  },
                ),
                Text(
                  'Party confirmations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MortSpacing.sm),
                if (acceptances.isEmpty)
                  const Text('No party has confirmed this exact version yet.'),
                for (final item in acceptances)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.verified_outlined,
                      color: MortColors.neon,
                    ),
                    title: Text('${_label(item['party_role'])} confirmed'),
                    subtitle: Text(
                      'Saved ${formatDateTime(item['accepted_at'])}',
                    ),
                  ),
                if (version['status'] == 'pending_confirmation') ...[
                  MortTextField(
                    label: 'Confirmation sentence',
                    hint: 'I reviewed and confirm this exact job agreement.',
                    controller: _confirmation,
                    onChanged: (_) => setState(() {}),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _affirmative,
                    title: const Text(
                      'I affirmatively confirm this exact version',
                    ),
                    onChanged: (value) =>
                        setState(() => _affirmative = value == true),
                  ),
                  MortButton(
                    label: 'Confirm exact agreement',
                    icon: Icons.draw_outlined,
                    busy: _busy,
                    onPressed:
                        _affirmative && _confirmation.text.trim().length >= 8
                        ? () => _confirm(version['id'].toString())
                        : null,
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                MortButton(
                  label: 'Material changes',
                  icon: Icons.change_circle_outlined,
                  style: MortButtonStyle.secondary,
                  onPressed: () =>
                      context.push('/contracts/${widget.contractId}/change'),
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Payment status',
                  icon: Icons.payments_outlined,
                  style: MortButtonStyle.secondary,
                  onPressed: () =>
                      context.push('/contracts/${widget.contractId}/payment'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class ContractChangeScreen extends ConsumerStatefulWidget {
  const ContractChangeScreen({super.key, required this.contractId});

  final String contractId;

  @override
  ConsumerState<ContractChangeScreen> createState() =>
      _ContractChangeScreenState();
}

class _ContractChangeScreenState extends ConsumerState<ContractChangeScreen> {
  final _scope = TextEditingController();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _understood = false;
  bool _busy = false;
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() => ref
      .read(legalContractRepositoryProvider)
      .contractChanges(widget.contractId);

  @override
  void dispose() {
    _scope.dispose();
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final patch = <String, dynamic>{};
    if (_scope.text.trim().isNotEmpty) {
      patch['agreed_scope'] = _scope.text.trim();
    }
    final dollars = double.tryParse(_amount.text.trim());
    if (dollars != null && dollars >= 0) {
      patch.addAll({
        'amount_type': 'fixed',
        'fixed_total_cents': (dollars * 100).round(),
        'hourly_rate_cents': null,
      });
    }
    if (patch.isEmpty || _reason.text.trim().length < 8 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(legalContractRepositoryProvider)
          .requestContractChange(
            contractId: widget.contractId,
            patch: patch,
            reason: _reason.text,
          );
      if (!mounted) return;
      _scope.clear();
      _amount.clear();
      _reason.clear();
      _understood = false;
      setState(() => _future = _load());
      MortToast.show(
        context,
        'Proposal sent. The active agreement did not change.',
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(String changeId, bool accept) async {
    try {
      await ref
          .read(legalContractRepositoryProvider)
          .respondContractChange(changeId: changeId, accept: accept);
      if (!mounted) return;
      setState(() => _future = _load());
      MortToast.show(
        context,
        accept
            ? 'Exact proposal response saved. Both parties are required.'
            : 'Proposal declined. The active agreement remains unchanged.',
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        _understood &&
        _reason.text.trim().length >= 8 &&
        (_scope.text.trim().isNotEmpty || _amount.text.trim().isNotEmpty);
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Mutual consent',
          title: 'Material changes',
          subtitle:
              'No one can silently lower pay, expand scope, extend hours, change location, add hazards or expenses, or change payment timing.',
        ),
        MortTextArea(label: 'Revised scope', controller: _scope),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(
          label: 'Revised fixed total in dollars',
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(label: 'Reason for the change', controller: _reason),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _understood,
          title: const Text(
            'I understand this proposal does not change the agreement by itself',
          ),
          onChanged: (value) => setState(() => _understood = value == true),
        ),
        MortButton(
          label: 'Send change proposal',
          icon: Icons.send_outlined,
          busy: _busy,
          onPressed: canSend ? _request : null,
        ),
        const SizedBox(height: MortSpacing.lg),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Change history unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final changes = snapshot.data ?? const [];
            if (changes.isEmpty) return const Text('No material changes yet.');
            return Column(
              children: [
                for (final change in changes) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MortBadge(label: _label(change['status'])),
                        const SizedBox(height: MortSpacing.xs),
                        Text(_list(change['change_categories'])),
                        Text(change['reason']?.toString() ?? ''),
                        Text(
                          'Integrity protected until both parties respond.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (change['status'] == 'pending_both_parties') ...[
                          const SizedBox(height: MortSpacing.sm),
                          MortButton(
                            label: 'Accept exact proposal',
                            icon: Icons.check,
                            style: MortButtonStyle.secondary,
                            onPressed: () =>
                                _respond(change['id'].toString(), true),
                          ),
                          const SizedBox(height: MortSpacing.xs),
                          MortButton(
                            label: 'Decline proposal',
                            icon: Icons.close,
                            style: MortButtonStyle.danger,
                            onPressed: () =>
                                _respond(change['id'].toString(), false),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class PaymentStatusScreen extends ConsumerWidget {
  const PaymentStatusScreen({super.key, required this.contractId});

  final String contractId;

  Future<Map<String, dynamic>> _load(WidgetRef ref) async {
    final repository = ref.read(legalContractRepositoryProvider);
    final values = await Future.wait([
      repository.paymentObligations(contractId),
      repository.paymentDisputes(contractId),
    ]);
    return {'obligations': values[0], 'disputes': values[1]};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).asData?.value?.role;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Payment record',
          title: 'Payment status',
          subtitle:
              'Stripe job funding is available only when server controls enable the sandbox. MORT does not call the flow escrow or treat poster sent as worker received.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _load(ref),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Payment status unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final obligations =
                snapshot.data?['obligations'] as List<Map<String, dynamic>>? ??
                const [];
            final disputes =
                snapshot.data?['disputes'] as List<Map<String, dynamic>>? ??
                const [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (obligations.isEmpty)
                  const MortEmptyState(
                    title: 'No obligation visible',
                    message:
                        'The payment obligation is created after both parties confirm the exact agreement.',
                  ),
                for (final obligation in obligations) ...[
                  MortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _money(
                            obligation['amount_cents'],
                            obligation['currency_code'],
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        MortBadge(
                          label: _label(obligation['status']),
                          color:
                              obligation['status'] ==
                                  'worker_confirmed_received'
                              ? MortColors.neon
                              : MortColors.warning,
                        ),
                        Text('Due: ${_label(obligation['due_rule'])}'),
                        Text('Preference: ${obligation['payment_preference']}'),
                        if (const [
                          'due',
                          'poster_marked_sent',
                        ].contains(obligation['status'])) ...[
                          const SizedBox(height: MortSpacing.sm),
                          MortButton(
                            label: 'Report payment not received',
                            icon: Icons.report_problem_outlined,
                            style: MortButtonStyle.secondary,
                            onPressed: () => context.push(
                              '/payments/${obligation['id']}/nonpayment',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                if (role == UserRole.adult && obligations.isNotEmpty) ...[
                  MortButton(
                    label: 'Review Stripe job funding',
                    icon: Icons.lock_outline,
                    onPressed: () =>
                        context.push('/contracts/$contractId/fund'),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                if (role == UserRole.teen) ...[
                  MortButton(
                    label: 'Stripe payout setup',
                    icon: Icons.account_balance_outlined,
                    style: MortButtonStyle.secondary,
                    onPressed: () =>
                        context.push('/payments/stripe/payout-setup'),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                if (disputes.isNotEmpty) ...[
                  Text(
                    'Private disputes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: MortSpacing.sm),
                  for (final dispute in disputes) ...[
                    MortCard(
                      onTap: () => context.push('/disputes/${dispute['id']}'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_label(dispute['status'])),
                                Text(
                                  'Guilt determined: ${dispute['guilt_determined'] == true ? 'yes' : 'no'}',
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                    const SizedBox(height: MortSpacing.sm),
                  ],
                ],
                const MortCard(
                  color: MortColors.cardAlt,
                  child: Text(
                    'MORT does not automatically sue, select legal claims, promise recovery, decide guilt, or provide legal representation. Official options depend on facts and local law.',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class NonpaymentReportScreen extends ConsumerStatefulWidget {
  const NonpaymentReportScreen({super.key, required this.obligationId});

  final String obligationId;

  @override
  ConsumerState<NonpaymentReportScreen> createState() =>
      _NonpaymentReportScreenState();
}

class _NonpaymentReportScreenState
    extends ConsumerState<NonpaymentReportScreen> {
  final _statement = TextEditingController();
  bool _understood = false;
  bool _busy = false;

  @override
  void dispose() {
    _statement.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_understood || _statement.text.trim().length < 20 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(legalContractRepositoryProvider)
          .reportNonpayment(
            obligationId: widget.obligationId,
            statement: _statement.text,
          );
      if (!mounted) return;
      _statement.clear();
      setState(() => _understood = false);
      MortToast.show(
        context,
        'Private report opened. No guilt or legal outcome was determined.',
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Private report',
          title: 'Payment not received',
          subtitle:
              'This preserves a private allegation and evidence trail. It is not a court finding or criminal accusation.',
        ),
        MortTextArea(
          label: 'What was agreed, completed, and not received?',
          controller: _statement,
          maxLength: 4000,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _understood,
          title: const Text(
            'I understand this report does not automatically determine guilt or file a legal claim',
          ),
          onChanged: (value) => setState(() => _understood = value == true),
        ),
        MortButton(
          label: 'Open private nonpayment report',
          icon: Icons.lock_outline,
          busy: _busy,
          onPressed: _understood && _statement.text.trim().length >= 20
              ? _submit
              : null,
        ),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          child: Text(
            'Next steps may include the adult’s response, evidence preservation, retaliation controls, trained review, a bounded private account restriction after review, appeal, and an authorized evidence export.',
          ),
        ),
      ],
    );
  }
}

class PaymentDisputeScreen extends ConsumerStatefulWidget {
  const PaymentDisputeScreen({super.key, required this.disputeId});

  final String disputeId;

  @override
  ConsumerState<PaymentDisputeScreen> createState() =>
      _PaymentDisputeScreenState();
}

class _PaymentDisputeScreenState extends ConsumerState<PaymentDisputeScreen> {
  final _statement = TextEditingController();
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final repository = ref.read(legalContractRepositoryProvider);
    final values = await Future.wait([
      repository.paymentDispute(widget.disputeId),
      repository.disputeTimeline(widget.disputeId),
    ]);
    return {'dispute': values[0], 'timeline': values[1]};
  }

  @override
  void dispose() {
    _statement.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_statement.text.trim().length < 10) return;
    try {
      await ref
          .read(legalContractRepositoryProvider)
          .submitDisputeStatement(
            disputeId: widget.disputeId,
            statement: _statement.text,
          );
      if (!mounted) return;
      _statement.clear();
      setState(() => _future = _load());
      MortToast.show(context, 'Private dispute statement saved.');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Private review',
          title: 'Payment dispute',
          subtitle:
              'A reviewer can make a private platform recommendation, not a court judgment or criminal finding.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Dispute unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final dispute = Map<String, dynamic>.from(
              snapshot.data?['dispute'] as Map? ?? const {},
            );
            final timeline =
                snapshot.data?['timeline'] as List<Map<String, dynamic>>? ??
                const [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortCard(
                  color: MortColors.cardAlt,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MortBadge(label: _label(dispute['status'])),
                      Text(
                        'Guilt determined: ${dispute['guilt_determined'] == true ? 'yes' : 'no'}',
                      ),
                      Text(
                        'Classification: ${_label(dispute['classification_status'])}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
                _AgreementSection(
                  title: 'Statements',
                  rows: {
                    'Worker': dispute['worker_statement'],
                    'Poster': dispute['poster_statement'] ?? 'Not submitted',
                  },
                ),
                MortTextArea(
                  label: 'Your factual statement',
                  controller: _statement,
                  maxLength: 4000,
                ),
                MortButton(
                  label: 'Submit private statement',
                  icon: Icons.send_outlined,
                  onPressed: _submit,
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Authorized evidence export',
                  icon: Icons.file_download_outlined,
                  style: MortButtonStyle.secondary,
                  onPressed: () =>
                      context.push('/disputes/${widget.disputeId}/export'),
                ),
                const SizedBox(height: MortSpacing.lg),
                Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
                for (final event in timeline)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle, size: 10),
                    title: Text(_label(event['event_type'])),
                    subtitle: Text(event['event_summary']?.toString() ?? ''),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class EvidenceExportScreen extends ConsumerStatefulWidget {
  const EvidenceExportScreen({super.key, required this.disputeId});

  final String disputeId;

  @override
  ConsumerState<EvidenceExportScreen> createState() =>
      _EvidenceExportScreenState();
}

class _EvidenceExportScreenState extends ConsumerState<EvidenceExportScreen> {
  Map<String, dynamic>? _export;
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(legalContractRepositoryProvider)
          .evidenceExport(widget.disputeId);
      if (mounted) setState(() => _export = result);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Minimized record',
          title: 'Payment evidence export',
          subtitle:
              'Only authenticated dispute parties can request the server-generated manifest.',
        ),
        const MortCard(
          color: MortColors.cardAlt,
          child: Text(
            'Excluded: raw identity documents, document numbers, face data, residential addresses, precise coordinates, unrelated incidents, other users’ private data, and secrets.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Generate authorized export',
          icon: Icons.file_download_outlined,
          busy: _busy,
          onPressed: _generate,
        ),
        if (_export != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  'Manifest hash: ${_export!['manifest_hash']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(),
                SelectableText(
                  const JsonEncoder.withIndent(
                    '  ',
                  ).convert(_export!['export']),
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
          const MortCard(
            child: Text(
              'This export does not file a lawsuit, select a legal claim, promise recovery, or decide whether a court or wage process applies.',
            ),
          ),
        ],
      ],
    );
  }
}

class _AgreementSection extends StatelessWidget {
  const _AgreementSection({required this.title, required this.rows});

  final String title;
  final Map<String, dynamic> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.sm),
      child: MortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: MortSpacing.sm),
            for (final row in rows.entries) ...[
              Text(row.key, style: Theme.of(context).textTheme.labelMedium),
              Text(row.value?.toString() ?? 'Not set'),
              const SizedBox(height: MortSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

String _label(dynamic value) => (value?.toString() ?? 'unknown')
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

String _contractTitle(Map<String, dynamic> contract) {
  final job = contract['jobs'];
  if (job is Map) {
    final title = job['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
  }
  return 'Job agreement';
}

String _list(dynamic value) {
  if (value is List) return value.isEmpty ? 'None' : value.join(', ');
  return value?.toString() ?? 'None';
}

String _amount(Map<String, dynamic> version) {
  if (version['amount_type'] == 'fixed') {
    return _money(version['fixed_total_cents'], version['currency_code']);
  }
  return '${_money(version['hourly_rate_cents'], version['currency_code'])}/hour';
}

String _money(dynamic cents, dynamic currency) {
  final value = (cents as num? ?? 0).toDouble() / 100;
  return NumberFormat.simpleCurrency(
    name: currency?.toString() ?? 'USD',
  ).format(value);
}
