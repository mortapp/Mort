import 'package:flutter/material.dart';
import '../../core/theme/mort_colors.dart';
import 'safety_outbox.dart';

/// A backend acknowledgment is not a push delivery receipt.
class SafetyActionReceipt {
  const SafetyActionReceipt({
    this.guardianQueued = 0,
    this.trustedQueued = 0,
    this.sharingExpiresAt,
    this.acknowledgedAt,
  });
  factory SafetyActionReceipt.fromMap(Map<String, dynamic> map) =>
      SafetyActionReceipt(
        guardianQueued: (map['guardian_queued'] as num?)?.toInt() ?? 0,
        trustedQueued: (map['trusted_queued'] as num?)?.toInt() ?? 0,
        sharingExpiresAt: DateTime.tryParse(
          map['sharing_expires_at']?.toString() ?? '',
        ),
        acknowledgedAt: DateTime.tryParse(
          map['acknowledged_at']?.toString() ?? '',
        ),
      );
  final int guardianQueued;
  final int trustedQueued;
  final DateTime? sharingExpiresAt;
  final DateTime? acknowledgedAt;
}

/// Local, immediately available presentation. Construction has no network or
/// authentication side effects. Only explicit action callbacks can send data.
class EmergencyPanel extends StatefulWidget {
  const EmergencyPanel({
    super.key,
    required this.onAlert,
    required this.onCallEmergency,
    required this.onShare,
    this.onLeave,
    this.onCallGuardian,
    this.onCallTrusted,
    this.offline = false,
    this.canSendContacts = true,
  });
  final Future<SafetyActionReceipt> Function() onAlert;
  final Future<void> Function() onCallEmergency;
  final Future<SafetyActionReceipt> Function() onShare;
  final Future<void> Function()? onLeave;
  final Future<void> Function()? onCallGuardian;
  final Future<void> Function()? onCallTrusted;
  final bool offline;
  final bool canSendContacts;
  @override
  State<EmergencyPanel> createState() => _EmergencyPanelState();
}

class _EmergencyPanelState extends State<EmergencyPanel> {
  bool _sending = false;
  String? _message;
  SafetyActionReceipt? _receipt;
  Future<void> _send(Future<SafetyActionReceipt> Function() action) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _message = 'Safety alert waiting to send';
      _receipt = null;
    });
    try {
      final receipt = await action();
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _message = 'Safety alert recorded';
      });
    } catch (error) {
      if (mounted)
        setState(
          () => _message = error is SafetyDispatchFailure
              ? error.message.toString()
              : 'Safety alert not confirmed. Use the calling options or try again.',
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _call(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(() => _message = 'Call could not open. Use your Phone app.');
    }
  }

  Widget _action(
    String label,
    IconData icon,
    VoidCallback? callback, {
    bool urgent = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        backgroundColor: urgent ? MortColors.danger : MortColors.graphite4,
        foregroundColor: MortColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center),
      onPressed: callback,
    ),
  );
  @override
  Widget build(BuildContext context) => Material(
    color: MortColors.ink2,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: DefaultTextStyle(
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: MortColors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: MortColors.silver),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('MORT Safety')),
                  if (Navigator.of(context).canPop())
                    IconButton(
                      tooltip: 'Close Emergency',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: MortColors.silver),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Need help?',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: MortColors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choose what you need. You're always allowed to leave a job.",
              ),
              const SizedBox(height: 24),
              if (widget.offline) ...[
                const Text('No data connection'),
                const Text(
                  'MORT cannot reach safety contacts through the app right now. Calling options remain available.',
                ),
                const SizedBox(height: 16),
              ],
              if (!widget.canSendContacts)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Teen Safety Contact alerts are unavailable for this account. Calling options remain available.',
                  ),
                ),
              if (widget.canSendContacts)
                _action(
                  'Alert My Safety Contacts',
                  Icons.notification_important_outlined,
                  _sending ? null : () => _send(widget.onAlert),
                  urgent: true,
                ),
              _action(
                'Call 911',
                Icons.call_outlined,
                () => _call(widget.onCallEmergency),
              ),
              if (widget.onLeave != null)
                _action(
                  'Leave This Job',
                  Icons.exit_to_app_rounded,
                  () => _call(widget.onLeave!),
                ),
              if (widget.canSendContacts)
                _action(
                  'Share Live Location',
                  Icons.location_on_outlined,
                  _sending ? null : () => _send(widget.onShare),
                ),
              if (widget.onCallGuardian != null)
                _action(
                  'Call Guardian',
                  Icons.call_outlined,
                  () => _call(widget.onCallGuardian!),
                ),
              if (widget.onCallTrusted != null)
                _action(
                  'Call Trusted Contact',
                  Icons.call_outlined,
                  () => _call(widget.onCallTrusted!),
                ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Semantics(liveRegion: true, child: Text(_message!)),
              ],
              if (_receipt != null) ...[
                Text(
                  _receipt!.guardianQueued > 0
                      ? 'Guardian: queued for delivery'
                      : 'Guardian: no enabled contact',
                ),
                Text(
                  _receipt!.trustedQueued > 0
                      ? 'Trusted contact: queued for delivery'
                      : 'Trusted contact: no enabled contact',
                ),
                const Text('Device delivery has not been confirmed.'),
                if (_receipt!.sharingExpiresAt != null)
                  Text(
                    'Sharing ends at ${TimeOfDay.fromDateTime(_receipt!.sharingExpiresAt!.toLocal()).format(context)}. Manage sharing in Safety Center.',
                  ),
              ],
              const SizedBox(height: 24),
              const Text(
                'MORT does not dispatch emergency services or guarantee a response.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
