import 'package:flutter/foundation.dart';

class SafetyDeviceStatus {
  const SafetyDeviceStatus({
    this.percent,
    this.saver = false,
    this.label = 'Battery unavailable',
    this.lastSync,
    this.connected = true,
  });
  final int? percent;
  final bool saver;
  final String label;
  final DateTime? lastSync;
  final bool connected;
}

final safetyDeviceStatus = ValueNotifier(const SafetyDeviceStatus());
final safetyMonitorRefresh = ValueNotifier(0);

/// null follows the automatic policy; a teen may change MORT effects only.
/// This does not change Android/iOS system power settings.
final safetySaverOverride = ValueNotifier<bool?>(null);
