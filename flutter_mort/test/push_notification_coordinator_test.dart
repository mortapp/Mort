import 'dart:async';

import 'package:flutter_mort/services/push/push_notification_coordinator.dart';
import 'package:flutter_mort/services/push/remote_push_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cold-start notification is replayed to the later app listener',
    () async {
      const message = RemotePushMessage(
        data: {'type': 'account_security_alert'},
      );
      final provider = _InitialMessageRemotePushProvider(message);
      final coordinator = PushNotificationCoordinator.forTesting(
        provider: provider,
      );
      final received = Completer<RemotePushMessage>();

      await coordinator.initialize();
      final subscription = coordinator.openedMessages.listen(received.complete);
      addTearDown(subscription.cancel);

      expect(
        await received.future.timeout(const Duration(seconds: 1)),
        message,
      );
    },
  );

  test('failed provider initialization can be retried', () async {
    final provider = _FailingRemotePushProvider();
    final coordinator = PushNotificationCoordinator.forTesting(
      provider: provider,
    );

    await expectLater(coordinator.initialize(), throwsStateError);
    await expectLater(coordinator.initialize(), throwsStateError);

    expect(provider.initializeCalls, 2);
  });
}

class _InitialMessageRemotePushProvider implements RemotePushProvider {
  const _InitialMessageRemotePushProvider(this.message);

  final RemotePushMessage message;

  @override
  bool get configured => true;

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
      RemotePushPermission.notDetermined;

  @override
  Future<RemotePushPermission> requestPermission() async =>
      RemotePushPermission.notDetermined;

  @override
  Future<String?> registrationToken() async => null;

  @override
  Future<RemotePushMessage?> initialMessage() async => message;

  @override
  Future<void> deleteToken() async {}
}

class _FailingRemotePushProvider implements RemotePushProvider {
  var initializeCalls = 0;

  @override
  bool get configured => true;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<RemotePushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<RemotePushMessage> get openedMessages => const Stream.empty();

  @override
  Future<void> initialize() async {
    initializeCalls++;
    throw StateError('provider initialization failed');
  }

  @override
  Future<RemotePushPermission> permissionStatus() async =>
      RemotePushPermission.notDetermined;

  @override
  Future<RemotePushPermission> requestPermission() async =>
      RemotePushPermission.notDetermined;

  @override
  Future<String?> registrationToken() async => null;

  @override
  Future<RemotePushMessage?> initialMessage() async => null;

  @override
  Future<void> deleteToken() async {}
}
