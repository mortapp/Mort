import 'dart:async';

import 'package:flutter_timezone/flutter_timezone.dart';

import 'remote_push_provider.dart';

class PushNotificationCoordinator {
  PushNotificationCoordinator._({RemotePushProvider? provider})
    : _provider = provider ?? createRemotePushProvider();

  static final instance = PushNotificationCoordinator._();

  final RemotePushProvider _provider;
  final _foregroundController = StreamController<RemotePushMessage>.broadcast();
  final _openedController = StreamController<RemotePushMessage>.broadcast();
  bool _initialized = false;

  bool get configured => _provider.configured;
  Stream<RemotePushMessage> get foregroundMessages =>
      _foregroundController.stream;
  Stream<RemotePushMessage> get openedMessages => _openedController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!_provider.configured) return;
    await _provider.initialize();
    _provider.foregroundMessages.listen(_foregroundController.add);
    _provider.openedMessages.listen(_openedController.add);
    final initial = await _provider.initialMessage();
    if (initial != null) _openedController.add(initial);
  }

  Future<RemotePushPermission> permissionStatus() async {
    if (!_provider.configured) return RemotePushPermission.unavailable;
    await initialize();
    return _provider.permissionStatus();
  }

  Future<RemotePushPermission> requestPermission() async {
    if (!_provider.configured) return RemotePushPermission.unavailable;
    await initialize();
    return _provider.requestPermission();
  }

  Future<String> localTimezoneName() => _timezoneName();

  Future<String> _timezoneName() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      return timezone.identifier.trim().isEmpty ? 'UTC' : timezone.identifier;
    } catch (_) {
      return 'UTC';
    }
  }
}
