import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/secure_draft_storage.dart';
import '../../data/services/secure_device_storage.dart';

class SafetyDispatchFailure extends StateError {
  SafetyDispatchFailure(super.message);
}

class QueuedSafetyAction {
  const QueuedSafetyAction({
    required this.userId,
    required this.requestId,
    required this.action,
    required this.requestedAt,
    this.applicationId,
  });
  final String userId;
  final String requestId;
  final String action;
  final DateTime requestedAt;
  final String? applicationId;
  Map<String, dynamic> toMap() => {
    'owner': userId,
    'request': requestId,
    'action': action,
    'requested_at': requestedAt.toUtc().toIso8601String(),
    'application': applicationId,
  };
}

/// Account-scoped secure device storage; no coordinates or private evidence.
/// Entries are removed only after the dispatch Future confirms backend success.
class SafetyOutbox {
  SafetyOutbox({MortDraftValueStore? store})
    : _store = store ?? FlutterSecureDraftValueStore(mortSecureDeviceStorage);
  final MortDraftValueStore _store;
  Future<void> _tail = Future.value();
  String _key(String userId) => 'mort.safety.outbox.v1.$userId';
  Future<void> cacheActiveJob(String userId, String? applicationId) async {
    final key = '${_key(userId)}.context';
    if (applicationId == null) {
      await _store.delete(key);
      return;
    }
    await _store.write(
      key,
      jsonEncode({'owner': userId, 'application': applicationId}),
    );
  }

  Future<String?> cachedActiveJob(String userId) async {
    final encoded = await _store.read('${_key(userId)}.context');
    if (encoded == null) return null;
    final value = jsonDecode(encoded);
    if (value is! Map ||
        value['owner'] != userId ||
        value['application'] is! String)
      return null;
    return value['application'] as String;
  }

  Future<List<QueuedSafetyAction>> read(String userId) async {
    final encoded = await _store.read(_key(userId));
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List || decoded.length > 20)
      throw StateError('Safety queue could not be read.');
    return decoded.map((row) {
      if (row is! Map ||
          row['owner'] != userId ||
          row['request'] is! String ||
          row['action'] is! String ||
          !const ['alert', 'exit'].contains(row['action']) ||
          DateTime.tryParse(row['requested_at']?.toString() ?? '') == null) {
        throw StateError('Safety queue owner or data is invalid.');
      }
      return QueuedSafetyAction(
        userId: userId,
        requestId: row['request'] as String,
        action: row['action'] as String,
        requestedAt: DateTime.parse(row['requested_at'] as String),
        applicationId: row['application'] as String?,
      );
    }).toList();
  }

  Future<void> _modify(
    String userId,
    void Function(List<QueuedSafetyAction>) change,
  ) {
    final operation = _tail.then((_) async {
      final entries = await read(userId);
      change(entries);
      if (entries.isEmpty) {
        await _store.delete(_key(userId));
      } else {
        await _store.write(
          _key(userId),
          jsonEncode(entries.map((e) => e.toMap()).toList()),
        );
      }
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> enqueue({
    required String userId,
    required String requestId,
    required String action,
    String? applicationId,
    DateTime? requestedAt,
  }) => _modify(userId, (entries) {
    if (!const ['alert', 'exit'].contains(action))
      throw StateError('Only critical safety events can be queued.');
    final matching = entries.where((entry) => entry.requestId == requestId);
    if (matching.isNotEmpty) {
      if (matching.first.action != action ||
          matching.first.applicationId != applicationId) {
        throw StateError('Safety request changed during retry.');
      }
      return;
    }
    if (entries.length >= 20)
      throw StateError('Safety queue is full. Use calling options.');
    entries.add(
      QueuedSafetyAction(
        userId: userId,
        requestId: requestId,
        action: action,
        requestedAt: requestedAt ?? DateTime.now().toUtc(),
        applicationId: applicationId,
      ),
    );
  });
  Future<void> acknowledge(String userId, String requestId) => _modify(
    userId,
    (entries) => entries.removeWhere((entry) => entry.requestId == requestId),
  );

  /// Local storage availability must not prevent an online emergency send.
  /// Cleanup failure preserves the same request for an idempotent later retry.
  Future<T> dispatchCritical<T>({
    required String userId,
    required String requestId,
    required String action,
    required DateTime requestedAt,
    String? applicationId,
    required Future<T> Function() dispatch,
  }) async {
    var persisted = false;
    try {
      await enqueue(
        userId: userId,
        requestId: requestId,
        action: action,
        applicationId: applicationId,
        requestedAt: requestedAt,
      );
      persisted = true;
    } catch (_) {
      // Continue with the explicitly requested server mutation.
    }
    T result;
    try {
      result = await dispatch();
    } catch (_) {
      throw SafetyDispatchFailure(
        persisted
            ? 'Not confirmed. Saved on this device for retry after reconnecting. Use calling options now.'
            : 'Not confirmed and could not be saved on this device. Use calling options now and retry.',
      );
    }
    try {
      await acknowledge(userId, requestId);
    } catch (_) {
      // Server success remains confirmed; a retained entry replays its ID.
    }
    return result;
  }

  Future<void> flush({
    required String userId,
    required String? Function() currentUserId,
    required Future<void> Function(QueuedSafetyAction) dispatch,
  }) async {
    for (final entry in await read(userId)) {
      if (currentUserId() != userId) return;
      try {
        await dispatch(entry);
      } catch (_) {
        return;
      }
      await acknowledge(userId, entry.requestId);
    }
  }
}

final safetyOutboxProvider = Provider<SafetyOutbox>((ref) => SafetyOutbox());
