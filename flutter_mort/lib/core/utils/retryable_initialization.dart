import 'dart:async';

/// One successful initialization, with coalesced concurrent callers and a
/// fresh attempt after failure. Completion is never recorded on error.
class RetryableInitialization {
  bool _done = false;
  Future<void>? _pending;

  Future<void> run(Future<void> Function() initialize) {
    if (_done) return Future<void>.value();
    return _pending ??= Future<void>.sync(initialize)
        .then((_) {
          _done = true;
        })
        .whenComplete(() {
          _pending = null;
        });
  }
}
