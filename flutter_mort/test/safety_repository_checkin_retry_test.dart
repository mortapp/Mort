import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/repositories/safety_repository.dart';
import 'package:flutter_mort/data/services/checkin_request_coordinator.dart';

class _MemoryRetryStorage implements CheckinRetryStorage {
  final values = <String, String>{};
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('secure read unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('secure write unavailable');
    values[key] = value;
  }
}

void main() {
  test(
    'schedule repository retries the same durable RPC request after timeout',
    () async {
      final storage = _MemoryRetryStorage();
      var generated = 0;
      final requestIds = <String>[];
      final calls = <Map<String, dynamic>>[];
      final firstRepository = SafetyRepository(
        authenticatedUserId: () => 'teen-1',
        checkinRequestCoordinator: CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-${++generated}',
        ),
        checkinRpcInvoker: (function, params) async {
          expect(storage.values, hasLength(1));
          calls.add({'function': function, ...params});
          requestIds.add(params['p_client_request_id']!);
          throw TimeoutException('server may have committed before timeout');
        },
      );

      await expectLater(
        firstRepository.scheduleActiveJobCheckin(
          applicationId: 'application-1',
          minutesFromNow: 60,
        ),
        throwsA(isA<TimeoutException>()),
      );

      final restartedRepository = SafetyRepository(
        authenticatedUserId: () => 'teen-1',
        checkinRequestCoordinator: CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-${++generated}',
        ),
        checkinRpcInvoker: (function, params) async {
          calls.add({'function': function, ...params});
          requestIds.add(params['p_client_request_id']!);
          return {
            'ok': true,
            'replayed': true,
            'checkin_id': 'checkin-1',
            'expected_at': '2026-11-02T12:00:00Z',
          };
        },
      );
      final result = await restartedRepository.scheduleActiveJobCheckin(
        applicationId: 'application-1',
        minutesFromNow: 60,
      );

      expect(requestIds, ['request-1', 'request-1']);
      expect(calls.map((call) => call['function']).toSet(), {
        'schedule_active_job_checkin',
      });
      expect(calls[0]['p_application_id'], calls[1]['p_application_id']);
      expect(calls[0]['p_minutes_from_now'], calls[1]['p_minutes_from_now']);
      expect(result['replayed'], isTrue);
      expect(storage.values, isEmpty);
    },
  );

  test(
    'completion authorization denial clears the rejected intent safely',
    () async {
      final storage = _MemoryRetryStorage();
      var generated = 0;
      final requestIds = <String>[];
      var reject = true;

      SafetyRepository createRepository() => SafetyRepository(
        authenticatedUserId: () => 'teen-1',
        checkinRequestCoordinator: CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-${++generated}',
        ),
        checkinRpcInvoker: (_, params) async {
          requestIds.add(params['p_client_request_id']!);
          if (reject) {
            return {'ok': false, 'code': 'checkin_not_authorized'};
          }
          return {'ok': true, 'checkin_id': 'checkin-1'};
        },
      );

      await expectLater(
        createRepository().completeActiveJobCheckin(checkinId: 'checkin-1'),
        throwsA(isA<CheckinRequestRejected>()),
      );
      expect(storage.values, isEmpty);
      reject = false;
      await createRepository().completeActiveJobCheckin(checkinId: 'checkin-1');

      expect(requestIds, ['request-1', 'request-2']);
    },
  );

  test(
    'schedule repository blocks a changed payload from reusing a retry key',
    () async {
      final storage = _MemoryRetryStorage();
      var generated = 0;
      var calls = 0;
      final repository = SafetyRepository(
        authenticatedUserId: () => 'teen-1',
        checkinRequestCoordinator: CheckinRequestCoordinator(
          storage: storage,
          newRequestId: () => 'request-${++generated}',
        ),
        checkinRpcInvoker: (_, _) async {
          calls += 1;
          throw TimeoutException('ambiguous response');
        },
      );

      await expectLater(
        repository.scheduleActiveJobCheckin(
          applicationId: 'application-1',
          minutesFromNow: 30,
        ),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        repository.scheduleActiveJobCheckin(
          applicationId: 'application-1',
          minutesFromNow: 60,
        ),
        throwsA(isA<CheckinRequestPayloadMismatch>()),
      );

      expect(calls, 1);
      expect(storage.values, hasLength(1));
    },
  );

  test('secure-storage read failure prevents an untracked RPC', () async {
    final storage = _MemoryRetryStorage()..failRead = true;
    var calls = 0;
    final repository = SafetyRepository(
      authenticatedUserId: () => 'teen-1',
      checkinRequestCoordinator: CheckinRequestCoordinator(
        storage: storage,
        newRequestId: () => 'request-1',
      ),
      checkinRpcInvoker: (_, _) async {
        calls += 1;
        return {'ok': true};
      },
    );

    await expectLater(
      repository.scheduleActiveJobCheckin(
        applicationId: 'application-1',
        minutesFromNow: 60,
      ),
      throwsStateError,
    );
    expect(calls, 0);
  });

  test('secure-storage write failure prevents an untracked RPC', () async {
    final storage = _MemoryRetryStorage()..failWrite = true;
    var calls = 0;
    final repository = SafetyRepository(
      authenticatedUserId: () => 'teen-1',
      checkinRequestCoordinator: CheckinRequestCoordinator(
        storage: storage,
        newRequestId: () => 'request-1',
      ),
      checkinRpcInvoker: (_, _) async {
        calls += 1;
        return {'ok': true};
      },
    );

    await expectLater(
      repository.completeActiveJobCheckin(checkinId: 'checkin-1'),
      throwsStateError,
    );
    expect(calls, 0);
    expect(storage.values, isEmpty);
  });

  test('concurrent duplicate calls share one in-flight submission', () async {
    final storage = _MemoryRetryStorage();
    final response = Completer<dynamic>();
    var calls = 0;
    final coordinator = CheckinRequestCoordinator(
      storage: storage,
      newRequestId: () => 'request-1',
    );
    // A single repository instance shares the same in-flight coordinator.
    final shared = SafetyRepository(
      authenticatedUserId: () => 'teen-1',
      checkinRequestCoordinator: coordinator,
      checkinRpcInvoker: (_, _) {
        calls += 1;
        return response.future;
      },
    );

    final first = shared.scheduleActiveJobCheckin(
      applicationId: 'application-1',
      minutesFromNow: 60,
    );
    final duplicate = shared.scheduleActiveJobCheckin(
      applicationId: 'application-1',
      minutesFromNow: 60,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    response.complete({'ok': true, 'checkin_id': 'checkin-1'});
    await Future.wait([first, duplicate]);
  });

  test(
    'separate repository instances share one concurrent logical request',
    () async {
      final storage = _MemoryRetryStorage();
      final response = Completer<dynamic>();
      var calls = 0;

      SafetyRepository makeRepository(String generatedRequestId) =>
          SafetyRepository(
            authenticatedUserId: () => 'teen-1',
            checkinRequestCoordinator: CheckinRequestCoordinator(
              storage: storage,
              newRequestId: () => generatedRequestId,
            ),
            checkinRpcInvoker: (_, _) {
              calls += 1;
              return response.future;
            },
          );

      final first = makeRepository('request-first').scheduleActiveJobCheckin(
        applicationId: 'application-1',
        minutesFromNow: 60,
      );
      final second = makeRepository('request-second').scheduleActiveJobCheckin(
        applicationId: 'application-1',
        minutesFromNow: 60,
      );
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      response.complete({'ok': true, 'checkin_id': 'checkin-1'});
      await Future.wait([first, second]);
    },
  );
}
