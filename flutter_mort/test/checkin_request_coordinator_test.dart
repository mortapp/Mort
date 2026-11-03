import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/services/checkin_request_coordinator.dart';

class _MemoryCheckinRetryStorage implements CheckinRetryStorage {
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

void main() {
  group('CheckinRequestCoordinator', () {
    test(
      'reuses the persisted request after timeout and process restart',
      () async {
        final storage = _MemoryCheckinRetryStorage();
        var generatedIds = 0;
        final firstProcess = CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-${++generatedIds}',
        );
        final firstAttemptIds = <String>[];

        await expectLater(
          firstProcess.execute(
            userId: 'teen-1',
            operation: CheckinOperation.schedule,
            entityId: 'application-1',
            payload: const {'minutes_from_now': 60},
            request: (id) async {
              firstAttemptIds.add(id);
              throw TimeoutException('response timed out');
            },
          ),
          throwsA(isA<TimeoutException>()),
        );

        final restartedProcess = CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-${++generatedIds}',
        );
        final retryIds = <String>[];
        final result = await restartedProcess.execute(
          userId: 'teen-1',
          operation: CheckinOperation.schedule,
          entityId: 'application-1',
          payload: const {'minutes_from_now': 60},
          request: (id) async {
            retryIds.add(id);
            return {'ok': true, 'replayed': true, 'checkin_id': 'checkin-1'};
          },
        );

        expect(retryIds.single, firstAttemptIds.single);
        expect(result['replayed'], isTrue);
        expect(storage.values, isEmpty);
      },
    );

    test(
      'does not reuse a pending request ID with a changed payload',
      () async {
        final storage = _MemoryCheckinRetryStorage();
        final coordinator = CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-1',
        );

        await expectLater(
          coordinator.execute(
            userId: 'teen-1',
            operation: CheckinOperation.schedule,
            entityId: 'application-1',
            payload: const {'minutes_from_now': 30},
            request: (_) => throw TimeoutException('response timed out'),
          ),
          throwsA(isA<TimeoutException>()),
        );

        var requestSent = false;
        await expectLater(
          coordinator.execute(
            userId: 'teen-1',
            operation: CheckinOperation.schedule,
            entityId: 'application-1',
            payload: const {'minutes_from_now': 60},
            request: (_) async {
              requestSent = true;
              return {'ok': true};
            },
          ),
          throwsA(isA<CheckinRequestPayloadMismatch>()),
        );

        expect(requestSent, isFalse);
        expect(storage.values, hasLength(1));
      },
    );

    test(
      'clears a definitive terminal denial so a new action gets a new ID',
      () async {
        final storage = _MemoryCheckinRetryStorage();
        var sequence = 0;
        final coordinator = CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-${++sequence}',
        );
        final attemptedIds = <String>[];

        await expectLater(
          coordinator.execute(
            userId: 'teen-1',
            operation: CheckinOperation.schedule,
            entityId: 'application-1',
            payload: const {'minutes_from_now': 60},
            request: (id) async {
              attemptedIds.add(id);
              return {'ok': false, 'code': 'active_assignment_required'};
            },
          ),
          throwsA(isA<CheckinRequestRejected>()),
        );
        expect(storage.values, isEmpty);

        await coordinator.execute(
          userId: 'teen-1',
          operation: CheckinOperation.schedule,
          entityId: 'application-1',
          payload: const {'minutes_from_now': 60},
          request: (id) async {
            attemptedIds.add(id);
            return {'ok': true, 'replayed': false};
          },
        );

        expect(attemptedIds, ['request-1', 'request-2']);
      },
    );

    test('keeps request IDs isolated by user and operation', () async {
      final storage = _MemoryCheckinRetryStorage();
      var sequence = 0;
      final coordinator = CheckinRequestCoordinator(
        storage: storage,
        newRequestId: () => 'request-${++sequence}',
      );
      final seen = <String>[];

      for (final userId in ['teen-1', 'teen-2']) {
        await coordinator
            .execute(
              userId: userId,
              operation: CheckinOperation.complete,
              entityId: 'checkin-1',
              payload: const {},
              request: (id) async {
                seen.add(id);
                throw TimeoutException('keep intent pending');
              },
            )
            .catchError((_) => <String, dynamic>{});
      }

      expect(seen.toSet(), hasLength(2));
    });

    test(
      'successful completion clears state so a later action gets a new ID',
      () async {
        final storage = _MemoryCheckinRetryStorage();
        var sequence = 0;
        final coordinator = CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-${++sequence}',
        );
        final ids = <String>[];

        for (var action = 0; action < 2; action++) {
          await coordinator.execute(
            userId: 'teen-1',
            operation: CheckinOperation.complete,
            entityId: 'checkin-1',
            payload: const {},
            request: (id) async {
              ids.add(id);
              return {'ok': true, 'replayed': false};
            },
          );
        }

        expect(ids, ['request-1', 'request-2']);
        expect(storage.values, isEmpty);
      },
    );
  });
}
