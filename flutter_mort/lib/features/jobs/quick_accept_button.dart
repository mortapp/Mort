import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/mort_error.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/application.dart';
import '../../data/models/job.dart';
import '../../data/repositories/providers.dart';

enum _QuickAcceptState {
  available,
  claiming,
  accepted,
  offerTaken,
  notEligible,
  expired,
  networkError,
}

/// The Teen-facing Quick Accept CTA for a single-worker job that has opted
/// into quick_accept_eligible. The server (quick_accept_job_v1) is the
/// sole source of truth for who wins a claim -- this widget never shows
/// success before the RPC actually confirms it, and shows a clean "Offer
/// taken" state rather than a raw error when another Teen wins first.
///
/// Renders nothing for jobs that aren't quick-accept eligible -- those
/// keep using the existing regular Apply flow elsewhere.
class QuickAcceptButton extends ConsumerStatefulWidget {
  const QuickAcceptButton({super.key, required this.job, this.onAccepted});

  final Job job;
  final ValueChanged<MortApplication>? onAccepted;

  @override
  ConsumerState<QuickAcceptButton> createState() => _QuickAcceptButtonState();
}

class _QuickAcceptButtonState extends ConsumerState<QuickAcceptButton> {
  _QuickAcceptState _state = _QuickAcceptState.available;
  String? _message;

  bool get _isGenuinelyExpired {
    final expiresAt = widget.job.expiresAt;
    return expiresAt != null && expiresAt.isBefore(DateTime.now());
  }

  Future<void> _accept() async {
    if (_state == _QuickAcceptState.claiming) return;
    setState(() => _state = _QuickAcceptState.claiming);
    try {
      final application = await ref
          .read(applicationsRepositoryProvider)
          .quickAccept(widget.job.id);
      if (!mounted) return;
      setState(() => _state = _QuickAcceptState.accepted);
      widget.onAccepted?.call(application);
    } on MortCodedError catch (error) {
      if (!mounted) return;
      setState(() {
        _message = userFacingError(error);
        _state = error.code == 'offer_taken'
            ? _QuickAcceptState.offerTaken
            : _QuickAcceptState.notEligible;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = userFacingError(error);
        _state = _QuickAcceptState.networkError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.job.quickAcceptEligible) return const SizedBox.shrink();

    if (_state == _QuickAcceptState.available && _isGenuinelyExpired) {
      _state = _QuickAcceptState.expired;
    }

    return switch (_state) {
      _QuickAcceptState.available => MortPrimaryButton(
        label: 'Accept',
        icon: Icons.bolt_rounded,
        onPressed: _accept,
      ),
      _QuickAcceptState.claiming => const MortPrimaryButton(
        label: 'Claiming...',
        busy: true,
        onPressed: null,
      ),
      _QuickAcceptState.accepted => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: MortColors.success),
          const SizedBox(width: MortSpacing.xs),
          Text(
            'Accepted',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: MortColors.success),
          ),
        ],
      ),
      _QuickAcceptState.offerTaken => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.block_flipped,
            color: MortColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: MortSpacing.xs),
          Text('Offer taken', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      _QuickAcceptState.expired => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_off_outlined,
            color: MortColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: MortSpacing.xs),
          Text('Offer expired', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      _QuickAcceptState.notEligible => Tooltip(
        message: _message ?? 'This offer is not available to you.',
        child: const MortSecondaryButton(
          label: 'Not eligible',
          onPressed: null,
        ),
      ),
      _QuickAcceptState.networkError => MortSecondaryButton(
        label: 'Retry accept',
        icon: Icons.refresh_rounded,
        onPressed: _accept,
      ),
    };
  }
}
