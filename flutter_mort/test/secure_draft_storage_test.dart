import 'dart:convert';

import 'package:flutter_mort/data/services/secure_draft_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryDraftStore implements MortDraftValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  group('MortSecureDraftStorage', () {
    test('keeps profile drafts isolated by authenticated owner', () async {
      final store = _MemoryDraftStore();
      final storage = MortSecureDraftStorage(store: store);

      await storage.writeProfileDraft('user-a', {
        'display_name': 'Alex',
        'role': 'teen',
      });

      expect(await storage.readProfileDraft('user-a'), {
        'display_name': 'Alex',
        'role': 'teen',
      });
      expect(await storage.readProfileDraft('user-b'), isNull);
      expect(store.values.keys, contains('mort.profile.draft.v1.user-a'));
    });

    test('rejects and removes an owner-mismatched envelope', () async {
      final store = _MemoryDraftStore();
      store.values['mort.job.draft.v1.user-a'] = jsonEncode({
        'schema_version': 1,
        'owner_id': 'user-b',
        'kind': 'job',
        'payload': {'title': 'Wrong owner'},
      });
      final storage = MortSecureDraftStorage(store: store);

      expect(await storage.readJobDraft('user-a'), isNull);
      expect(store.values, isEmpty);
    });

    test('rejects malformed local data and clears it', () async {
      final store = _MemoryDraftStore();
      store.values['mort.profile.draft.v1.user-a'] = '{not-json';
      final storage = MortSecureDraftStorage(store: store);

      expect(await storage.readProfileDraft('user-a'), isNull);
      expect(store.values, isEmpty);
    });

    test('round-trips a process recovery job payload', () async {
      final store = _MemoryDraftStore();
      final firstProcess = MortSecureDraftStorage(store: store);
      await firstProcess.writeJobDraft('user-a', {
        'client_request_id': '00000000-0000-0000-0000-000000000001',
        'active_step': 3,
        'title': 'Safe yard cleanup',
      });

      final restartedProcess = MortSecureDraftStorage(store: store);
      final recovered = await restartedProcess.readJobDraft('user-a');

      expect(recovered?['active_step'], 3);
      expect(recovered?['title'], 'Safe yard cleanup');
    });

    test('refuses oversized encrypted draft payloads', () async {
      final storage = MortSecureDraftStorage(store: _MemoryDraftStore());

      await expectLater(
        storage.writeJobDraft('user-a', {'text': 'x' * (70 * 1024)}),
        throwsStateError,
      );
    });
  });
}
