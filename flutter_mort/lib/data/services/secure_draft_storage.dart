import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_device_storage.dart';

abstract interface class MortDraftValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureDraftValueStore implements MortDraftValueStore {
  FlutterSecureDraftValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MortSecureDraftStorage {
  MortSecureDraftStorage({MortDraftValueStore? store})
    : _store = store ?? FlutterSecureDraftValueStore(mortSecureDeviceStorage);

  static const _schemaVersion = 1;
  static const _maximumEncodedBytes = 64 * 1024;

  final MortDraftValueStore _store;

  Future<Map<String, dynamic>?> readProfileDraft(String userId) =>
      _read(kind: 'profile', userId: userId);

  Future<void> writeProfileDraft(String userId, Map<String, dynamic> payload) =>
      _write(kind: 'profile', userId: userId, payload: payload);

  Future<void> clearProfileDraft(String userId) =>
      _store.delete(_key('profile', userId));

  Future<Map<String, dynamic>?> readJobDraft(String userId) =>
      _read(kind: 'job', userId: userId);

  Future<void> writeJobDraft(String userId, Map<String, dynamic> payload) =>
      _write(kind: 'job', userId: userId, payload: payload);

  Future<void> clearJobDraft(String userId) =>
      _store.delete(_key('job', userId));

  Future<Map<String, dynamic>?> _read({
    required String kind,
    required String userId,
  }) async {
    final encoded = await _store.read(_key(kind, userId));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema_version'] != _schemaVersion ||
          decoded['owner_id'] != userId ||
          decoded['kind'] != kind ||
          decoded['payload'] is! Map) {
        await _store.delete(_key(kind, userId));
        return null;
      }
      return Map<String, dynamic>.from(decoded['payload'] as Map);
    } on FormatException {
      await _store.delete(_key(kind, userId));
      return null;
    }
  }

  Future<void> _write({
    required String kind,
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final encoded = jsonEncode({
      'schema_version': _schemaVersion,
      'owner_id': userId,
      'kind': kind,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    });
    if (utf8.encode(encoded).length > _maximumEncodedBytes) {
      throw StateError('The local draft is too large to store safely.');
    }
    await _store.write(_key(kind, userId), encoded);
  }

  static String _key(String kind, String userId) =>
      'mort.$kind.draft.v$_schemaVersion.$userId';
}
