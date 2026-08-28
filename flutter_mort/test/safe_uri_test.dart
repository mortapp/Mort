import 'package:flutter_mort/core/utils/safe_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('external links require public HTTPS destinations', () {
    expect(safeExternalHttpsUri('https://www.irs.gov/teen-work'), isNotNull);
    for (final value in [
      'http://example.com',
      'javascript:alert(1)',
      'https://user:password@example.com',
      'https://localhost/source',
      'https://127.0.0.1/source',
      'https://10.0.0.2/source',
      'https://172.16.0.1/source',
      'https://192.168.1.1/source',
      'https://example.com:8443/source',
      'https://[::1]/source',
    ]) {
      expect(safeExternalHttpsUri(value), isNull, reason: value);
    }
  });

  test('Stripe onboarding requires the exact Connect host', () {
    expect(
      safeStripeConnectUri('https://connect.stripe.com/setup/s/test'),
      isNotNull,
    );
    expect(
      safeStripeConnectUri('https://connect.stripe.com.attacker.test/setup'),
      isNull,
    );
    expect(safeStripeConnectUri('https://stripe.example/setup'), isNull);
  });

  test('internal help routes cannot navigate to privileged areas', () {
    expect(safeInternalHelpRoute('/support'), '/support');
    expect(safeInternalHelpRoute('/legal/privacy'), '/legal/privacy');
    expect(safeInternalHelpRoute('/guide/history'), '/guide/history');
    for (final value in [
      '/admin/users',
      '/adult/jobs',
      '//attacker.test/path',
      'https://attacker.test',
      '/support/../admin/users',
    ]) {
      expect(safeInternalHelpRoute(value), isNull, reason: value);
    }
  });
}
