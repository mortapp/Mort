import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Converts measured hardware constraints into a renderer choice. The
/// Galaxy A14 family is listed because physical profiling on SM-A146U showed
/// full-resolution multi-pass fBm could not maintain an interactive cadence.
/// Other Android devices retain shader-first rendering unless Android itself
/// classifies them as low-RAM.
class MortAtmosphereDevicePolicy {
  const MortAtmosphereDevicePolicy._();

  static bool requiresPerformanceFallback({
    required String model,
    required String product,
    required bool isLowRamDevice,
  }) {
    if (isLowRamDevice) return true;
    final normalizedModel = model.toLowerCase().replaceAll(
      RegExp('[^a-z0-9]'),
      '',
    );
    final normalizedProduct = product.toLowerCase().replaceAll(
      RegExp('[^a-z0-9]'),
      '',
    );
    return normalizedModel.startsWith('sma14') ||
        normalizedProduct.startsWith('a14');
  }

  static Future<bool> detectPerformanceFallback() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return requiresPerformanceFallback(
        model: info.model,
        product: info.product,
        isLowRamDevice: info.isLowRamDevice,
      );
    } catch (error) {
      debugPrint('MORT atmosphere device policy unavailable: $error');
      return false;
    }
  }
}
