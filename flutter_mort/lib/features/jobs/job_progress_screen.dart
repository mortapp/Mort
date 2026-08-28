import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/preferences/mort_experience_preferences.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/theme/mort_tokens.dart';
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

class _JobProgressScreenState extends ConsumerState<JobProgressScreen>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 5);
  static const _settlementPollInterval = Duration(seconds: 30);
  static const _terminalStates = {'completed', 'cancelled'};

  final _pin = TextEditingController();
  JobExecutionStatus? _current;
  Object? _loadError;
  bool _initialLoading = true;
  GeneratedJobPin? _generatedPin;
  String? _startConfirmationRequestId;
  String? _startConfirmationPin;
  String? _finishConfirmationRequestId;
  String? _finishConfirmationPin;
  bool _busy = false;
  bool _statusFetchInFlight = false;
  bool _statusRefreshPending = false;
  bool _pollingEnabled = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshAndSchedule(showSpinner: true));
  }

  @override
  void dispose() {
    _pollingEnabled = false;
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollingEnabled = true;
      unawaited(_refreshAndSchedule(showSpinner: false));
    } else {
      _pollingEnabled = false;
      _pollTimer?.cancel();
    }
  }

  Future<void> _refreshAndSchedule({required bool showSpinner}) async {
    await _fetchStatus(showSpinner: showSpinner);
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    final state = _current?.state;
    if (!_pollingEnabled ||
        !mounted ||
        widget.syntheticStatusForTesting != null ||
        (state != null && _terminalStates.contains(state))) {
      return;
    }
    final delay = state == 'completion_pending_release'
        ? _settlementPollInterval
        : _pollInterval;
    _pollTimer = Timer(delay, () async {
      final latestState = _current?.state;
      if (!_pollingEnabled ||
          !mounted ||
          (latestState != null && _terminalStates.contains(latestState))) {
        return;
      }
      if (!_busy && !_statusFetchInFlight) {
        await _fetchStatus(showSpinner: false);
      }
      _scheduleNextPoll();
    });
  }

  Future<void> _fetchStatus({required bool showSpinner}) async {
    if (_statusFetchInFlight) {
      _statusRefreshPending = true;
      return;
    }
    if (widget.syntheticStatusForTesting != null) {
      if (mounted) {
        setState(() {
          _current = widget.syntheticStatusForTesting;
          _initialLoading = false;
        });
      }
      return;
    }
    _statusFetchInFlight = true;
    if (showSpinner && mounted) {
      setState(() {
        _initialLoading = _current == null;
        _loadError = null;
      });
    }
    try {
      final status = await ref
          .read(jobExecutionRepositoryProvider)
          .getStatus(widget.applicationId);
      if (!mounted) return;
      setState(() {
        _current = status;
        _initialLoading = false;
        _loadError = null;
        final generatedPin = _generatedPin;
        if (generatedPin != null) {
          final generatedPinIsActive = switch (generatedPin.kind) {
            JobPinKind.start => status.startPinActive,
            JobPinKind.finish => status.finishPinActive,
          };
          if (!generatedPinIsActive) _generatedPin = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        if (_current == null) _loadError = error;
      });
    } finally {
      _statusFetchInFlight = false;
      final refreshAgain = _statusRefreshPending && mounted && !_busy;
      if (refreshAgain) {
        _statusRefreshPending = false;
        await _fetchStatus(showSpinner: false);
      }
    }
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
        await _fetchStatus(showSpinner: false);
      }
      return result;
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
      return null;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_statusRefreshPending) {
          _statusRefreshPending = false;
          unawaited(_fetchStatus(showSpinner: false));
        }
      }
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
    final previousPin = start ? _startConfirmationPin : _finishConfirmationPin;
    if (previousPin != value) {
      if (start) {
        _startConfirmationPin = value;
        _startConfirmationRequestId = const Uuid().v4();
      } else {
        _finishConfirmationPin = value;
        _finishConfirmationRequestId = const Uuid().v4();
      }
    }
    final result = await _perform(
      () => start
          ? repository.confirmStartPin(
              applicationId: widget.applicationId,
              pin: value,
              personMatchesProfile: true,
              clientRequestId: _startConfirmationRequestId,
            )
          : repository.confirmFinishPin(
              applicationId: widget.applicationId,
              pin: value,
              clientRequestId: _finishConfirmationRequestId,
            ),
      success: start
          ? 'Start confirmed. The job is now in progress.'
          : 'Completion recorded. Funds remain pending during review.',
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _pin.clear();
        if (start) {
          _startConfirmationPin = null;
          _startConfirmationRequestId = null;
        } else {
          _finishConfirmationPin = null;
          _finishConfirmationRequestId = null;
        }
      });
      MortHaptics.success(context);
    } else {
      MortHaptics.warning(context);
    }
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

  /// Interim navigation UX (see docs/MORT_NAVIGATION_SDK_RESEARCH.md):
  /// launches the device's default maps app with the job-site
  /// coordinates, rather than a full in-app turn-by-turn SDK (deferred
  /// pending the owner's routing-provider/billing decision). The
  /// coordinates are only ever obtained via the same lifecycle-gated
  /// get_released_job_location RPC used elsewhere -- this never renders
  /// a persistent, copyable address in MORT's own UI, and access follows
  /// the job's real state (revoked on completion/cancellation/block).
  Future<void> _navigateToJobSite() async {
    try {
      final result = await ref
          .read(trustSafetyRepositoryProvider)
          .getReleasedJobLocation(widget.applicationId);
      final lat = result['latitude'] as num?;
      final lng = result['longitude'] as num?;
      if (lat == null || lng == null) {
        if (mounted) {
          MortToast.show(
            context,
            'Navigation is not available for this job yet.',
          );
        }
        return;
      }
      final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        MortToast.show(context, 'Could not open a maps app on this device.');
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    }
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
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const MortLoading(label: 'Loading server job progress...');
    }
    if (_current == null) {
      return MortScreen(
        children: [
          MortErrorState(
            title: 'Job progress unavailable',
            message: userFacingError(_loadError),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => _fetchStatus(showSpinner: true),
            ),
          ),
        ],
      );
    }
    final status = _current!;
    return RefreshIndicator(
      onRefresh: () => _fetchStatus(showSpinner: false),
      child: MortScreen(
        children: [
          MortHeader(
            eyebrow: 'Server-owned job status - updates automatically',
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
          if ({
            'completion_pending_release',
            'completed',
          }.contains(status.state)) ...[
            _CompletionCard(status: status),
            const SizedBox(height: MortSpacing.md),
          ],
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
              if (status.isTeen)
                MortAction(
                  label: 'Navigate to job site',
                  icon: Icons.directions_rounded,
                  onPressed: _navigateToJobSite,
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
      ),
    );
  }

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
          MortGlassCard(
            infoAccent: true,
            child: Column(
              children: [
                Icon(
                  start
                      ? Icons.lock_open_outlined
                      : Icons.verified_user_outlined,
                  size: 42,
                  color: MortColors.lightBlue,
                ),
                const SizedBox(height: MortSpacing.xs),
                Text(
                  start ? 'Start job' : 'End job',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: MortSpacing.xs),
                Text(
                  'Enter the separate six-digit ${start ? 'start' : 'finish'} PIN shared by the adult in person.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MortSpacing.md),
                MortPinPad(
                  value: _pin.text,
                  enabled: !_busy,
                  onChanged: (value) => setState(() => _pin.text = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
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

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.status});

  final JobExecutionStatus status;

  @override
  Widget build(BuildContext context) => MortGlassCard(
    child: Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: MortColors.roseGoldLight),
            boxShadow: MortShadows.glow,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: MortColors.roseGoldLight,
            size: 48,
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        Text(
          status.state == 'completed' ? 'Job complete' : 'Completion recorded',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: MortSpacing.xs),
        Text(
          status.completionPendingAt == null
              ? 'The server recorded the finish confirmation.'
              : 'Recorded ${DateFormat.yMMMd().add_jm().format(status.completionPendingAt!.toLocal())}.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MortSpacing.sm),
        const MortStatusChip(
          label: 'Payment under review',
          icon: Icons.schedule_rounded,
          color: MortColors.lightBlue,
        ),
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Leave a rating',
              icon: Icons.star_outline_rounded,
              route: '/reviews/${status.applicationId}',
            ),
            MortAction(
              label: 'Report issue',
              icon: Icons.report_outlined,
              route: '/report/job/${status.jobId}',
              style: MortButtonStyle.danger,
            ),
            MortAction(
              label: 'Return home',
              icon: Icons.home_outlined,
              route: status.isAdult ? '/adult/home' : '/teen/home',
            ),
          ],
        ),
      ],
    ),
  );
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
    return MortGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MortSectionTitle(title: 'Status timeline'),
          MortTimeline(
            steps: [
              for (var index = 0; index < ordered.length; index++)
                MortTimelineStep(
                  title: _label(ordered[index]),
                  detail: index == current ? 'Current server status' : null,
                  complete: index <= current,
                ),
            ],
          ),
          if (!ordered.contains(state))
            MortStatusChip(
              label: _label(state),
              icon: Icons.info_outline_rounded,
              color: MortColors.warning,
            ),
        ],
      ),
    );
  }
}

class _GeneratedPinCard extends StatefulWidget {
  const _GeneratedPinCard({required this.pin});

  final GeneratedJobPin pin;

  @override
  State<_GeneratedPinCard> createState() => _GeneratedPinCardState();
}

class _GeneratedPinCardState extends State<_GeneratedPinCard> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _restartTicker();
  }

  @override
  void didUpdateWidget(covariant _GeneratedPinCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pin.pin != widget.pin.pin ||
        oldWidget.pin.expiresAt != widget.pin.expiresAt) {
      _restartTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _restartTicker() {
    _ticker?.cancel();
    _tick();
    if (_remaining > Duration.zero) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _tick() {
    final expiresAt = widget.pin.expiresAt;
    final remaining = expiresAt == null
        ? Duration.zero
        : expiresAt.toUtc().difference(DateTime.now().toUtc());
    if (!mounted) return;
    final next = remaining.isNegative ? Duration.zero : remaining;
    if (next != _remaining) setState(() => _remaining = next);
    if (expiresAt != null && next == Duration.zero) _ticker?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = widget.pin.expiresAt;
    final expired = expiresAt != null && _remaining == Duration.zero;
    final low = !expired && _remaining.inSeconds <= 30;
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    return MortCard(
      color: expired
          ? MortColors.warning.withValues(alpha: 0.12)
          : MortColors.neonDeep,
      child: Semantics(
        label: 'Generated six digit in-person job PIN',
        liveRegion: expired || _remaining.inSeconds == 30,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share in person only'),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.pin.pin,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(letterSpacing: 8),
              ),
            ),
            if (expiresAt == null)
              const Text('Expires soon and can be used once.')
            else if (expired)
              const Text(
                'This PIN expired. Generate a new one in person.',
                style: TextStyle(color: MortColors.danger),
              )
            else
              Text(
                'Expires in ${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}. Single use.',
                style: low ? const TextStyle(color: MortColors.danger) : null,
              ),
          ],
        ),
      ),
    );
  }
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
