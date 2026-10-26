import 'package:flutter_mort/core/atmosphere/mort_atmosphere_device_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Galaxy A14 family selects the measured performance fallback', () {
    expect(
      MortAtmosphereDevicePolicy.requiresPerformanceFallback(
        model: 'SM_A146U',
        product: 'a14xmsq',
        isLowRamDevice: false,
      ),
      isTrue,
    );
  });

  test('Android low-RAM classification selects the fallback', () {
    expect(
      MortAtmosphereDevicePolicy.requiresPerformanceFallback(
        model: 'generic',
        product: 'generic',
        isLowRamDevice: true,
      ),
      isTrue,
    );
  });

  test('modern unmeasured Android hardware keeps shader-first rendering', () {
    expect(
      MortAtmosphereDevicePolicy.requiresPerformanceFallback(
        model: 'Pixel 9 Pro',
        product: 'komodo',
        isLowRamDevice: false,
      ),
      isFalse,
    );
  });
}
