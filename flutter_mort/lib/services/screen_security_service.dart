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
    _activeSensitiveScreens = (_activeSensitiveScreens - 1).clamp(0, 1000);
    if (_activeSensitiveScreens == 0) await _setSecure(false);
  }

  static Future<void> _setSecure(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Native protection is unavailable in unit tests and non-Android builds.
    }
  }
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
