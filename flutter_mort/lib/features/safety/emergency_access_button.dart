import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../data/models/profile.dart';
import '../../data/services/supabase_service.dart';
import 'emergency_panel.dart';
import 'safety_device_status.dart';
import 'safety_outbox.dart';
import 'safety_location_consent.dart';
import 'safety_contact_call.dart';
import 'dart:async';

/// Emergency-only access never unlocks or reveals the account behind the gate.
class EmergencyAccessButton extends ConsumerStatefulWidget {
  const EmergencyAccessButton({super.key, this.applicationId});
  final String? applicationId;
  @override
  ConsumerState<EmergencyAccessButton> createState() =>
      _EmergencyAccessButtonState();
}

class _EmergencyAccessButtonState extends ConsumerState<EmergencyAccessButton> {
  final Map<String, String> _requests = {};
  final Map<String, DateTime> _requestTimes = {};
  Future<SafetyActionReceipt> _send(
    String action, {
    String? application,
  }) async {
    final owner = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (owner == null)
      throw StateError('Sign-in unavailable. Use calling options.');
    final key = '$owner:$action:$application';
    final request = _requests.putIfAbsent(key, () => const Uuid().v4());
    final requestedAt = _requestTimes.putIfAbsent(
      key,
      () => DateTime.now().toUtc(),
    );
    Future<Map<String, dynamic>> dispatch() => ref
        .read(safetyRepositoryProvider)
        .performAction(
          action: action,
          applicationId: application,
          payload: {
            'actor_id': owner,
            'requested_at': requestedAt.toIso8601String(),
          },
          clientRequestId: request,
        )
        .timeout(const Duration(seconds: 8));
    final result = action == 'alert' || action == 'exit'
        ? await ref
              .read(safetyOutboxProvider)
              .dispatchCritical(
                userId: owner,
                requestId: request,
                action: action,
                applicationId: application,
                requestedAt: requestedAt,
                dispatch: dispatch,
              )
        : await dispatch();
    _requests.remove(key);
    _requestTimes.remove(key);
    safetyMonitorRefresh.value++;
    if (action == 'share') unawaited(requestSafetyLocationConsent());
    return SafetyActionReceipt.fromMap(result);
  }

  Future<void> _call() async {
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: '911'));
      if (mounted)
        MortToast.show(
          context,
          opened
              ? 'Emergency call opened'
              : 'Open your Phone app and call 911.',
        );
    } catch (_) {
      if (mounted) MortToast.show(context, 'Open your Phone app and call 911.');
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (dialog) => AlertDialog(
        title: const Text('Leave this job for safety?'),
        content: const Text(
          "You can leave now without the poster's permission or Finish PIN. If MORT is offline, the job record may need to be updated after reconnecting.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Stay at Job'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Leave Now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      var application = widget.applicationId;
      final owner = SupabaseService.isInitialized
          ? SupabaseService.client.auth.currentUser?.id
          : null;
      if (application == null && owner != null) {
        try {
          application = await ref
              .read(safetyOutboxProvider)
              .cachedActiveJob(owner);
        } catch (_) {
          /* Fall back to server context; never invent a job. */
        }
      }
      if (application == null) {
        final runtime = await ref
            .read(safetyRepositoryProvider)
            .getRuntime()
            .timeout(const Duration(seconds: 5));
        application = runtime['application_id']?.toString();
      }
      if (application == null) throw StateError('No confirmed job context');
      await _send('exit', application: application);
      if (mounted)
        MortToast.show(context, 'Safety Exit recorded. You can leave now.');
    } catch (_) {
      if (mounted)
        MortToast.show(
          context,
          'You can leave now. The job record was not confirmed. Use calling options and update MORT when connected.',
        );
    }
  }

  void _open() {
    final role = ref.read(currentProfileProvider).asData?.value?.role;
    // A missing profile read must not remove Emergency actions from a signed-in
    // device. The server independently requires an active minor teen for sends.
    final canAttemptTeenSafety =
        role == UserRole.teen ||
        (role == null &&
            SupabaseService.isInitialized &&
            SupabaseService.client.auth.currentUser != null);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: ValueListenableBuilder<SafetyDeviceStatus>(
          valueListenable: safetyDeviceStatus,
          builder: (_, status, _) => EmergencyPanel(
            canSendContacts: canAttemptTeenSafety,
            offline: !status.connected,
            onAlert: () => _send('alert', application: widget.applicationId),
            onShare: () => _send('share', application: widget.applicationId),
            onCallEmergency: _call,
            onCallGuardian: () =>
                openKnownSafetyContactCall(context, 'Guardian'),
            onCallTrusted: () =>
                openKnownSafetyContactCall(context, 'Trusted Contact'),
            onLeave: canAttemptTeenSafety ? _leave : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MortButton(
    label: 'Emergency',
    icon: Icons.emergency_outlined,
    style: MortButtonStyle.danger,
    onPressed: _open,
  );
}
