import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/services/secure_draft_storage.dart';
import 'package:flutter_mort/features/safety/safety_outbox.dart';

class _MemoryStore implements MortDraftValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _UnavailableStore implements MortDraftValueStore {
  @override
  Future<String?> read(String key) async =>
      throw StateError('storage unavailable');
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('storage unavailable');
  @override
  Future<void> delete(String key) async =>
      throw StateError('storage unavailable');
}

void main() {
  test(
    'Unavailable local storage does not block an online confirmed alert',
    () async {
      var sent = false;
      final result = await SafetyOutbox(store: _UnavailableStore())
          .dispatchCritical(
            userId: 'teen-a',
            requestId: 'request-1',
            action: 'alert',
            requestedAt: DateTime.utc(2026),
            dispatch: () async {
              sent = true;
              return 'confirmed';
            },
          );
      expect(sent, true);
      expect(result, 'confirmed');
    },
  );
  test(
    'Storage and network failure explicitly says the alert was not saved',
    () async {
      await expectLater(
        SafetyOutbox(store: _UnavailableStore()).dispatchCritical(
          userId: 'teen-a',
          requestId: 'request-1',
          action: 'alert',
          requestedAt: DateTime.utc(2026),
          dispatch: () async => throw StateError('offline'),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('could not be saved'),
          ),
        ),
      );
    },
  );
  test(
    'Failed send keeps an encrypted-store entry and stable request for retry',
    () async {
      final outbox = SafetyOutbox(store: _MemoryStore());
      await outbox.enqueue(
        userId: 'teen-a',
        requestId: 'request-1',
        action: 'alert',
      );
      await outbox.flush(
        userId: 'teen-a',
        currentUserId: () => 'teen-a',
        dispatch: (_) async => throw StateError('offline'),
      );
      expect((await outbox.read('teen-a')).single.requestId, 'request-1');
      String? actor;
      await outbox.flush(
        userId: 'teen-a',
        currentUserId: () => 'teen-a',
        dispatch: (entry) async {
          actor = entry.userId;
        },
      );
      expect(actor, 'teen-a');
      expect(await outbox.read('teen-a'), isEmpty);
    },
  );
  test(
    'Account switch prevents dispatch and never moves another teen queue',
    () async {
      final outbox = SafetyOutbox(store: _MemoryStore());
      await outbox.enqueue(
        userId: 'teen-a',
        requestId: 'request-1',
        action: 'exit',
        applicationId: 'job-a',
      );
      var dispatched = false;
      await outbox.flush(
        userId: 'teen-a',
        currentUserId: () => 'teen-b',
        dispatch: (_) async {
          dispatched = true;
        },
      );
      expect(dispatched, false);
      expect(await outbox.read('teen-b'), isEmpty);
      expect(await outbox.read('teen-a'), hasLength(1));
    },
  );
}
