/// Runs asynchronous work once at a time and preserves requests that arrive
/// while the current run is in progress by scheduling one trailing run.
class CoalescedAsyncTask {
  Future<void>? _running;
  bool _rerunRequested = false;

  Future<void> run(Future<void> Function() action) {
    final current = _running;
    if (current != null) {
      _rerunRequested = true;
      return current;
    }

    final running = _run(action);
    _running = running;
    return running;
  }

  Future<void> waitForIdle() => _running ?? Future<void>.value();

  Future<void> _run(Future<void> Function() action) async {
    try {
      while (true) {
        _rerunRequested = false;
        Object? error;
        StackTrace? stackTrace;
        try {
          await Future<void>.sync(action);
        } catch (caught, trace) {
          error = caught;
          stackTrace = trace;
        }

        if (_rerunRequested) continue;
        if (error != null) Error.throwWithStackTrace(error, stackTrace!);
        return;
      }
    } finally {
      _running = null;
      _rerunRequested = false;
    }
  }
}
