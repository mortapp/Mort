/// Prevents queued provider callbacks from registering while a signed-in
/// account's notification registration is being revoked.
class PushRegistrationGate {
  Future<void>? _active;
  Future<void>? _revocation;
  final _blockedOwners = <String>{};

  bool allows(String owner) =>
      !_blockedOwners.contains(owner) && _revocation == null;

  Future<void> sync(
    String owner,
    Future<void> Function() register, {
    bool runAfterActive = false,
  }) {
    if (!allows(owner)) return Future<void>.value();
    final active = _active;
    if (runAfterActive && active != null) {
      return _after(active, () => sync(owner, register));
    }
    return _active ??= Future<void>.microtask(() async {
      if (allows(owner)) await register();
    }).whenComplete(() => _active = null);
  }

  Future<void> revoke(String owner, Future<void> Function() unregister) {
    // Set the block before awaiting either the in-flight write or revocation.
    _blockedOwners.add(owner);
    final previous = _revocation;
    final future = _after(previous ?? _active, unregister);
    _revocation = future;
    return future.whenComplete(() {
      if (identical(_revocation, future)) _revocation = null;
    });
  }

  Future<void> _after(
    Future<void>? waitFor,
    Future<void> Function() unregister,
  ) async {
    try {
      await waitFor;
    } catch (_) {
      // A registration error must not prevent attempting revocation.
    }
    await unregister();
  }

  void explicitOptIn(String owner) {
    if (_revocation == null) _blockedOwners.remove(owner);
  }
}
