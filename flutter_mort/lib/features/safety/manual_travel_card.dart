import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import 'safety_device_status.dart';
import 'safety_location_consent.dart';
import 'package:go_router/go_router.dart';

class ManualTravelCard extends ConsumerStatefulWidget {
  const ManualTravelCard({
    super.key,
    required this.applicationId,
    required this.isTeen,
    this.onReschedule,
  });
  final String applicationId;
  final bool isTeen;
  final VoidCallback? onReschedule;
  @override
  ConsumerState<ManualTravelCard> createState() => _ManualTravelCardState();
}

class _ManualTravelCardState extends ConsumerState<ManualTravelCard> {
  Map<String, dynamic>? _runtime;
  String? _error;
  bool _busy = false;
  bool _loading = false;
  String _travelMode = 'WALK';
  final Map<String, String> _requests = {};
  @override
  void initState() {
    super.initState();
    safetyMonitorRefresh.addListener(_refresh);
    _load();
  }

  void _refresh() {
    if (mounted && !_loading) _load();
  }

  @override
  void dispose() {
    safetyMonitorRefresh.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final value = await ref
          .read(safetyRepositoryProvider)
          .getJobRuntime(widget.applicationId)
          .timeout(const Duration(seconds: 8));
      if (mounted)
        setState(() {
          _runtime = value;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Travel status not confirmed. Emergency remains available.',
        );
    } finally {
      _loading = false;
    }
  }

  Future<void> _act(String action) async {
    if (_busy) return;
    if (action == 'travel') {
      final agreed = await showDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, update) => AlertDialog(
            title: const Text("I'm On My Way"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MORT uses location while open and may send it to Google Routes for an arrival estimate. The poster sees only an estimate and arrival status. Walking and cycling estimates can miss safe paths; follow local conditions. Charge your phone, bring a charger if possible, and keep notifications enabled. Low battery does not block attendance.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: _travelMode,
                  decoration: const InputDecoration(
                    labelText: 'How are you traveling?',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'WALK', child: Text('Walking')),
                    DropdownMenuItem(value: 'DRIVE', child: Text('Car / ride')),
                    DropdownMenuItem(value: 'BICYCLE', child: Text('Bicycle')),
                    DropdownMenuItem(
                      value: 'TRANSIT',
                      child: Text('Public transit'),
                    ),
                  ],
                  onChanged: (value) =>
                      update(() => _travelMode = value ?? 'WALK'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Start Trip'),
              ),
            ],
          ),
        ),
      );
      if (agreed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .performAction(
            action: action,
            applicationId: widget.applicationId,
            payload: action == 'travel'
                ? {'travel_mode': _travelMode}
                : const {},
            clientRequestId: _requests.putIfAbsent(
              action == 'travel' ? '$action:$_travelMode' : action,
              () => const Uuid().v4(),
            ),
          );
      _requests.remove(action == 'travel' ? '$action:$_travelMode' : action);
      if (action == 'travel' || action == 'continue_trip')
        await requestSafetyLocationConsent();
      safetyMonitorRefresh.value++;
      await _load();
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error = 'Travel change not confirmed. Try again when connected.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _posterResponse(String response) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          response == 'cancel_connection'
              ? 'Cancel for connection / safety issue?'
              : 'Record your response?',
        ),
        content: const Text(
          'This does not start the job, mark the worker safe or prove a no-show. Payment concerns remain subject to review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(safetyRepositoryProvider)
          .recordPosterConnectionResponse(
            widget.applicationId,
            response,
            _requests.putIfAbsent(response, () => const Uuid().v4()),
          );
      _requests.remove(response);
      if (mounted)
        MortToast.show(
          context,
          'Response recorded. Worker safety is not confirmed by this statement.',
        );
      await _load();
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Response not confirmed. Retry when connected.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final travel = _runtime?['travel_state']?.toString() ?? 'off';
    final accepted = _runtime?['job_status'] == 'accepted';
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MortSectionTitle(title: 'Travel Safety'),
          Text(
            _runtime?['connection_lost'] == true
                ? 'Worker Connection Issue. A lost connection does not prove a no-show.'
                : travel == 'arrived'
                ? 'Arrived — confirmed by the worker'
                : travel == 'traveling'
                ? 'On the way'
                : travel == 'reconfirm'
                ? 'Are you still on your way?'
                : 'Travel sharing is off',
          ),
          Text(
            _runtime?['eta_range_min'] == null
                ? 'ETA unavailable. Exact moving location is hidden from the poster.'
                : 'Estimated arrival: ${_runtime!['eta_range_min']}–${_runtime!['eta_range_max']} minutes. Exact location is hidden from the poster.',
          ),
          if (_runtime?['nearby'] == true)
            const Text(
              'Nearby — estimated within 10 minutes. Arrival is not confirmed.',
            ),
          if (_error != null) Text(_error!),
          if (widget.isTeen && accepted) ...[
            if (travel == 'off')
              MortButton(
                label: "I'm On My Way",
                onPressed: _busy ? null : () => _act('travel'),
              ),
            if (travel == 'reconfirm')
              MortButton(
                label: 'Yes, Continue Trip',
                onPressed: _busy ? null : () => _act('continue_trip'),
              ),
            if (travel == 'traveling' || travel == 'reconfirm')
              MortButton(
                label: 'Cancel Trip',
                style: MortButtonStyle.secondary,
                onPressed: _busy ? null : () => _act('stop_trip'),
              ),
            MortButton(
              label: "I'm Here",
              style: MortButtonStyle.secondary,
              onPressed: _busy ? null : () => _act('arrived'),
            ),
            const Text(
              'Arrival does not start the job. Enter the poster’s temporary Start PIN in person.',
            ),
          ],
          if (widget.isTeen && _runtime?['final_safety_pending'] == true)
            MortButton(
              label: "I left safely — I'm Safe",
              onPressed: _busy ? null : () => _act('final_safe'),
            ),
          if (!widget.isTeen && widget.onReschedule != null)
            MortButton(
              label: 'Reschedule Job',
              style: MortButtonStyle.secondary,
              onPressed: widget.onReschedule,
            ),
          if (!widget.isTeen &&
              accepted &&
              _runtime?['connection_lost'] == true) ...[
            for (final response in const {
              'wait_for_worker': 'Wait for Worker',
              'worker_arrived_device_unavailable':
                  'Worker Arrived but Device Unavailable',
              'wait_for_device': 'Wait for Device',
              'cancel_connection': 'Cancel for Connection / Safety Issue',
            }.entries)
              MortButton(
                label: response.value,
                style: MortButtonStyle.secondary,
                onPressed: _busy ? null : () => _posterResponse(response.key),
              ),
            TextButton(
              onPressed: _runtime?['job_id'] == null
                  ? null
                  : () => context.push('/report/job/${_runtime!['job_id']}'),
              child: const Text('Report Arrival Issue'),
            ),
            const Text(
              'Only the worker can confirm the Start PIN from their own account. Device loss is not proof of abandonment.',
            ),
          ],
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Refresh travel status'),
          ),
        ],
      ),
    );
  }
}
