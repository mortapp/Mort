import 'package:flutter_mort/core/utils/financial_math.dart';
import 'package:flutter_mort/data/models/financial_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('net earnings estimate', () {
    test('gross minus expenses', () {
      expect(
        estimatedNetCents(grossCents: 300000, expensesCents: 120000),
        180000,
      );
      expect(estimatedNetCents(grossCents: 0, expensesCents: 0), 0);
    });

    test('negative net stays honest (no clamping)', () {
      expect(estimatedNetCents(grossCents: 5000, expensesCents: 9000), -4000);
    });

    test('FinancialSummary parses server summary and derives net', () {
      final summary = FinancialSummary.fromJson({
        'ok': true,
        'year': 2027,
        'gross_tracked_cents': 684000,
        'jobs_completed': 37,
        'method_breakdown': [
          {
            'method': 'cash',
            'category': 'DIRECT_CASH',
            'amount_cents': 200000,
            'count': 12,
          },
          {
            'method': 'cash_app',
            'category': 'DIRECT_ELECTRONIC',
            'amount_cents': 350000,
            'count': 20,
          },
          {
            'method': 'flexible',
            'category': 'UNKNOWN_DIRECT',
            'amount_cents': 134000,
            'count': 5,
          },
        ],
        'expenses_cents': 131000,
        'expense_count': 14,
        'receipts_count': 14,
        'personal_targets': [
          {
            'id': 't1',
            'year': 2027,
            'amount_cents': 800000,
            'label': 'Personal earning target',
          },
        ],
        'disclaimer':
            'Recordkeeping estimate — not a tax return or tax determination.',
      });
      // All three method categories count toward the SAME tracked gross.
      expect(summary.grossTrackedCents, 684000);
      expect(summary.methodBreakdown.map((m) => m.compensationCategory.wire), [
        'DIRECT_CASH',
        'DIRECT_ELECTRONIC',
        'UNKNOWN_DIRECT',
      ]);
      expect(summary.estimatedNetCents, 553000);
      expect(summary.disclaimer, contains('not a tax return'));
    });
  });

  group('payment method changes never reset earnings', () {
    test('changing methods across the year keeps one cumulative total', () {
      // Cash $2,000, external electronic $3,500, other direct $4,500:
      // the tracked gross must remain the full $10,000 regardless of the
      // method used for any individual job.
      final methods = [
        const FinancialMethodBreakdown(
          method: 'cash',
          category: 'DIRECT_CASH',
          amountCents: 200000,
          count: 10,
        ),
        const FinancialMethodBreakdown(
          method: 'cash_app',
          category: 'DIRECT_ELECTRONIC',
          amountCents: 350000,
          count: 15,
        ),
        const FinancialMethodBreakdown(
          method: 'flexible',
          category: 'UNKNOWN_DIRECT',
          amountCents: 450000,
          count: 12,
        ),
      ];
      final total = methods.fold<int>(0, (sum, m) => sum + m.amountCents);
      expect(total, 1000000);
    });

    test('unknown future categories still count (never excluded)', () {
      // If the backend later reports a GIFT_CARD or MORT_PROCESSED
      // category, the client must never treat it as "not counted": it maps
      // to the generic direct bucket and its amount stays inside gross.
      expect(CompensationCategory.fromWire('GIFT_CARD').wire, 'UNKNOWN_DIRECT');
      expect(
        CompensationCategory.fromWire('MORT_PROCESSED').wire,
        'UNKNOWN_DIRECT',
      );
    });

    test('no compensation category is labeled tax-free or benefits-safe', () {
      for (final category in CompensationCategory.values) {
        expect(category.label.toLowerCase().contains('tax-free'), isFalse);
        expect(category.label.toLowerCase().contains('benefits-safe'), isFalse);
        expect(category.label.toLowerCase().contains('avoid'), isFalse);
      }
    });
  });

  group('alert levels', () {
    test('70/85/95/100 thresholds', () {
      expect(alertLevelForPercent(69), isNull);
      expect(alertLevelForPercent(70), 'HEADS_UP');
      expect(alertLevelForPercent(84), 'HEADS_UP');
      expect(alertLevelForPercent(85), 'FINANCIAL_CHECK');
      expect(alertLevelForPercent(95), 'REVIEW_RECOMMENDED');
      expect(alertLevelForPercent(100), 'THRESHOLD_REACHED');
      expect(alertLevelForPercent(150), 'THRESHOLD_REACHED');
    });

    test('check label picks the highest severity without alarm words', () {
      expect(financialCheckLabel(const []), 'Good');
      expect(financialCheckLabel(const ['HEADS_UP']), 'Heads up');
      expect(
        financialCheckLabel(const ['HEADS_UP', 'FINANCIAL_CHECK']),
        'Financial check',
      );
      expect(
        financialCheckLabel(const ['FINANCIAL_CHECK', 'THRESHOLD_REACHED']),
        'Threshold reached',
      );
      for (final label in [
        financialCheckLabel(const ['THRESHOLD_REACHED']),
        financialCheckLabel(const ['REVIEW_RECOMMENDED']),
      ]) {
        expect(label.toLowerCase().contains('banned'), isFalse);
        expect(label.toLowerCase().contains('blocked'), isFalse);
      }
    });
  });

  group('calendar year math', () {
    test('year bounds are inclusive of the whole calendar year', () {
      final (start, end) = calendarYearBounds(2027);
      expect(start, DateTime(2027, 1, 1));
      expect(end.year, 2027);
      expect(end.month, 12);
      expect(end.day, 31);
    });

    test(
      'rollover: December 31 belongs to its year, January 1 to the next',
      () {
        expect(
          isWithinCalendarYear(DateTime(2026, 12, 31, 23, 59), 2026),
          isTrue,
        );
        expect(isWithinCalendarYear(DateTime(2027, 1, 1), 2026), isFalse);
        expect(isWithinCalendarYear(DateTime(2026, 1, 1), 2027), isFalse);
        expect(isWithinCalendarYear(DateTime(2027, 7, 4), 2027), isTrue);
      },
    );
  });

  group('targets', () {
    test('progress and percent clamp correctly', () {
      expect(
        percentOfThreshold(amountCents: 400000, thresholdCents: 800000),
        50,
      );
      expect(
        percentOfThreshold(amountCents: 1600000, thresholdCents: 800000),
        200,
      );
      expect(
        targetProgress(amountCents: 400000, targetCents: 800000),
        closeTo(0.5, 0.001),
      );
      expect(targetProgress(amountCents: 900000, targetCents: 800000), 1.0);
      expect(targetProgress(amountCents: 1, targetCents: 0), 0);
    });

    test('personal target label never claims a government threshold', () {
      const target = FinancialPersonalTarget(
        id: 't',
        year: 2027,
        amountCents: 800000,
        label: 'Personal earning target',
      );
      final text = target.label.toLowerCase();
      expect(text.contains('irs'), isFalse);
      expect(text.contains('government'), isFalse);
      expect(text.contains('benefit limit'), isFalse);
    });
  });

  group('currency formatting', () {
    test('formats with thousands separators', () {
      expect(formatUsdCents(684000), '\$6,840.00');
      expect(formatUsdCents(0), '\$0.00');
      expect(formatUsdCents(5), '\$0.05');
      expect(formatUsdCents(-131000), '-\$1,310.00');
    });
  });
}
