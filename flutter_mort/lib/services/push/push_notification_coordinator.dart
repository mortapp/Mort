import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/services/secure_device_storage.dart';
import '../../data/services/supabase_service.dart';
import 'remote_push_provider.dart';

class PushNotificationCoordinator {
  PushNotificationCoordinator._({RemotePushProvider? provider})
    : _provider = provider ?? createRemotePushProvider();

  static final instance = PushNotificationCoordinator._();
  static const _deviceIdKey = 'mort.push.installation_id';
  static const _uuid = Uuid();

  final RemotePushProvider _provider;
  final _foregroundController = StreamController<RemotePushMessage>.broadcast();
  final _openedController = StreamController<RemotePushMessage>.broadcast();
  bool _initialized = false;
  bool _syncing = false;

  bool get configured => _provider.configured;
  Stream<RemotePushMessage> get foregroundMessages =>
      _foregroundController.stream;
  Stream<RemotePushMessage> get openedMessages => _openedController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!_provider.configured) return;
    await _provider.initialize();
    _provider.tokenRefreshes.listen((_) {
      unawaited(syncRegistration());
    });
    _provider.foregroundMessages.listen(_foregroundController.add);
    _provider.openedMessages.listen(_openedController.add);
    SupabaseService.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.userUpdated) {
        unawaited(syncRegistration());
      }
    });
    final initial = await _provider.initialMessage();
    if (initial != null) _openedController.add(initial);
    await syncRegistration();
  }

  Future<RemotePushPermission> permissionStatus() async {
    if (!_provider.configured) return RemotePushPermission.unavailable;
    await initialize();
    return _provider.permissionStatus();
  }

  Future<RemotePushPermission> requestPermissionAndRegister() async {
    if (!_provider.configured) return RemotePushPermission.unavailable;
    await initialize();
    final permission = await _provider.requestPermission();
    if (_canRegister(permission)) {
      await syncRegistration(force: true);
    }
    return permission;
  }

  Future<void> syncRegistration({bool force = false}) async {
    if (!_provider.configured || _syncing) return;
    if (SupabaseService.client.auth.currentUser == null) return;
    _syncing = true;
    try {
      final permission = await _provider.permissionStatus();
      if (!_canRegister(permission)) return;
      final token = await _provider.registrationToken();
      if (token == null || token.trim().isEmpty) return;
      final package = await PackageInfo.fromPlatform();
      await NotificationsRepository().registerDevice(
        deviceId: await _deviceId(),
        provider: 'fcm',
        registrationToken: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        permissionStatus: permission == RemotePushPermission.provisional
            ? 'provisional'
            : 'authorized',
        appVersion: '${package.version}+${package.buildNumber}',
        locale: PlatformDispatcher.instance.locale.toLanguageTag(),
        timezoneName: await _timezoneName(),
        environment: AppConfig.releaseStage,
        clientRequestId: _uuid.v4(),
      );
    } finally {
      _syncing = false;
    }
  }

  Future<void> disableAllRemoteNotifications() async {
    if (SupabaseService.client.auth.currentUser != null) {
      await NotificationsRepository().unregisterDevices(
        deviceId: await _deviceId(),
        allDevices: true,
        clientRequestId: _uuid.v4(),
      );
    }
    if (_provider.configured) await _provider.deleteToken();
  }

  Future<void> prepareForSignOut({required bool allDevices}) async {
    if (!_provider.configured ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }
    await NotificationsRepository().unregisterDevices(
      deviceId: await _deviceId(),
      allDevices: allDevices,
      clientRequestId: _uuid.v4(),
    );
    await _provider.deleteToken();
  }

  Future<String> localTimezoneName() => _timezoneName();

  bool _canRegister(RemotePushPermission permission) =>
      permission == RemotePushPermission.authorized ||
      permission == RemotePushPermission.provisional;

  Future<String> _deviceId() async {
    final stored = await mortSecureDeviceStorage.read(key: _deviceIdKey);
    if (stored != null && Uuid.isValidUUID(fromString: stored)) return stored;
    final generated = _uuid.v4();
    await mortSecureDeviceStorage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  Future<String> _timezoneName() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      return timezone.identifier.trim().isEmpty ? 'UTC' : timezone.identifier;
    } catch (_) {
      return 'UTC';
    }
  }
}
