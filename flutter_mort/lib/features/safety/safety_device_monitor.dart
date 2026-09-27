import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';
import '../../data/services/supabase_service.dart';
import 'safety_battery_policy.dart';
import 'safety_device_status.dart';
import 'safety_outbox.dart';

/// Foreground-only monitoring. The server detects a lost heartbeat if the OS
/// suspends this app; no promise of terminated-app GPS or push delivery.
class SafetyDeviceMonitor extends ConsumerStatefulWidget {
  const SafetyDeviceMonitor({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<SafetyDeviceMonitor> createState() =>
      _SafetyDeviceMonitorState();
}

class _SafetyDeviceMonitorState extends ConsumerState<SafetyDeviceMonitor>
    with WidgetsBindingObserver {
  static const _power = MethodChannel('mort/native_security');
  SafetyOutbox get _outbox => ref.read(safetyOutboxProvider);
  Timer? _timer;
  bool _visible = true;
  bool _busy = false;
  String? _owner;
  DateTime? _lastPositionAt;
  Position? _lastPosition;
  bool _criticalSnapshotAttempted = false;
  DateTime? _sampleAt;
  int? _samplePercent;
  DateTime? _lastRuntimeAt;
  Map<String, dynamic>? _runtime;
  String? _currentUser() => SupabaseService.isInitialized
      ? SupabaseService.client.auth.currentUser?.id
      : null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    safetyMonitorRefresh.addListener(_refresh);
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_tick()),
    );
    unawaited(_tick());
  }

  void _refresh() {
    _lastRuntimeAt = null;
    unawaited(_tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (_visible) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    safetyMonitorRefresh.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _tick() async {
    if (_busy || !_visible || !mounted) return;
    final profile = ref.read(currentProfileProvider).asData?.value;
    final owner = _currentUser();
    if (_owner != owner) {
      _owner = owner;
      _runtime = null;
      _lastRuntimeAt = null;
      _samplePercent = null;
      _sampleAt = null;
      _lastPositionAt = null;
      _lastPosition = null;
      _criticalSnapshotAttempted = false;
      safetySaverOverride.value = null;
      safetyDeviceStatus.value = const SafetyDeviceStatus();
    }
    if (owner == null || profile?.id != owner || profile?.role != UserRole.teen)
      return;
    _busy = true;
    try {
      final repository = ref.read(safetyRepositoryProvider);
      try {
        await _outbox.flush(
          userId: owner,
          currentUserId: _currentUser,
          dispatch: (entry) async {
            await repository
                .performAction(
                  action: entry.action,
                  applicationId: entry.applicationId,
                  payload: {
                    'actor_id': entry.userId,
                    'requested_at': entry.requestedAt.toUtc().toIso8601String(),
                  },
                  clientRequestId: entry.requestId,
                )
                .timeout(const Duration(seconds: 8));
          },
        );
      } catch (_) {
        /* Queue storage failure must not prevent device sync. */
      }
      if (_currentUser() != owner || !_visible) return;
      final now = DateTime.now();
      if (_lastRuntimeAt == null ||
          now.difference(_lastRuntimeAt!) >= const Duration(minutes: 1)) {
        _runtime = await repository.getRuntime().timeout(
          const Duration(seconds: 8),
        );
        _lastRuntimeAt = now;
      }
      if (_currentUser() != owner || !_visible) return;
      final expires = DateTime.tryParse(
        _runtime?['sharing_expires_at']?.toString() ?? '',
      );
      final sharing = expires != null && expires.isAfter(now);
      final application = _runtime?['application_id']?.toString();
      try {
        await _outbox.cacheActiveJob(owner, application);
      } catch (_) {
        /* Secure-storage failure must not stop safety sync. */
      }
      Map<String, dynamic>? power;
      try {
        power = await _power.invokeMapMethod<String, dynamic>(
          'readSafetyPower',
        );
      } on MissingPluginException {
        /* Unsupported platforms return unknown. */
      }
      final raw = power?['percent'];
      final percent = raw is num && raw >= 0 && raw <= 100 ? raw.toInt() : null;
      double? drain;
      if (percent != null &&
          _samplePercent != null &&
          _sampleAt != null &&
          now.difference(_sampleAt!).inMinutes >= 5 &&
          _samplePercent! > percent) {
        drain =
            (_samplePercent! - percent) /
            now.difference(_sampleAt!).inSeconds *
            60;
      }
      if (_sampleAt == null ||
          now.difference(_sampleAt!) >= const Duration(minutes: 10)) {
        _sampleAt = now;
        _samplePercent = percent;
      }
      final decision = SafetyBatteryDecision.evaluate(
        percent: percent,
        drainPerMinute: drain,
        travelMinutes: (_runtime?['eta_minutes'] as num?)?.toInt() ?? 0,
        jobMinutes:
            (_runtime?['remaining_job_minutes'] as num?)?.toInt() ?? 120,
      );
      final saver =
          safetySaverOverride.value ??
          (decision.enableSaver || power?['systemSaver'] == true);
      final policy = SafetyLocationPolicy.forState(
        sharingActive: sharing,
        travelActive: _runtime?['travel_state'] == 'traveling',
        criticalBattery: decision.criticalSnapshot || saver,
        stationary:
            _lastPosition != null &&
            _lastPosition!.speed >= 0 &&
            _lastPosition!.speed < .5 &&
            now.difference(_lastPosition!.timestamp) <
                const Duration(minutes: 5),
      );
      Position? position;
      if (policy.pollEvery != null &&
          (_lastPositionAt == null ||
              now.difference(_lastPositionAt!) >= policy.pollEvery! ||
              (decision.criticalSnapshot && !_criticalSnapshotAttempted))) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: LocationSettings(
                accuracy: policy.highAccuracy
                    ? LocationAccuracy.high
                    : LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 8),
              ),
            );
            _lastPositionAt = now;
            _lastPosition = position;
          } catch (_) {
            /* A missing location never blocks a safety snapshot. */
          }
        }
      }
      if (decision.criticalSnapshot &&
          position == null &&
          _lastPosition != null &&
          now.difference(_lastPosition!.timestamp) <
              const Duration(minutes: 2) &&
          policy.pollEvery != null)
        position = _lastPosition;
      if (_currentUser() != owner || !_visible) return;
      await repository
          .recordDeviceSnapshot(
            applicationId: application,
            batteryPercent: percent,
            saverEnabled: saver,
            latitude: position?.latitude,
            longitude: position?.longitude,
            locationAt: position?.timestamp,
            expectedActorId: owner,
          )
          .timeout(const Duration(seconds: 8));
      _criticalSnapshotAttempted = decision.criticalSnapshot;
      if (application != null &&
          _runtime?['travel_state'] == 'traveling' &&
          position != null) {
        // ETA failure must never invalidate a confirmed heartbeat or snapshot.
        try {
          await repository
              .refreshTravelEta(application)
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          /* Scoped status keeps ETA unavailable or expires it. */
        }
      }
      if (_currentUser() == owner)
        safetyDeviceStatus.value = SafetyDeviceStatus(
          percent: percent,
          saver: saver,
          label: decision.label,
          lastSync: DateTime.now(),
        );
    } catch (_) {
      if (_currentUser() == owner) {
        final old = safetyDeviceStatus.value;
        safetyDeviceStatus.value = SafetyDeviceStatus(
          percent: old.percent,
          saver: old.saver,
          label: old.label,
          lastSync: old.lastSync,
          connected: false,
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
