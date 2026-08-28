import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/services/secure_device_storage.dart';
import 'device_authentication_service.dart';

class AppLockPolicy {
  const AppLockPolicy._();

  static bool shouldLock({
    required bool enabled,
    required DateTime? backgroundedAt,
    required DateTime now,
    required int inactivityMinutes,
  }) {
    if (!enabled || backgroundedAt == null) return false;
    return now.difference(backgroundedAt) >=
        Duration(minutes: inactivityMinutes.clamp(1, 240));
  }
}

class AppLockController extends ChangeNotifier {
  AppLockController({
    FlutterSecureStorage? storage,
    DeviceAuthenticationService? authentication,
  }) : _storage = storage ?? mortSecureDeviceStorage,
       _authentication = authentication ?? DeviceAuthenticationService();

  static final instance = AppLockController();
  static const _enabledKey = 'mort.app_lock.enabled';
  static const _minutesKey = 'mort.app_lock.minutes';

  final FlutterSecureStorage _storage;
  final DeviceAuthenticationService _authentication;
  DateTime? _backgroundedAt;
  bool _initialized = false;
  bool _authenticating = false;

  bool enabled = false;
  bool isLocked = false;
  bool privacyCovered = false;
  int inactivityMinutes = 15;
  String? failureMessage;
  DeviceAuthenticationCapability capability =
      const DeviceAuthenticationCapability.unavailable();

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final settings = await _storage.readAll();
      enabled = settings[_enabledKey] == 'true';
      final storedMinutes = int.tryParse(settings[_minutesKey] ?? '');
      inactivityMinutes = (storedMinutes ?? 15).clamp(1, 240);
      capability = await _authentication.capability();
      isLocked = enabled && capability.supported;
    } catch (_) {
      failureMessage =
          'Local app-lock settings could not be restored on this device.';
    }
    notifyListeners();
  }

  Future<DeviceAuthenticationResult> testAuthentication() async {
    _authenticating = true;
    notifyListeners();
    final result = await _authentication.authenticate(
      'Confirm device authentication for MORT. This does not verify legal identity.',
    );
    _authenticating = false;
    capability = await _authentication.capability();
    failureMessage = result.succeeded ? null : result.message;
    notifyListeners();
    return result;
  }

  Future<bool> updateSettings({
    required bool requireLock,
    required int minutes,
  }) async {
    if (requireLock) {
      final result = await testAuthentication();
      if (!result.succeeded) return false;
    }
    enabled = requireLock;
    inactivityMinutes = minutes.clamp(1, 240);
    if (!enabled) {
      isLocked = false;
      failureMessage = null;
    }
    await _storage.write(key: _enabledKey, value: enabled.toString());
    await _storage.write(key: _minutesKey, value: inactivityMinutes.toString());
    notifyListeners();
    return true;
  }

  void handleLifecycle(AppLifecycleState state, {DateTime? at}) {
    final now = at ?? DateTime.now();
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      privacyCovered = true;
      _backgroundedAt ??= now;
      notifyListeners();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    privacyCovered = false;
    if (!_authenticating &&
        AppLockPolicy.shouldLock(
          enabled: enabled,
          backgroundedAt: _backgroundedAt,
          now: now,
          inactivityMinutes: inactivityMinutes,
        )) {
      isLocked = true;
      failureMessage = null;
    }
    _backgroundedAt = null;
    notifyListeners();
  }

  void lockNow() {
    if (!enabled) return;
    isLocked = true;
    failureMessage = null;
    notifyListeners();
  }

  Future<void> unlock() async {
    if (!isLocked || _authenticating) return;
    _authenticating = true;
    failureMessage = null;
    notifyListeners();
    final result = await _authentication.authenticate(
      'Unlock MORT after inactivity.',
    );
    _authenticating = false;
    if (result.succeeded) {
      isLocked = false;
      failureMessage = null;
    } else {
      failureMessage = result.message;
    }
    notifyListeners();
  }

  bool get authenticating => _authenticating;
  bool get initialized => _initialized;
}
