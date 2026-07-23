import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

enum DeviceAuthenticationStatus {
  authenticated,
  unavailable,
  notEnrolled,
  lockedOut,
  cancelled,
  denied,
  failed,
}

class DeviceAuthenticationCapability {
  const DeviceAuthenticationCapability({
    required this.supported,
    required this.hasEnrolledBiometrics,
    required this.label,
  });

  const DeviceAuthenticationCapability.unavailable()
    : supported = false,
      hasEnrolledBiometrics = false,
      label = 'Unavailable';

  final bool supported;
  final bool hasEnrolledBiometrics;
  final String label;
}

class DeviceAuthenticationResult {
  const DeviceAuthenticationResult(this.status, this.message);

  final DeviceAuthenticationStatus status;
  final String message;

  bool get succeeded => status == DeviceAuthenticationStatus.authenticated;
}

class DeviceAuthenticationService {
  DeviceAuthenticationService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  Future<DeviceAuthenticationCapability> capability() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return const DeviceAuthenticationCapability.unavailable();
    }
    try {
      final supported = await _authentication.isDeviceSupported();
      final biometrics = await _authentication.getAvailableBiometrics();
      return DeviceAuthenticationCapability(
        supported: supported,
        hasEnrolledBiometrics: biometrics.isNotEmpty,
        label: _capabilityLabel(supported, biometrics),
      );
    } catch (_) {
      return const DeviceAuthenticationCapability.unavailable();
    }
  }

  Future<DeviceAuthenticationResult> authenticate(String reason) async {
    final available = await capability();
    if (!available.supported) {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.unavailable,
        'Device authentication is unavailable on this device.',
      );
    }
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? DeviceAuthenticationResult(
              DeviceAuthenticationStatus.authenticated,
              '${available.label} succeeded. No biometric data left the device.',
            )
          : const DeviceAuthenticationResult(
              DeviceAuthenticationStatus.failed,
              'Authentication did not succeed. Private MORT content remains locked.',
            );
    } on LocalAuthException catch (error) {
      return _mapException(error);
    } catch (_) {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.failed,
        'Authentication could not be completed. Private MORT content remains locked.',
      );
    }
  }

  static String _capabilityLabel(
    bool supported,
    List<BiometricType> biometrics,
  ) {
    if (biometrics.contains(BiometricType.face)) return 'Face authentication';
    if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint authentication';
    }
    if (biometrics.isNotEmpty) return 'Biometric authentication';
    if (supported) return 'Device PIN, pattern, or passcode';
    return 'Unavailable';
  }

  static DeviceAuthenticationResult _mapException(LocalAuthException error) {
    final code = error.code.name.toLowerCase();
    if (code.contains('notenrolled') || code.contains('nobiometrics')) {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.notEnrolled,
        'Set up a screen lock or biometric method in device settings, then try again.',
      );
    }
    if (code.contains('lockout')) {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.lockedOut,
        'Device authentication is locked after failed attempts. Unlock the device normally, then retry.',
      );
    }
    if (code.contains('cancel')) {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.cancelled,
        'Authentication was cancelled. Private MORT content remains locked.',
      );
    }
    if (code.contains('permission') || code.contains('passcode')) {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.denied,
        'A device screen lock or biometric permission is required.',
      );
    }
    if (code.contains('hardware') || code.contains('unsupported')) {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.unavailable,
        'Device authentication is unavailable on this device.',
      );
    }
    return const DeviceAuthenticationResult(
      DeviceAuthenticationStatus.failed,
      'Authentication failed. Private MORT content remains locked.',
    );
  }
}
