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
      expect(mortSecureSessionKey, 'mort.rakjydmgwwgtdislanbt.auth.session.v1');
      expect(mortSupabaseProjectRef, 'rakjydmgwwgtdislanbt');
    });

    test('migrates the old Supabase preference only after read-back', () async {
      final session = _session();
      final secure = _MemoryStore();
      final preferences = _MemoryStore({mortLegacySupabaseSessionKey: session});
      final storage = MortSecureSessionStorage(
        secureStore: secure,
        legacyPreferences: preferences,
      );

      await storage.initialize();

      expect(await storage.accessToken(), session);
      expect(secure.values[mortSecureSessionKey], session);
      expect(
        preferences.values.containsKey(mortLegacySupabaseSessionKey),
        isFalse,
      );
    });

    test(
      'migrates the prior secure key without exposing the session',
      () async {
        final session = _session();
        final secure = _MemoryStore({mortLegacySecureSessionKey: session});
        final storage = MortSecureSessionStorage(
          secureStore: secure,
          legacyPreferences: _MemoryStore(),
        );

        await storage.initialize();

        expect(await storage.hasAccessToken(), isTrue);
        expect(secure.values[mortSecureSessionKey], session);
        expect(secure.values.containsKey(mortLegacySecureSessionKey), isFalse);
      },
    );

    test('does not delete a legacy value when verification fails', () async {
      final session = _session();
      final secure = _MemoryStore()..corruptWrites = true;
      final preferences = _MemoryStore({mortLegacySupabaseSessionKey: session});
      final storage = MortSecureSessionStorage(
        secureStore: secure,
        legacyPreferences: preferences,
      );

      await storage.initialize();

      expect(await storage.hasAccessToken(), isFalse);
      expect(preferences.values[mortLegacySupabaseSessionKey], session);
    });

    test('rejects malformed legacy JSON without deleting it', () async {
      const malformed = '{"access_token":"only-one-field"}';
      final secure = _MemoryStore();
      final preferences = _MemoryStore({
        mortLegacySupabaseSessionKey: malformed,
      });
      final storage = MortSecureSessionStorage(
        secureStore: secure,
        legacyPreferences: preferences,
      );

      await storage.initialize();

      expect(await storage.hasAccessToken(), isFalse);
      expect(preferences.values[mortLegacySupabaseSessionKey], malformed);
      expect(secure.values.containsKey(mortSecureSessionKey), isFalse);
    });

    test('migration is idempotent when the new key already exists', () async {
      final current = _session(userId: 'current');
      final legacy = _session(userId: 'legacy');
      final secure = _MemoryStore({mortSecureSessionKey: current});
      final preferences = _MemoryStore({mortLegacySupabaseSessionKey: legacy});
      final storage = MortSecureSessionStorage(
        secureStore: secure,
        legacyPreferences: preferences,
      );

      await storage.initialize();
      await storage.initialize();

      expect(await storage.accessToken(), current);
      expect(preferences.values[mortLegacySupabaseSessionKey], legacy);
    });

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
