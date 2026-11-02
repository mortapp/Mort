import 'package:flutter_timezone/flutter_timezone.dart';

import 'remote_push_provider.dart';

/// Remote device push is deliberately dormant. Supabase-backed in-app
/// notifications remain available in the notification center.
class PushNotificationCoordinator {
  PushNotificationCoordinator._();

  static final instance = PushNotificationCoordinator._();

  bool get configured => false;
  Stream<RemotePushMessage> get foregroundMessages => const Stream.empty();
  Stream<RemotePushMessage> get openedMessages => const Stream.empty();

  Future<void> initialize() async {}

  Future<RemotePushPermission> permissionStatus() async =>
      RemotePushPermission.unavailable;

  Future<RemotePushPermission> requestPermissionAndRegister() async =>
      RemotePushPermission.unavailable;

  Future<void> syncRegistration({bool force = false}) async {}

  Future<void> disableAllRemoteNotifications() async {}

  Future<void> prepareForSignOut({required bool allDevices}) async {}

  Future<String> localTimezoneName() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      return timezone.identifier.trim().isEmpty ? 'UTC' : timezone.identifier;
    } catch (_) {
      return 'UTC';
    }
  }
}
