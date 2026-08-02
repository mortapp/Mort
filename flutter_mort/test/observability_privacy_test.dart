import 'package:flutter_mort/core/observability/product_analytics.dart';
import 'package:flutter_mort/core/observability/sentry_crash_provider.dart';
import 'package:flutter_mort/core/observability/structured_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  tearDown(() => MortStructuredLog.instance.clear());

  test('structured logs drop sensitive keys and redact unsafe values', () {
    MortStructuredLog.instance.record(
      'mort.repository.failed',
      level: MortLogLevel.error,
      attributes: const {
        'code': 'network_timeout',
        'provider': 'https://private.example/token',
        'message': 'PIN 123456 at an exact address',
      },
    );

    final record = MortStructuredLog.instance.recent.single;
    expect(record.event, 'mort.repository.failed');
    expect(record.attributes['code'], 'network_timeout');
    expect(record.attributes['provider'], 'redacted');
    expect(record.attributes, isNot(contains('message')));
    expect(record.toSafeMap().toString(), isNot(contains('123456')));
  });

  test(
    'Sentry sanitizer strips content, identity, requests, and unsafe crumbs',
    () {
      final raw = SentryEvent(
        message: SentryMessage('Private message text and PIN 123456'),
        user: SentryUser(id: 'teen-user-id', email: 'teen@example.test'),
        request: SentryRequest(url: 'https://example.test/jobs/exact-address'),
        exceptions: [
          SentryException(
            type: 'State Error',
            value: 'OAuth code and exact location',
          ),
        ],
        breadcrumbs: [
          Breadcrumb(category: 'http', message: 'Bearer private-token'),
          Breadcrumb(
            category: 'mort.repository.failed',
            data: const {
              'code': 'network_timeout',
              'message': 'private child content',
            },
          ),
        ],
        tags: const {'mort_context': 'job/uuid?pin=123456'},
      );

      final safe = MortSentryCrashProvider.sanitizeEvent(raw, Hint());
      final encoded = safe.toJson().toString();
      expect(safe.message, isNull);
      expect(safe.user, isNull);
      expect(safe.request, isNull);
      expect(safe.exceptions!.single.value, '[details redacted]');
      expect(safe.tags!['mort_context'], 'unspecified');
      expect(safe.breadcrumbs, hasLength(1));
      expect(safe.breadcrumbs!.single.data, isNot(contains('message')));
      for (final prohibited in [
        '123456',
        'teen@example.test',
        'private-token',
        'exact-address',
        'OAuth code',
        'private child content',
      ]) {
        expect(encoded, isNot(contains(prohibited)));
      }
    },
  );

  test('route analytics collapse paths and identifiers into safe surfaces', () {
    final analytics = MortProductAnalytics.instance;
    expect(analytics.surfaceForPath('/jobs/11111111/private'), 'jobs');
    expect(analytics.surfaceForPath('/messages/thread-secret'), 'messages');
    expect(analytics.surfaceForPath('/support/tickets/private-id'), 'support');
    expect(
      analytics.surfaceForPath('https://evil.test/?token=secret'),
      'unknown',
    );
  });
}
