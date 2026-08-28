import 'package:flutter_mort/core/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every legacy checkpoint route converges on four-step onboarding', () {
    expect(legacyOnboardingPaths, hasLength(11));
    for (final path in legacyOnboardingPaths) {
      expect(canonicalOnboardingPath(path), '/onboarding');
    }
    expect(canonicalOnboardingPath('/onboarding'), '/onboarding');
  });
}
