import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../core/theme/mort_spacing.dart';
import '../../data/repositories/providers.dart';
import 'emergency_access_button.dart';
import 'safety_contact_call.dart';
import 'safety_sharing_countdown.dart';
import 'dart:async';

class SafetyEventScreen extends ConsumerStatefulWidget {
  const SafetyEventScreen({super.key, required this.eventId});
  final String eventId;
  @override
  ConsumerState<SafetyEventScreen> createState() => _SafetyEventScreenState();
}

class _SafetyEventScreenState extends ConsumerState<SafetyEventScreen> {
  late Future<Map<String, dynamic>> _future;
  Timer? _poll;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _future = _load();
    // Reauthorize each refresh, including expiry and contact revocation.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_loading) _refresh();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    final result = _loadChecked();
    // FutureBuilder attaches on the next frame; an immediate denied response
    // must already have an error observer without losing its error snapshot.
    result.ignore();
    return result;
  }

  Future<Map<String, dynamic>> _loadChecked() async {
    _loading = true;
    try {
      return await ref
          .read(safetyRepositoryProvider)
          .getSafetyEvent(widget.eventId)
          .timeout(const Duration(seconds: 8));
    } finally {
      _loading = false;
    }
  }

  void _refresh() => setState(() {
    _future = _load();
  });
  Future<void> _contact(String target) async {
    try {
      final id = await ref
          .read(safetyRepositoryProvider)
          .openSafetyContact(widget.eventId, target);
      if (mounted) context.push('/safety/contact/$id');
    } catch (_) {
      if (mounted)
        MortToast.show(
          context,
          'Safety Contact not confirmed. Access may have ended.',
        );
    }
  }

  Future<void> _reached() async {
    final safe = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Were you able to confirm they are okay?'),
        content: const Text(
          'Your response does not count as a teen device check-in. MORT keeps watching for the device to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('They Need Help'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text("Yes, They're Safe"),
          ),
        ],
      ),
    );
    if (safe == null || !mounted) return;
    if (!safe) {
      await showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Emergency Options'),
          content: EmergencyAccessButton(),
        ),
      );
      return;
    }
    try {
      await ref
          .read(safetyRepositoryProvider)
          .recordContactReached(widget.eventId);
      if (mounted)
        MortToast.show(
          context,
          'Your contact response was recorded. The teen’s safety status was not changed.',
        );
    } catch (_) {
      if (mounted)
        MortToast.show(context, 'Contact response not confirmed. Try again.');
    }
  }

  Future<void> _location(Map<String, dynamic> event) async {
    final latitude = event['latitude'];
    final longitude = event['longitude'];
    if (latitude is! num || longitude is! num) return;
    try {
      final opened = await launchUrl(
        Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': '$latitude,$longitude',
        }),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) MortToast.show(context, 'Could not open Maps.');
    } catch (_) {
      if (mounted) MortToast.show(context, 'Could not open Maps.');
    }
  }

  @override
  Widget build(BuildContext context) => MortScreen(
    atmosphereIntensity: MortAtmosphereIntensity.midnight,
    children: [
      const MortHeader(
        eyebrow: 'Free Safety',
        title: 'Safety event',
        subtitle:
            'Only this authorized event is shared. Connection loss does not necessarily mean danger.',
      ),
      const EmergencyAccessButton(),
      const SizedBox(height: MortSpacing.md),
      FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const MortErrorState(
              title: 'Safety event unavailable',
              message:
                  'Access may have ended, the link may have changed, or MORT may be offline.',
            );
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData)
            return const MortLoading(
              label: 'Loading authorized event...',
              fullScreen: false,
            );
          final event = snapshot.data!;
          final lastLocation = event['last_location_at']?.toString();
          final expires = DateTime.tryParse(
            event['sharing_expires_at']?.toString() ?? '',
          );
          return MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  event['teen_name']?.toString() ?? 'Linked teen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Safety status: ${event['safety_state'] ?? 'unavailable'}',
                ),
                Text(
                  'Last confirmed battery: ${event['battery_percent'] ?? 'unavailable'}${event['battery_percent'] == null ? '' : '%'}',
                ),
                Text(
                  'Last check-in: ${event['last_checkin_at'] ?? 'unavailable'}',
                ),
                Text(
                  'Last connection: ${event['last_seen_at'] ?? 'unavailable'}',
                ),
                SafetySharingCountdown(
                  expiresAt: event['live_sharing'] == true ? expires : null,
                ),
                Text(
                  'Last known location time: ${lastLocation ?? 'unavailable'}',
                ),
                if (event['latitude'] is num && event['longitude'] is num)
                  MortButton(
                    label: 'View Last Known Location',
                    style: MortButtonStyle.secondary,
                    onPressed: () => _location(event),
                  ),
                MortButton(
                  label: 'I Reached Them',
                  style: MortButtonStyle.secondary,
                  onPressed: _reached,
                ),
                MortButton(
                  label: 'Message Teen',
                  style: MortButtonStyle.secondary,
                  onPressed: () => _contact('teen'),
                ),
                MortButton(
                  label: 'Call Teen',
                  style: MortButtonStyle.secondary,
                  onPressed: () => openKnownSafetyContactCall(
                    context,
                    event['teen_name']?.toString() ?? 'Teen',
                  ),
                ),
                if (event['job_id'] != null)
                  MortButton(
                    label: 'Urgent Contact Poster',
                    style: MortButtonStyle.secondary,
                    onPressed: () => _contact('poster'),
                  ),
                const Text(
                  'MORT has not contacted emergency services or dispatched physical help.',
                ),
              ],
            ),
          );
        },
      ),
      TextButton(
        onPressed: _refresh,
        child: const Text('Refresh safety event'),
      ),
    ],
  );
}
