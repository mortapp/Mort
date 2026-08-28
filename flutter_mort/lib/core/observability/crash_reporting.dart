import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

typedef CrashEventSink =
    Future<void> Function(CrashEnvelope event, StackTrace stackTrace);
typedef CrashBreadcrumbSink = Future<void> Function(SafeBreadcrumb breadcrumb);

@immutable
class CrashEnvelope {
  const CrashEnvelope({
    required this.category,
    required this.context,
    required this.correlationId,
    required this.fatal,
    required this.occurredAt,
  });

  final String category;
  final String context;
  final String correlationId;
  final bool fatal;
  final DateTime occurredAt;

  Map<String, Object> toSafeMap() => {
    'category': category,
    'context': context,
    'correlation_id': correlationId,
    'fatal': fatal,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };
}

@immutable
class SafeBreadcrumb {
  const SafeBreadcrumb({
    required this.event,
    required this.level,
    required this.occurredAt,
    this.attributes = const {},
  });

  final String event;
  final String level;
  final DateTime occurredAt;
  final Map<String, String> attributes;

  Map<String, Object> toSafeMap() => {
    'event': event,
    'level': level,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    if (attributes.isNotEmpty) 'attributes': attributes,
  };
}

class MortCrashReporting {
  MortCrashReporting._();

  static final MortCrashReporting instance = MortCrashReporting._();
  static const _uuid = Uuid();

  CrashEventSink? _sink;
  CrashBreadcrumbSink? _breadcrumbSink;
  String _providerName = 'disabled';

  bool get providerConfigured => _sink != null;
  String get providerName => _providerName;

  void configure({
    CrashEventSink? sink,
    CrashBreadcrumbSink? breadcrumbSink,
    String providerName = 'disabled',
  }) {
    _sink = sink;
    _breadcrumbSink = breadcrumbSink;
    _providerName = sink == null ? 'disabled' : safeProvider(providerName);
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
      correlationId: _uuid.v4(),
      fatal: fatal,
      occurredAt: DateTime.now(),
    );
    try {
      await sink(envelope, stackTrace);
    } catch (_) {
      // Observability must never become a second application failure.
    }
  }

  Future<void> addBreadcrumb(SafeBreadcrumb breadcrumb) async {
    final sink = _breadcrumbSink;
    if (sink == null) return;
    try {
      await sink(breadcrumb);
    } catch (_) {
      // Breadcrumb delivery is best effort and never user-visible.
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
      'repository_operation',
      'background_operation',
    };
    return allowed.contains(context) ? context : 'unspecified';
  }

  @visibleForTesting
  String safeProvider(String provider) {
    final normalized = provider.toLowerCase().trim();
    return const {'disabled', 'sentry'}.contains(normalized)
        ? normalized
        : 'unknown';
  }
}
