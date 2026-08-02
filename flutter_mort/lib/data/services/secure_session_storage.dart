import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_device_storage.dart';

const mortSupabaseProjectRef = 'rakjydmgwwgtdislanbt';
const mortSecureSessionKey = 'mort.rakjydmgwwgtdislanbt.auth.session.v1';
const mortLegacySecureSessionKey = 'mort.supabase.session';
const mortLegacySupabaseSessionKey = 'sb-rakjydmgwwgtdislanbt-auth-token';

abstract interface class MortSessionValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureSessionValueStore implements MortSessionValueStore {
  FlutterSecureSessionValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SharedPreferencesSessionValueStore implements MortSessionValueStore {
  SharedPreferencesSessionValueStore(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesSessionValueStore> create() async {
    return SharedPreferencesSessionValueStore(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _preferences.remove(key);
  }
}

class MortSecureSessionStorage extends LocalStorage {
  MortSecureSessionStorage({
    FlutterSecureStorage? storage,
    MortSessionValueStore? secureStore,
    MortSessionValueStore? legacyPreferences,
  }) : _secureStore =
           secureStore ??
           FlutterSecureSessionValueStore(storage ?? mortSecureDeviceStorage),
       _legacyPreferences = legacyPreferences;

  static const legacyPreferenceKeys = <String>[
    mortLegacySupabaseSessionKey,
    mortLegacySecureSessionKey,
    supabasePersistSessionKey,
  ];

  final MortSessionValueStore _secureStore;
  MortSessionValueStore? _legacyPreferences;
  Future<void>? _initialization;
  String? _cachedSession;

  static bool isStructurallyValidSession(String? value) {
    if (value == null || value.isEmpty) return false;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return false;
      final user = decoded['user'];
      final expiresAt = decoded['expires_at'];
      return decoded['access_token'] is String &&
          (decoded['access_token'] as String).isNotEmpty &&
          decoded['refresh_token'] is String &&
          (decoded['refresh_token'] as String).isNotEmpty &&
          decoded['token_type'] is String &&
          (decoded['token_type'] as String).isNotEmpty &&
          expiresAt is num &&
          expiresAt > 0 &&
          user is Map &&
          user['id'] is String &&
          (user['id'] as String).isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<void> initialize() => _initialization ??= _loadAndMigrate();

  Future<void> _loadAndMigrate() async {
    final current = await _secureStore.read(mortSecureSessionKey);
    if (isStructurallyValidSession(current)) {
      _cachedSession = current;
      return;
    }

    final legacySecure = await _secureStore.read(mortLegacySecureSessionKey);
    if (await _migrateCandidate(
      legacySecure,
      sourceStore: _secureStore,
      sourceKey: mortLegacySecureSessionKey,
    )) {
      return;
    }

    final preferences = _legacyPreferences ??=
        await SharedPreferencesSessionValueStore.create();
    for (final key in legacyPreferenceKeys) {
      final candidate = await preferences.read(key);
      if (await _migrateCandidate(
        candidate,
        sourceStore: preferences,
        sourceKey: key,
      )) {
        return;
      }
    }
  }

  Future<bool> _migrateCandidate(
    String? candidate, {
    required MortSessionValueStore sourceStore,
    required String sourceKey,
  }) async {
    if (!isStructurallyValidSession(candidate)) return false;
    await _secureStore.write(mortSecureSessionKey, candidate!);
    final verified = await _secureStore.read(mortSecureSessionKey);
    if (verified != candidate || !isStructurallyValidSession(verified)) {
      return false;
    }
    await sourceStore.delete(sourceKey);
    _cachedSession = verified;
    return true;
  }

  @override
  Future<String?> accessToken() async {
    await initialize();
    return _cachedSession;
  }

  @override
  Future<bool> hasAccessToken() async {
    await initialize();
    return isStructurallyValidSession(_cachedSession);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await initialize();
    if (!isStructurallyValidSession(persistSessionString)) {
      throw const FormatException('Invalid Supabase session structure.');
    }
    await _secureStore.write(mortSecureSessionKey, persistSessionString);
    final verified = await _secureStore.read(mortSecureSessionKey);
    if (verified != persistSessionString) {
      throw StateError('Secure session write verification failed.');
    }
    _cachedSession = verified;
  }

  @override
  Future<void> removePersistedSession() async {
    await initialize();
    await _secureStore.delete(mortSecureSessionKey);
    await _secureStore.delete(mortLegacySecureSessionKey);
    final preferences = _legacyPreferences ??=
        await SharedPreferencesSessionValueStore.create();
    for (final key in legacyPreferenceKeys) {
      await preferences.delete(key);
    }
    _cachedSession = null;
  }
}
