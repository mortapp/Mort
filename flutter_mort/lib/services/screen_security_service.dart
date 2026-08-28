import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenSecurityService {
  const ScreenSecurityService._();

  static const _channel = MethodChannel('mort/native_security');
  static int _activeSensitiveScreens = 0;

  static Future<void> acquire() async {
    _activeSensitiveScreens += 1;
    if (_activeSensitiveScreens == 1) await _setSecure(true);
  }

  static Future<void> release() async {
    if (_activeSensitiveScreens <= 0) return;
    _activeSensitiveScreens -= 1;
    if (_activeSensitiveScreens == 0) await _setSecure(false);
  }

  static Future<void> _setSecure(bool enabled) async {
    if (_platformSetter != null) {
      await _platformSetter!(enabled);
      return;
    }
    final platform = defaultTargetPlatform;
    final supportsNativeProtection =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (kIsWeb || !supportsNativeProtection) return;
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Native protection is unavailable in unit tests and unsupported builds.
    }
  }

  @visibleForTesting
  static Future<void> debugReset() async {
    _activeSensitiveScreens = 0;
    await _setSecure(false);
  }

  // A test-only platform setter allowing tests to inject a narrow adapter
  // for observing or faking native secure calls. Visible for testing only.
  @visibleForTesting
  static void setPlatformSetter(Future<void> Function(bool enabled)? setter) {
    _platformSetter = setter;
  }

  static Future<void> Function(bool enabled)? _platformSetter;
}

class SensitiveScreenProtection extends StatefulWidget {
  const SensitiveScreenProtection({super.key, required this.child});

  final Widget child;

  @override
  State<SensitiveScreenProtection> createState() =>
      _SensitiveScreenProtectionState();
}

class _SensitiveScreenProtectionState extends State<SensitiveScreenProtection> {
  @override
  void initState() {
    super.initState();
    ScreenSecurityService.acquire();
  }

  @override
  void dispose() {
    ScreenSecurityService.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
