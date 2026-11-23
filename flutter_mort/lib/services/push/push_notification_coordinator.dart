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
import 'push_registration_gate.dart';
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
  final _registration = PushRegistrationGate();

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
    final owner = _signedInUserId;
    if (owner == null) return RemotePushPermission.unavailable;
    await initialize();
    if (owner != _signedInUserId) return RemotePushPermission.unavailable;
    final permission = await _provider.requestPermission();
    if (owner != _signedInUserId) return RemotePushPermission.unavailable;
    if (_canRegister(permission)) {
      _registration.explicitOptIn(owner);
      if (!_registration.allows(owner)) return RemotePushPermission.unavailable;
      await syncRegistration(explicitOptIn: true);
    }
    return permission;
  }

  String? get _signedInUserId => SupabaseService.isInitialized
      ? SupabaseService.client.auth.currentUser?.id
      : null;

  Future<void> syncRegistration({bool explicitOptIn = false}) async {
    if (!_provider.configured) return;
    final owner = _signedInUserId;
    if (owner == null) return;
    bool stillEligible() =>
        owner == _signedInUserId && _registration.allows(owner);
    var registrationConfirmed = false;
    await _registration.sync(owner, () async {
      final repository = NotificationsRepository();
      // The registration RPC also enables alerts. Never call it on an
      // automatic callback after the account has disabled them.
      if (!explicitOptIn && !(await repository.getPreferences()).pushEnabled) {
        return;
      }
      if (!stillEligible()) return;
      final permission = await _provider.permissionStatus();
      if (!_canRegister(permission) || !stillEligible()) return;
      final token = await _provider.registrationToken();
      if (token == null || token.trim().isEmpty || !stillEligible()) return;
      final package = await PackageInfo.fromPlatform();
      final deviceId = await _deviceId();
      final timezone = await _timezoneName();
      if (!stillEligible()) return;
      await repository.registerDevice(
        deviceId: deviceId,
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
        timezoneName: timezone,
        environment: AppConfig.releaseStage,
        clientRequestId: _uuid.v4(),
      );
      registrationConfirmed = stillEligible();
    }, runAfterActive: explicitOptIn);
    if (explicitOptIn && !registrationConfirmed) {
      throw StateError('Remote alerts are not registered. Try again shortly.');
    }
  }

  Future<void> disableAllRemoteNotifications() async {
    final owner = _signedInUserId;
    if (owner == null) return;
    await _revoke(owner, allDevices: true);
  }

  Future<void> _revoke(String owner, {required bool allDevices}) =>
      _registration.revoke(owner, () async {
        final deviceId = await _deviceId();
        if (owner != _signedInUserId) {
          throw StateError('Notification revocation account changed.');
        }
        try {
          await NotificationsRepository().unregisterDevices(
            deviceId: deviceId,
            allDevices: allDevices,
            clientRequestId: _uuid.v4(),
          );
        } finally {
          if (_provider.configured && owner == _signedInUserId) {
            await initialize();
            if (owner == _signedInUserId) await _provider.deleteToken();
          }
        }
      });

  Future<void> prepareForSignOut({required bool allDevices}) async {
    final owner = _signedInUserId;
    if (!_provider.configured || owner == null) return;
    await _revoke(owner, allDevices: allDevices);
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
