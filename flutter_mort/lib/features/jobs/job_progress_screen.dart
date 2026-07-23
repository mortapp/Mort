import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/job_execution_repository.dart';
import '../../data/repositories/providers.dart';

class JobProgressScreen extends ConsumerStatefulWidget {
  const JobProgressScreen({
    super.key,
    required this.applicationId,
    this.syntheticStatusForTesting,
  });

  final String applicationId;
  final JobExecutionStatus? syntheticStatusForTesting;

  @override
  ConsumerState<JobProgressScreen> createState() => _JobProgressScreenState();
}

class _JobProgressScreenState extends ConsumerState<JobProgressScreen> {
  final _pin = TextEditingController();
  late Future<JobExecutionStatus> _status;
  GeneratedJobPin? _generatedPin;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _reload() {
    _status = widget.syntheticStatusForTesting == null
        ? ref
              .read(jobExecutionRepositoryProvider)
              .getStatus(widget.applicationId)
        : Future.value(widget.syntheticStatusForTesting);
  }

  Future<T?> _perform<T>(
    Future<T> Function() operation, {
    required String success,
  }) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final result = await operation();
      if (mounted) {
        MortToast.show(context, success);
        setState(_reload);
      }
      return result;
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generatePin({required bool start}) async {
    final repository = ref.read(jobExecutionRepositoryProvider);
    final generated = await _perform(
      () => start
          ? repository.generateStartPin(widget.applicationId)
          : repository.generateFinishPin(widget.applicationId),
      success:
          '${start ? 'Start' : 'Finish'} PIN generated. Share it in person only.',
    );
    if (generated != null && mounted) {
      setState(() => _generatedPin = generated);
    }
  }

  Future<void> _confirmPin({required bool start}) async {
    final value = _pin.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      MortToast.show(context, 'Enter all six digits.');
      return;
    }
    final repository = ref.read(jobExecutionRepositoryProvider);
    final result = await _perform(
      () => start
          ? repository.confirmStartPin(
              applicationId: widget.applicationId,
              pin: value,
              personMatchesProfile: true,
            )
          : repository.confirmFinishPin(
              applicationId: widget.applicationId,
              pin: value,
            ),
      success: start
          ? 'Start confirmed. The job is now in progress.'
          : 'Completion recorded. Funds remain pending during review.',
    );
    if (result != null) _pin.clear();
  }

  Future<void> _reportMismatch() async {
    final confirmed = await _confirmDialog(
      title: 'Report person mismatch?',
      message:
          'Do not continue if the person does not match the MORT profile. This opens a safety record; it does not make a legal identity finding.',
      action: 'Report mismatch',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await _perform(
      () => ref
          .read(jobExecutionRepositoryProvider)
          .reportPersonMismatch(widget.applicationId),
      success: 'Mismatch reported. Move to a safe place if needed.',
    );
    if (mounted) context.go('/safety');
  }

  Future<void> _finishPinUnavailable(JobExecutionStatus status) async {
    final response = await showDialog<_FinishStatement>(
      context: context,
      builder: (_) => const _FinishStatementDialog(),
    );
    if (response == null || !mounted) return;
    final result = await _perform(
      () => ref
          .read(jobExecutionRepositoryProvider)
          .reportFinishPinUnavailable(
            applicationId: widget.applicationId,
            actualStartAt:
                status.startedAt ??
                DateTime.now().subtract(const Duration(hours: 1)),
            actualFinishAt: DateTime.now(),
            workCompleted: response.workCompleted,
            statement: response.statement,
          ),
      success: 'Private review opened. Submission does not guarantee payment.',
    );
    _openReturnedSupportTicket(result);
  }

  Future<void> _cancelJob() async {
    final reason = await _statementDialog(
      title: 'Request job cancellation',
      label: 'Factual cancellation reason',
      warning:
          'After work starts, cancellation requires review and does not automatically create a full refund.',
    );
    if (reason == null || !mounted) return;
    final result = await _perform(
      () => ref
          .read(jobExecutionRepositoryProvider)
          .requestAdultCancellation(
            applicationId: widget.applicationId,
            reason: reason,
          ),
      success:
          'Cancellation request recorded. No money moved from this action.',
    );
    _openReturnedSupportTicket(result);
  }

  Future<void> _reportAbandonment() async {
    final statement = await _statementDialog(
      title: 'Report possible abandonment',
      label: 'What happened?',
      warning:
          'This is an allegation, not a finding. The teen can respond, and no cooldown or payment decision happens from this report alone.',
    );
    if (statement == null || !mounted) return;
    final result = await _perform(
      () => ref
          .read(jobExecutionRepositoryProvider)
          .reportPossibleTeenAbandonment(
            applicationId: widget.applicationId,
            statement: statement,
          ),
      success:
          'Report opened for private review. No automatic penalty applied.',
    );
    _openReturnedSupportTicket(result);
  }

  Future<void> _respondToAbandonment() async {
    final response = await showDialog<_AbandonmentResponse>(
      context: context,
      builder: (_) => const _AbandonmentResponseDialog(),
    );
    if (response == null || !mounted) return;
    final result = await _perform(
      () => ref
          .read(jobExecutionRepositoryProvider)
          .respondToAbandonment(
            applicationId: widget.applicationId,
            statement: response.statement,
            safetyRelated: response.safetyRelated,
          ),
      success: 'Your factual response was added. No payment decision was made.',
    );
    if (response.safetyRelated && result != null && mounted) {
      context.go('/safety');
    }
  }

  void _openReturnedSupportTicket(Map<String, dynamic>? result) {
    if (result == null || !mounted) return;
    final support = result['support'];
    final supportMap = support is Map ? support : result;
    final ticket = supportMap['ticket'];
    final id = ticket is Map ? ticket['id']?.toString() : null;
    if (id != null && id.isNotEmpty) context.go('/support/ticket/$id');
  }

  Future<String?> _statementDialog({
    required String title,
    required String label,
    required String warning,
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        _StatementDialog(title: title, label: label, warning: warning),
  );

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String action,
    bool danger = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(backgroundColor: MortColors.danger)
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => FutureBuilder<JobExecutionStatus>(
    future: _status,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const MortLoading(label: 'Loading server job progress...');
      }
      if (snapshot.hasError || snapshot.data == null) {
        return MortScreen(
          children: [
            MortErrorState(
              title: 'Job progress unavailable',
              message: userFacingError(snapshot.error),
              action: MortButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: () => setState(_reload),
              ),
            ),
          ],
        );
      }
      final status = snapshot.data!;
      return MortScreen(
        children: [
          MortHeader(
            eyebrow: 'Server-owned job status',
            title: 'Job progress',
            subtitle:
                'Agreement, funding, in-person handoff, completion review, and payment release stay separate.',
            trailing: MortBadge(label: _label(status.state)),
          ),
          const MortSafetyBanner(
            message:
                'Exchange job PINs in person, never in public chat. A PIN records a participant action; it does not prove identity, work quality, or payment eligibility.',
          ),
          const SizedBox(height: MortSpacing.md),
          _FundingCard(status: status),
          const SizedBox(height: MortSpacing.md),
          _ProgressTimeline(state: status.state),
          const SizedBox(height: MortSpacing.md),
          if (_generatedPin != null) ...[
            _GeneratedPinCard(pin: _generatedPin!),
            const SizedBox(height: MortSpacing.md),
          ],
          if (status.isAdult) _adultActions(status),
          if (status.isTeen) _teenActions(status),
          const SizedBox(height: MortSpacing.md),
          const MortSectionTitle(title: 'Job tools'),
          MortActionRow(
            actions: [
              const MortAction(
                label: 'Messages',
                icon: Icons.chat_bubble_outline,
                route: '/messages',
              ),
              MortAction(
                label: 'Exact agreement',
                icon: Icons.description_outlined,
                route: '/contracts/${status.contractId}',
              ),
              MortAction(
                label: 'Payment status',
                icon: Icons.account_balance_wallet_outlined,
                route: '/contracts/${status.contractId}/payment',
              ),
              MortAction(
                label: 'Open support',
                icon: Icons.support_agent,
                onPressed: () => context.go(
                  Uri(
                    path: '/support/new',
                    queryParameters: {
                      'category': 'start_finish_pin',
                      'applicationId': status.applicationId,
                      'jobId': status.jobId,
                      'contractId': status.contractId,
                    },
                  ).toString(),
                ),
              ),
              const MortAction(
                label: 'Safety Center',
                icon: Icons.health_and_safety_outlined,
                route: '/safety',
                style: MortButtonStyle.danger,
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _adultActions(JobExecutionStatus status) {
    final awaitingStart = {
      'awaiting_start',
      'start_pin_active',
    }.contains(status.state);
    final inProgress = {
      'in_progress',
      'finish_pin_active',
    }.contains(status.state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MortSectionTitle(title: 'Adult actions'),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Generate start PIN',
              icon: Icons.pin_outlined,
              enabled: awaitingStart,
              busy: _busy,
              onPressed: () => _generatePin(start: true),
            ),
            MortAction(
              label: 'Generate finish PIN',
              icon: Icons.task_alt,
              enabled: inProgress,
              busy: _busy,
              onPressed: () => _generatePin(start: false),
            ),
            MortAction(
              label: 'Cancel job',
              icon: Icons.cancel_outlined,
              style: MortButtonStyle.danger,
              enabled: !{'completed', 'cancelled'}.contains(status.state),
              busy: _busy,
              onPressed: _cancelJob,
            ),
            MortAction(
              label: 'Report possible abandonment',
              icon: Icons.report_outlined,
              enabled: inProgress,
              busy: _busy,
              onPressed: _reportAbandonment,
            ),
          ],
        ),
      ],
    );
  }

  Widget _teenActions(JobExecutionStatus status) {
    final start = status.state == 'start_pin_active';
    final finish = status.state == 'finish_pin_active';
    final canEnter = start || finish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MortSectionTitle(title: 'Teen actions'),
        if (canEnter) ...[
          TextField(
            controller: _pin,
            maxLength: 6,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: '${start ? 'Start' : 'Finish'} PIN',
              hintText: 'Six digits shared in person',
            ),
          ),
          MortButton(
            label: start ? 'Confirm job start' : 'Confirm job finish',
            icon: start ? Icons.play_arrow : Icons.check_circle_outline,
            busy: _busy,
            onPressed: () => _confirmPin(start: start),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        MortActionRow(
          actions: [
            MortAction(
              label: 'Person mismatch',
              icon: Icons.person_off_outlined,
              style: MortButtonStyle.danger,
              enabled: start,
              busy: _busy,
              onPressed: _reportMismatch,
            ),
            MortAction(
              label: 'Finish PIN refused',
              icon: Icons.lock_clock_outlined,
              enabled: {
                'in_progress',
                'finish_pin_active',
              }.contains(status.state),
              busy: _busy,
              onPressed: () => _finishPinUnavailable(status),
            ),
            MortAction(
              label: 'Respond to abandonment report',
              icon: Icons.reply_outlined,
              enabled: status.state == 'disputed',
              busy: _busy,
              onPressed: _respondToAbandonment,
            ),
          ],
        ),
      ],
    );
  }
}

class _FundingCard extends StatelessWidget {
  const _FundingCard({required this.status});

  final JobExecutionStatus status;

  @override
  Widget build(BuildContext context) => MortCard(
    color: status.fundingStatus == 'funded'
        ? MortColors.neonDeep
        : MortColors.warning.withValues(alpha: 0.12),
    child: Row(
      children: [
        Icon(
          status.fundingStatus == 'funded'
              ? Icons.verified_outlined
              : Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(width: MortSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.fundingStatus == 'funded'
                    ? 'Funds collected'
                    : 'Funding: ${_label(status.fundingStatus)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                status.livePaymentEnabled
                    ? 'Provider status is server-owned.'
                    : 'Live payments remain disabled. This is not escrow and no Flutter action can move money.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProgressTimeline extends StatelessWidget {
  const _ProgressTimeline({required this.state});

  final String state;

  static const ordered = [
    'awaiting_start',
    'start_pin_active',
    'in_progress',
    'finish_pin_active',
    'completion_pending_release',
    'completed',
  ];

  @override
  Widget build(BuildContext context) {
    final current = ordered.indexOf(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MortSectionTitle(title: 'Status timeline'),
        for (var index = 0; index < ordered.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              index < current
                  ? Icons.check_circle
                  : index == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: index <= current ? MortColors.neon : MortColors.textMuted,
            ),
            title: Text(_label(ordered[index])),
          ),
        if (!ordered.contains(state))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline, color: MortColors.warning),
            title: Text(_label(state)),
          ),
      ],
    );
  }
}

class _GeneratedPinCard extends StatelessWidget {
  const _GeneratedPinCard({required this.pin});

  final GeneratedJobPin pin;

  @override
  Widget build(BuildContext context) => MortCard(
    color: MortColors.neonDeep,
    child: Semantics(
      label: 'Generated six digit in-person job PIN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share in person only'),
          Text(
            pin.pin,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(letterSpacing: 8),
          ),
          Text(
            pin.expiresAt == null
                ? 'Expires soon and can be used once.'
                : 'Expires ${DateFormat.jm().format(pin.expiresAt!.toLocal())}. Single use.',
          ),
        ],
      ),
    ),
  );
}

class _StatementDialog extends StatefulWidget {
  const _StatementDialog({
    required this.title,
    required this.label,
    required this.warning,
  });

  final String title;
  final String label;
  final String warning;

  @override
  State<_StatementDialog> createState() => _StatementDialogState();
}

class _StatementDialogState extends State<_StatementDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.warning),
          const SizedBox(height: MortSpacing.sm),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(labelText: widget.label),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = controller.text.trim();
          if (value.length >= 10) Navigator.pop(context, value);
        },
        child: const Text('Submit factual statement'),
      ),
    ],
  );
}

class _FinishStatement {
  const _FinishStatement(this.workCompleted, this.statement);

  final String workCompleted;
  final String statement;
}

class _FinishStatementDialog extends StatefulWidget {
  const _FinishStatementDialog();

  @override
  State<_FinishStatementDialog> createState() => _FinishStatementDialogState();
}

class _FinishStatementDialogState extends State<_FinishStatementDialog> {
  final work = TextEditingController();
  final statement = TextEditingController();

  @override
  void dispose() {
    work.dispose();
    statement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Finish PIN unavailable or refused'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Give factual details. Submission preserves a private review record but does not guarantee payment.',
          ),
          TextField(
            controller: work,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Work completed'),
          ),
          TextField(
            controller: statement,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'What happened?'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (work.text.trim().length >= 10 &&
              statement.text.trim().length >= 10) {
            Navigator.pop(
              context,
              _FinishStatement(work.text.trim(), statement.text.trim()),
            );
          }
        },
        child: const Text('Open private review'),
      ),
    ],
  );
}

class _AbandonmentResponse {
  const _AbandonmentResponse(this.statement, this.safetyRelated);

  final String statement;
  final bool safetyRelated;
}

class _AbandonmentResponseDialog extends StatefulWidget {
  const _AbandonmentResponseDialog();

  @override
  State<_AbandonmentResponseDialog> createState() =>
      _AbandonmentResponseDialogState();
}

class _AbandonmentResponseDialogState
    extends State<_AbandonmentResponseDialog> {
  final statement = TextEditingController();
  bool safetyRelated = false;

  @override
  void dispose() {
    statement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Respond to abandonment report'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The report is an allegation, not a finding. Explain the facts and flag any safety reason.',
          ),
          TextField(
            controller: statement,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Your response'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: safetyRelated,
            onChanged: (value) =>
                setState(() => safetyRelated = value ?? false),
            title: const Text('This involved a safety concern'),
            subtitle: const Text(
              'Safety cancellations cannot automatically receive an abandonment cooldown.',
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
      FilledButton(
        onPressed: () {
          if (statement.text.trim().length >= 10) {
            Navigator.pop(
              context,
              _AbandonmentResponse(statement.text.trim(), safetyRelated),
            );
          }
        },
        child: const Text('Submit response'),
      ),
    ],
  );
}

String _label(String value) => value
    .split('_')
    .map(
      (part) => part.isEmpty
          ? ''
          : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
