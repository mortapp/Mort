import 'package:flutter_mort/data/repositories/monetization_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the one-row table result from get_my_entitlements', () {
    final entitlements = MonetizationRepository.parseMyEntitlementsResponse([
      {'premium_active': false, 'ad_free_active': true},
    ]);

    expect(entitlements['premium_active'], isFalse);
    expect(entitlements['ad_free_active'], isTrue);
  });

  test('accepts a map-shaped RPC result for compatibility', () {
    final entitlements = MonetizationRepository.parseMyEntitlementsResponse({
      'premium_active': true,
      'ad_free_active': true,
    });

    expect(entitlements['premium_active'], isTrue);
    expect(entitlements['ad_free_active'], isTrue);
  });

  test('rejects malformed or ambiguous entitlement responses', () {
    for (final result in [
      null,
      'invalid',
      const <dynamic>[],
      [
        {'ad_free_active': false},
        {'ad_free_active': true},
      ],
    ]) {
      expect(
        () => MonetizationRepository.parseMyEntitlementsResponse(result),
        throwsFormatException,
      );
    }
  });
}
