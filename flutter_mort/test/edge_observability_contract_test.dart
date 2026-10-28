import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('active Edge Functions use redacted structured telemetry', () {
    final observability = _read(
      '../supabase/functions/_shared/observability.ts',
    );
    final stripe = _read('../supabase/functions/_shared/stripe.ts');

    expect(observability, contains('"x-correlation-id": traceId'));
    expect(observability, contains('constantTimeEqual'));
    expect(stripe, contains('correlatedJson(body, status, traceId'));
    expect(stripe, contains('structuredLog("error", "stripe.provider_failed"'));
    expect(stripe, isNot(contains('console.error("Stripe operation failed"')));
  });
}
