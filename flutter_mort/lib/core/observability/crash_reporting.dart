import 'package:flutter/foundation.dart';

typedef CrashEventSink = Future<void> Function(CrashEnvelope event);

@immutable
class CrashEnvelope {
  const CrashEnvelope({
    required this.category,
    required this.context,
    required this.fatal,
    required this.occurredAt,
  });

  final String category;
  final String context;
  final bool fatal;
  final DateTime occurredAt;

  Map<String, Object> toSafeMap() => {
    'category': category,
    'context': context,
    'fatal': fatal,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };
}

class MortCrashReporting {
  MortCrashReporting._();

  static final MortCrashReporting instance = MortCrashReporting._();

  CrashEventSink? _sink;

  bool get providerConfigured => _sink != null;

  void configure(CrashEventSink? sink) {
    _sink = sink;
  }

  Future<void> record(
    Object error,
    StackTrace stackTrace, {
    required bool fatal,
    required String context,
  }) async {
    final sink = _sink;
    if (sink == null) return;

    final envelope = CrashEnvelope(
      category: safeCategory(error),
      context: safeContext(context),
      fatal: fatal,
      occurredAt: DateTime.now(),
    );
    try {
      await sink(envelope);
    } catch (_) {
      // Crash reporting must never create a second application failure.
    }
  }

  @visibleForTesting
  String safeCategory(Object error) {
    final raw = error.runtimeType.toString().toLowerCase();
    final safe = raw.replaceAll(RegExp('[^a-z0-9_]'), '_');
    if (safe.isEmpty || safe.length > 80) return 'unknown_error';
    return safe;
  }

  @visibleForTesting
  String safeContext(String context) {
    const allowed = {
      'flutter_framework',
      'platform_dispatcher',
      'root_zone',
      'startup',
    };
    return allowed.contains(context) ? context : 'unspecified';
  }
}
