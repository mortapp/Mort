import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'secure_device_storage.dart';

enum CheckinOperation { schedule, complete }

abstract interface class CheckinRetryStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureCheckinRetryStorage implements CheckinRetryStorage {
  FlutterSecureCheckinRetryStorage(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class CheckinRequestPayloadMismatch implements Exception {
  const CheckinRequestPayloadMismatch();

  @override
  String toString() => 'checkin_request_payload_mismatch';
}

class CheckinRequestRejected implements Exception {
  const CheckinRequestRejected(this.code, {this.message});

  final String code;
  final String? message;

  @override
  String toString() => message?.isNotEmpty == true ? message! : code;
}

class CheckinRequestCoordinator {
  CheckinRequestCoordinator({
    CheckinRetryStorage? storage,
    String Function()? newRequestId,
  }) : _storage =
           storage ?? FlutterSecureCheckinRetryStorage(mortSecureDeviceStorage),
       _newRequestId = newRequestId ?? const Uuid().v4;

  static const _schemaVersion = 1;
  static const _maximumRecordBytes = 4096;

  final CheckinRetryStorage _storage;
  final String Function() _newRequestId;
  final Map<String, _InFlightRequest> _inFlight = {};

  Future<Map<String, dynamic>> execute({
    required String userId,
    required CheckinOperation operation,
    required String entityId,
    required Map<String, dynamic> payload,
    String? preferredRequestId,
    required Future<dynamic> Function(String requestId) request,
  }) {
    final key = _key(userId, operation, entityId);
    final canonicalPayload = _canonicalizeMap(payload);
    final encodedPayload = jsonEncode(canonicalPayload);
    final pending = _inFlight[key];
    if (pending != null) {
      if (pending.encodedPayload != encodedPayload) {
        return Future.error(const CheckinRequestPayloadMismatch());
      }
      return pending.future;
    }

    final future = _executeSerialized(
      key: key,
      userId: userId,
      operation: operation,
      entityId: entityId,
      encodedPayload: encodedPayload,
      payload: canonicalPayload,
      preferredRequestId: preferredRequestId,
      request: request,
    );
    _inFlight[key] = _InFlightRequest(encodedPayload, future);
    future.then<void>(
      (_) => _removeInFlight(key, future),
      onError: (Object _, StackTrace _) => _removeInFlight(key, future),
    );
    return future;
  }

  Future<Map<String, dynamic>> _executeSerialized({
    required String key,
    required String userId,
    required CheckinOperation operation,
    required String entityId,
    required String encodedPayload,
    required Map<String, dynamic> payload,
    required String? preferredRequestId,
    required Future<dynamic> Function(String requestId) request,
  }) async {
    final requestId = await _reserveRequestId(
      key: key,
      userId: userId,
      operation: operation,
      entityId: entityId,
      encodedPayload: encodedPayload,
      payload: payload,
      preferredRequestId: preferredRequestId,
    );

    // Exceptions from the transport are ambiguous: the server may have
    // committed before the response was lost. Keep the request ID for retry.
    final raw = await request(requestId);
    if (raw is! Map) {
      throw StateError('checkin_response_invalid');
    }
    final result = Map<String, dynamic>.from(raw);
    if (result['ok'] != true) {
      await _deleteIfCurrent(key, requestId);
      throw CheckinRequestRejected(
        (result['code'] ?? 'checkin_request_rejected').toString(),
        message: result['message']?.toString(),
      );
    }

    // A crash before this delete only causes a safe exact-key replay.
    await _deleteIfCurrent(key, requestId);
    return result;
  }

  Future<String> _reserveRequestId({
    required String key,
    required String userId,
    required CheckinOperation operation,
    required String entityId,
    required String encodedPayload,
    required Map<String, dynamic> payload,
    required String? preferredRequestId,
  }) async {
    final encoded = await _storage.read(key);
    if (encoded != null) {
      final record = _decodeRecord(encoded);
      if (record['user_id'] != userId ||
          record['operation'] != operation.name ||
          record['entity_id'] != entityId ||
          record['payload'] is! Map ||
          record['request_id'] is! String ||
          (record['request_id'] as String).isEmpty) {
        throw StateError('checkin_retry_state_unavailable');
      }
      if (jsonEncode(
            _canonicalizeMap(
              Map<String, dynamic>.from(record['payload'] as Map),
            ),
          ) !=
          encodedPayload) {
        throw const CheckinRequestPayloadMismatch();
      }
      return record['request_id'] as String;
    }

    final requestId = preferredRequestId?.trim().isNotEmpty == true
        ? preferredRequestId!.trim()
        : _newRequestId();
    final value = jsonEncode({
      'schema_version': _schemaVersion,
      'user_id': userId,
      'operation': operation.name,
      'entity_id': entityId,
      'request_id': requestId,
      'payload': payload,
    });
    if (utf8.encode(value).length > _maximumRecordBytes) {
      throw StateError('checkin_retry_state_too_large');
    }
    // Persist before the network call so process death cannot lose the key.
    await _storage.write(key, value);
    return requestId;
  }

  Map<String, dynamic> _decodeRecord(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic> ||
          value['schema_version'] != _schemaVersion) {
        throw StateError('checkin_retry_state_unavailable');
      }
      return value;
    } on FormatException {
      throw StateError('checkin_retry_state_unavailable');
    }
  }

  Future<void> _deleteIfCurrent(String key, String requestId) async {
    final current = await _storage.read(key);
    if (current == null) return;
    final record = _decodeRecord(current);
    if (record['request_id'] == requestId) await _storage.delete(key);
  }

  void _removeInFlight(String key, Future<Map<String, dynamic>> future) {
    if (identical(_inFlight[key]?.future, future)) _inFlight.remove(key);
  }

  static String _key(
    String userId,
    CheckinOperation operation,
    String entityId,
  ) =>
      'mort.checkin.request.v$_schemaVersion.${Uri.encodeComponent(userId)}.'
      '${operation.name}.${Uri.encodeComponent(entityId)}';

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonicalize(value[key])};
    }
    if (value is List) return value.map(_canonicalize).toList();
    return value;
  }

  static Map<String, dynamic> _canonicalizeMap(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(_canonicalize(value) as Map);
}

class _InFlightRequest {
  const _InFlightRequest(this.encodedPayload, this.future);

  final String encodedPayload;
  final Future<Map<String, dynamic>> future;
}
