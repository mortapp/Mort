import 'dart:io';

import 'package:flutter_mort/core/money/mort_service_fee.dart';
import 'package:flutter_mort/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('payment-disabled offered amount', () {
    test('deducts no platform fee', () {
      expect(MortServiceFee.serviceFeeCents, 0);
    });

    for (final testCase in const [
      ('25.00', 2500, 2500),
      ('10.00', 1000, 1000),
      ('5.00', 500, 500),
    ]) {
      test('${testCase.$1} produces the required payout', () {
        final result = MortServiceFee.breakdown(testCase.$1);

        expect(result, isNotNull);
        expect(result!.adultJobAmountCents, testCase.$2);
        expect(result.serviceFeeCents, 0);
        expect(result.teenPayoutCents, testCase.$3);
      });
    }

    for (final invalid in const ['0.00', '-1.00', 'not money', '10.001', '']) {
      test('rejects invalid adult amount "$invalid"', () {
        expect(MortServiceFee.tryParseAdultAmount(invalid), isNull);
        expect(MortServiceFee.validateAdultAmount(invalid), isNotNull);
      });
    }

    test('parses cents without floating-point arithmetic', () {
      expect(MortServiceFee.tryParseAdultAmount('5'), 500);
      expect(MortServiceFee.tryParseAdultAmount('5.5'), 550);
      expect(MortServiceFee.tryParseAdultAmount('5.05'), 505);
    });

    test('formats teen payout with two decimal places', () {
      expect(formatCents(2500), '\$25.00');
      expect(formatCents(500), '\$5.00');
    });
  });

  test('server migration preserves client-write denial and sets zero fee', () {
    final migrations = Directory('../supabase/migrations')
        .listSync()
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(migrations, contains("- 'pay_amount_cents'"));
    expect(migrations, contains('mort_payments_disabled_zero_fee'));
    expect(migrations, contains('mort_service_fee_cents = 0'));
  });
}
