import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/observability/structured_log.dart';
import '../../core/utils/retryable_initialization.dart';
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
  final _initialization = RetryableInitialization();
  bool _syncing = false;

  bool get configured => _provider.configured;
  Stream<RemotePushMessage> get foregroundMessages =>
      _foregroundController.stream;
  Stream<RemotePushMessage> get openedMessages => _openedController.stream;

  Future<void> initialize() => _initialization.run(_initialize);

  Future<void> startBestEffort() async {
    try {
      await initialize();
    } catch (_) {
      _recordFailure('mort.push.provider_setup_failed');
    }
  }

  Future<void> _initialize() async {
    if (!_provider.configured) return;
    final auth = SupabaseService.client.auth;
    await _provider.initialize();
    final initial = await _provider.initialMessage();
    _provider.tokenRefreshes.listen((_) {
      unawaited(_syncRegistrationBestEffort());
    }, onError: _recordStreamFailure);
    _provider.foregroundMessages.listen(
      _foregroundController.add,
      onError: _recordStreamFailure,
    );
    _provider.openedMessages.listen(
      _openedController.add,
      onError: _recordStreamFailure,
    );
    auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.userUpdated) {
        unawaited(_syncRegistrationBestEffort());
      }
    }, onError: _recordStreamFailure);
    if (initial != null) _openedController.add(initial);
    unawaited(_syncRegistrationBestEffort());
  }

  Future<void> _syncRegistrationBestEffort() async {
    try {
      await syncRegistration();
    } catch (_) {
      _recordFailure('mort.push.registration_failed');
    }
  }

  void _recordStreamFailure(Object _, StackTrace _) {
    _recordFailure('mort.push.provider_stream_failed');
  }

  void _recordFailure(String event) {
    MortStructuredLog.instance.record(
      event,
      level: MortLogLevel.warning,
      attributes: const {'provider': 'fcm', 'outcome': 'failed'},
    );
  }

  Future<RemotePushPermission> permissionStatus() async {
    if (!_provider.configured) return RemotePushPermission.unavailable;
    await initialize();
    return _provider.permissionStatus();
  }

  Future<RemotePushPermission> requestPermissionAndRegister() async {
    if (!_provider.configured) return RemotePushPermission.unavailable;
    if (SupabaseService.client.auth.currentUser == null) {
      return RemotePushPermission.unavailable;
    }
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
    if (_provider.configured) {
      await initialize();
      await _provider.deleteToken();
    }
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
