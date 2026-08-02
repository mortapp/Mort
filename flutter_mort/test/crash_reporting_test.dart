import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/observability/crash_reporting.dart';

void main() {
  tearDown(() => MortCrashReporting.instance.configure());

  test(
    'crash envelopes contain categories but never exception messages',
    () async {
      CrashEnvelope? captured;
      MortCrashReporting.instance.configure(
        sink: (event, _) async {
          captured = event;
        },
        providerName: 'sentry',
      );

      await MortCrashReporting.instance.record(
        StateError('private token and exact address'),
        StackTrace.fromString('private stack contents'),
        fatal: true,
        context: 'platform_dispatcher',
      );

      expect(captured, isNotNull);
      expect(captured!.category, 'stateerror');
      expect(captured!.context, 'platform_dispatcher');
      expect(captured!.correlationId, isNotEmpty);
      expect(
        captured!.toSafeMap().toString(),
        isNot(contains('private token')),
      );
      expect(
        captured!.toSafeMap().toString(),
        isNot(contains('private stack')),
      );
    },
  );

  test('unknown contexts fail closed to an allowlisted value', () {
    expect(
      MortCrashReporting.instance.safeContext('job/123?secret=value'),
      'unspecified',
    );
  });
}
