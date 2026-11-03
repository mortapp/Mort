enum RemotePushPermission {
  unavailable,
  notDetermined,
  denied,
  authorized,
  provisional,
}

class RemotePushMessage {
  const RemotePushMessage({required this.data});

  final Map<String, dynamic> data;
}

abstract interface class RemotePushProvider {
  bool get configured;
  Stream<String> get tokenRefreshes;
  Stream<RemotePushMessage> get foregroundMessages;
  Stream<RemotePushMessage> get openedMessages;

  Future<void> initialize();
  Future<RemotePushPermission> permissionStatus();
  Future<RemotePushPermission> requestPermission();
  Future<String?> registrationToken();
  Future<RemotePushMessage?> initialMessage();
  Future<void> deleteToken();
}

class DisabledRemotePushProvider implements RemotePushProvider {
  const DisabledRemotePushProvider();

  @override
  bool get configured => false;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<RemotePushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<RemotePushMessage> get openedMessages => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<RemotePushPermission> permissionStatus() async =>
      RemotePushPermission.unavailable;

  @override
  Future<RemotePushPermission> requestPermission() async =>
      RemotePushPermission.unavailable;

  @override
  Future<String?> registrationToken() async => null;

  @override
  Future<RemotePushMessage?> initialMessage() async => null;

  @override
  Future<void> deleteToken() async {}
}

// No remote delivery provider is approved for this app.
RemotePushProvider createRemotePushProvider() =>
    const DisabledRemotePushProvider();
