import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('push worker uses bounded input and redacted structured telemetry', () {
    final push = _read('../supabase/functions/send-push/index.ts');
    final observability = _read(
      '../supabase/functions/_shared/observability.ts',
    );
    final stripe = _read('../supabase/functions/_shared/stripe.ts');

    expect(push, contains('maximumBodyBytes'));
    expect(push, contains('constantTimeEqual(invokeSecret, suppliedSecret)'));
    expect(push, contains('correlationId(request)'));
    expect(push, contains('structuredLog("error", "push.request_failed"'));
    expect(push, contains('service_complete_push_event'));
    expect(push, contains('error_code: providerCode'));
    expect(push, isNot(contains('error_code: body.error.message')));
    expect(push, isNot(contains('console.error("send-push failed", error)')));
    expect(observability, contains('"x-correlation-id": traceId'));
    expect(observability, contains('constantTimeEqual'));
    expect(stripe, contains('correlatedJson(body, status, traceId'));
    expect(stripe, contains('structuredLog("error", "stripe.provider_failed"'));
    expect(stripe, isNot(contains('console.error("Stripe operation failed"')));
  });
}
