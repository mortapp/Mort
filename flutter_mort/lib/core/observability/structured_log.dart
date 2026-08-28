import 'dart:async';
import 'dart:collection';

import 'crash_reporting.dart';

enum MortLogLevel { debug, info, warning, error, critical }

class MortStructuredLog {
  MortStructuredLog._();

  static final MortStructuredLog instance = MortStructuredLog._();
  static const _maximumRecords = 100;
  static const _allowedAttributeKeys = {
    'code',
    'feature',
    'network_status',
    'operation',
    'outcome',
    'platform',
    'provider',
    'release_stage',
    'status',
  };

  final Queue<SafeBreadcrumb> _records = Queue<SafeBreadcrumb>();

  List<SafeBreadcrumb> get recent => List.unmodifiable(_records);

  void record(
    String event, {
    MortLogLevel level = MortLogLevel.info,
    Map<String, Object?> attributes = const {},
  }) {
    final breadcrumb = SafeBreadcrumb(
      event: _safeEvent(event),
      level: level.name,
      occurredAt: DateTime.now(),
      attributes: _safeAttributes(attributes),
    );
    _records.addLast(breadcrumb);
    while (_records.length > _maximumRecords) {
      _records.removeFirst();
    }
    unawaited(MortCrashReporting.instance.addBreadcrumb(breadcrumb));
  }

  void clear() => _records.clear();

  String _safeEvent(String event) {
    final normalized = event.toLowerCase().trim();
    return RegExp(r'^[a-z][a-z0-9_.-]{2,79}$').hasMatch(normalized)
        ? normalized
        : 'observability.invalid_event';
  }

  Map<String, String> _safeAttributes(Map<String, Object?> attributes) {
    final result = <String, String>{};
    for (final entry in attributes.entries) {
      if (!_allowedAttributeKeys.contains(entry.key)) continue;
      final value = entry.value?.toString().toLowerCase().trim() ?? 'unknown';
      result[entry.key] = RegExp(r'^[a-z0-9][a-z0-9_.-]{0,63}$').hasMatch(value)
          ? value
          : 'redacted';
    }
    return Map.unmodifiable(result);
  }
}
