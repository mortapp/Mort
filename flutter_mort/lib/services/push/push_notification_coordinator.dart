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
import 'coalesced_async_task.dart';
import 'remote_push_provider.dart';

class PushNotificationCoordinator {
  PushNotificationCoordinator._({RemotePushProvider? provider})
    : _provider = provider ?? createRemotePushProvider();

  @visibleForTesting
  PushNotificationCoordinator.forTesting({required RemotePushProvider provider})
    : _provider = provider;

  static final instance = PushNotificationCoordinator._();
  static const _deviceIdKey = 'mort.push.installation_id';
  static const _uuid = Uuid();

  final RemotePushProvider _provider;
  final _foregroundController = StreamController<RemotePushMessage>.broadcast();
  late final _openedController = StreamController<RemotePushMessage>.broadcast(
    onListen: _deliverPendingInitialMessage,
  );
  bool _initialized = false;
  bool _providerInitialized = false;
  bool _listenersBound = false;
  bool _initialMessageHandled = false;
  Future<void>? _initialization;
  RemotePushMessage? _pendingInitialMessage;
  final _registrationSync = CoalescedAsyncTask();

  bool get configured => _provider.configured;
  Stream<RemotePushMessage> get foregroundMessages =>
      _foregroundController.stream;
  Stream<RemotePushMessage> get openedMessages => _openedController.stream;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (!_provider.configured) {
        _initialized = true;
        return;
      }
      if (!_providerInitialized) {
        await _provider.initialize();
        _providerInitialized = true;
      }
      if (!_listenersBound) {
        _provider.tokenRefreshes.listen((_) {
          unawaited(syncRegistration());
        });
        _provider.foregroundMessages.listen(_foregroundController.add);
        _provider.openedMessages.listen(_openedController.add);
        if (SupabaseService.isInitialized) {
          SupabaseService.client.auth.onAuthStateChange.listen((state) {
            if (state.event == AuthChangeEvent.signedIn ||
                state.event == AuthChangeEvent.tokenRefreshed ||
                state.event == AuthChangeEvent.userUpdated) {
              unawaited(syncRegistration());
            }
          });
        }
        _listenersBound = true;
      }
      if (!_initialMessageHandled) {
        final initial = await _provider.initialMessage();
        _initialMessageHandled = true;
        if (initial != null) {
          if (_openedController.hasListener) {
            _openedController.add(initial);
          } else {
            _pendingInitialMessage = initial;
          }
        }
      }
      await syncRegistration();
      _initialized = true;
    } finally {
      _initialization = null;
    }
  }

  Future<RemotePushPermission> permissionStatus() async {
    if (!_provider.configured) return RemotePushPermission.unavailable;
    await initialize();
    return _provider.permissionStatus();
  }

  /// Checks the server-controlled delivery gate. Errors fail closed so the app
  /// never asks for permission or registers a token on an unknown status.
  Future<bool> deliveryAvailable() async {
    if (!_provider.configured || !SupabaseService.isInitialized) return false;
    try {
      return await NotificationsRepository().getPushDeliveryAvailability();
    } catch (_) {
      return false;
    }
  }

  Future<RemotePushPermission> requestPermissionAndRegister() async {
    if (!_provider.configured) return RemotePushPermission.unavailable;
    if (!await deliveryAvailable()) return RemotePushPermission.unavailable;
    await initialize();
    if (!await deliveryAvailable()) return RemotePushPermission.unavailable;
    final permission = await _provider.requestPermission();
    if (_canRegister(permission)) {
      await syncRegistration(force: true);
    }
    return permission;
  }

  Future<void> syncRegistration({bool force = false}) async {
    if (!_provider.configured || !SupabaseService.isInitialized) {
      return;
    }
    return _registrationSync.run(_syncRegistrationOnce);
  }

  Future<void> _syncRegistrationOnce() async {
    if (SupabaseService.client.auth.currentUser == null) return;
    if (!await deliveryAvailable()) return;
    final permission = await _provider.permissionStatus();
    if (!_canRegister(permission)) return;
    final token = await _provider.registrationToken();
    if (token == null || token.trim().isEmpty) return;
    final package = await PackageInfo.fromPlatform();
    await NotificationsRepository().registerDevice(
      deviceId: await _deviceId(),
      provider: 'fcm',
      registrationToken: token,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      permissionStatus: permission == RemotePushPermission.provisional
          ? 'provisional'
          : 'authorized',
      appVersion: '${package.version}+${package.buildNumber}',
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      timezoneName: await _timezoneName(),
      environment: AppConfig.releaseStage,
      clientRequestId: _uuid.v4(),
    );
  }

  Future<void> disableAllRemoteNotifications() async {
    if (SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentUser != null) {
      await NotificationsRepository().unregisterDevices(
        deviceId: await _deviceId(),
        allDevices: true,
        clientRequestId: _uuid.v4(),
      );
    }
    if (_provider.configured) await _provider.deleteToken();
  }

  Future<void> prepareForSignOut({required bool allDevices}) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.client.auth.currentUser == null) {
      return;
    }
    await NotificationsRepository().unregisterDevices(
      deviceId: await _deviceId(),
      allDevices: allDevices,
      clientRequestId: _uuid.v4(),
    );
    if (_provider.configured) await _provider.deleteToken();
  }

  Future<String> localTimezoneName() => _timezoneName();

  bool _canRegister(RemotePushPermission permission) =>
      permission == RemotePushPermission.authorized ||
      permission == RemotePushPermission.provisional;

  void _deliverPendingInitialMessage() {
    final message = _pendingInitialMessage;
    if (message == null) return;
    _pendingInitialMessage = null;
    _openedController.add(message);
  }

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
