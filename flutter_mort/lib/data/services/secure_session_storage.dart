import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_device_storage.dart';

class MortSecureSessionStorage extends LocalStorage {
  MortSecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? mortSecureDeviceStorage;

  static const _sessionKey = 'mort.supabase.session';
  final FlutterSecureStorage _storage;
  Future<void>? _initialization;
  String? _cachedSession;

  @override
  Future<void> initialize() => _initialization ??= _loadSession();

  Future<void> _loadSession() async {
    _cachedSession = await _storage.read(key: _sessionKey);
  }

  @override
  Future<String?> accessToken() async {
    await initialize();
    return _cachedSession;
  }

  @override
  Future<bool> hasAccessToken() async {
    await initialize();
    return _cachedSession?.isNotEmpty == true;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await initialize();
    await _storage.write(key: _sessionKey, value: persistSessionString);
    _cachedSession = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    await initialize();
    await _storage.delete(key: _sessionKey);
    _cachedSession = null;
  }
}
