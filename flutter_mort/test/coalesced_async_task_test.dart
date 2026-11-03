import 'dart:async';

import 'package:flutter_mort/services/push/coalesced_async_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a request during active work schedules one trailing run', () async {
    final task = CoalescedAsyncTask();
    final firstRun = Completer<void>();
    final secondRun = Completer<void>();
    var calls = 0;

    Future<void> work() {
      calls++;
      return calls == 1 ? firstRun.future : secondRun.future;
    }

    final originalRequest = task.run(work);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);

    final overlappingRequest = task.run(work);
    expect(calls, 1);

    firstRun.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 2);

    secondRun.complete();
    await Future.wait<void>([originalRequest, overlappingRequest]);
    expect(calls, 2);
  });

  test(
    'waitForIdle includes a trailing request queued before completion',
    () async {
      final task = CoalescedAsyncTask();
      final firstRun = Completer<void>();
      final secondRun = Completer<void>();
      var calls = 0;
      var idleCompleted = false;

      Future<void> work() {
        calls++;
        return calls == 1 ? firstRun.future : secondRun.future;
      }

      final originalRequest = task.run(work);
      final idle = task.waitForIdle();
      final overlappingRequest = task.run(work);
      unawaited(idle.then((_) => idleCompleted = true));

      firstRun.complete();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(idleCompleted, isFalse);

      secondRun.complete();
      await Future.wait<void>([originalRequest, overlappingRequest, idle]);
      expect(idleCompleted, isTrue);
    },
  );
}
