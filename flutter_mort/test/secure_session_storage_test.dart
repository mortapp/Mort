import 'dart:convert';

import 'package:flutter_mort/data/services/secure_session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements MortSessionValueStore {
  _MemoryStore([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;
  bool corruptWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = corruptWrites ? '$value-corrupt' : value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

String _session({String userId = 'user-1'}) => jsonEncode({
  'access_token': 'access-token',
  'refresh_token': 'refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': 1900000000,
  'user': {'id': userId, 'email': 'qa@example.test'},
  'provider_token': null,
  'provider_refresh_token': null,
});

void main() {
  group('MortSecureSessionStorage', () {
    test('uses the stable project-scoped key', () {
      expect(mortSecureSessionKey, 'mort.jxbnrkasktbhtiujkhay.auth.session.v1');
      expect(mortSupabaseProjectRef, 'jxbnrkasktbhtiujkhay');
    });

    test(
      'does not restore a legacy session into the production project',
      () async {
        final session = _session();
        final secure = _MemoryStore({mortLegacySecureSessionKey: session});
        final preferences = _MemoryStore({'old.supabase.session': session});
        final storage = MortSecureSessionStorage(
          secureStore: secure,
          legacyPreferences: preferences,
        );

        await storage.initialize();

        expect(await storage.hasAccessToken(), isFalse);
        expect(secure.values.containsKey(mortSecureSessionKey), isFalse);
        expect(secure.values[mortLegacySecureSessionKey], session);
        expect(preferences.values['old.supabase.session'], session);
      },
    );

    test('logout clears current and all known legacy session keys', () async {
      final session = _session();
      final secure = _MemoryStore({
        mortSecureSessionKey: session,
        mortLegacySecureSessionKey: session,
      });
      final preferences = _MemoryStore({
        for (final key in MortSecureSessionStorage.legacyPreferenceKeys)
          key: session,
      });
      final storage = MortSecureSessionStorage(
        secureStore: secure,
        legacyPreferences: preferences,
      );

      await storage.removePersistedSession();

      expect(await storage.hasAccessToken(), isFalse);
      expect(secure.values, isEmpty);
      expect(preferences.values, isEmpty);
    });
  });
}
