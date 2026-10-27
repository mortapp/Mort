import 'package:flutter_mort/data/models/financial_safety.dart';
import 'package:flutter_mort/features/financial/financial_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialYearReport _report() {
  return FinancialYearReport.fromJson({
    'ok': true,
    'year': 2027,
    'earnings': [
      {
        'title': 'Yard cleanup, 3 hours (cash, picked up in person)',
        'completed_on': '2027-03-14',
        'method': 'cash',
        'amount_cents': 12000,
      },
      {
        'title': 'Dog walking week',
        'completed_on': '2027-04-02',
        'method': 'cash_app',
        'amount_cents': 8000,
      },
    ],
    'expenses': [
      {
        'spent_on': '2027-03-13',
        'category': 'SUPPLIES',
        'merchant': 'Hardware store',
        'description': 'Bags, "large", 10x',
        'amount_cents': 2400,
        'has_receipt': true,
      },
      {
        'spent_on': '2027-04-01',
        'category': 'FUEL',
        'merchant': '',
        'description': 'Mower fuel',
        'amount_cents': 1500,
        'has_receipt': false,
      },
    ],
    'disclaimer':
        'For recordkeeping only. This report is not tax, legal, benefits, or '
        'financial advice.',
  });
}

void main() {
  group('CSV exports', () {
    test('earnings CSV includes every compensation method and the total', () {
      final csv = FinancialExportService.buildEarningsCsv(_report());
      expect(csv, contains('MORT Earnings Summary 2027'));
      expect(csv, contains('2027-03-14'));
      expect(csv, contains('Yard cleanup'));
      expect(csv, contains('cash'));
      expect(csv, contains('cash_app'));
      expect(csv, contains('\$200.00'));
      expect(csv, contains('\$80.00'));
      expect(csv, contains('Total'));
      expect(csv, contains('\$200.00'));
      expect(csv, contains(FinancialExportService.earningsDisclaimer));
    });

    test('earnings CSV escapes commas and quotes', () {
      final csv = FinancialExportService.buildEarningsCsv(_report());
      expect(
        csv,
        contains('"Yard cleanup, 3 hours (cash, picked up in person)"'),
      );
    });

    test('expense CSV lists recorded expenses, never "deductible"', () {
      final csv = FinancialExportService.buildExpensesCsv(_report());
      expect(csv, contains('MORT Expense Report 2027'));
      expect(csv, contains('SUPPLIES'));
      expect(csv, contains('FUEL'));
      expect(csv, contains('Receipt'));
      expect(csv, contains('1 receipts'));
      expect(csv.toLowerCase().contains('deductible'), isFalse);
    });

    test('receipt index includes only rows with receipts', () {
      final csv = FinancialExportService.buildReceiptIndexCsv(_report());
      expect(csv, contains('Hardware store'));
      expect(csv.contains('Mower fuel'), isFalse);
    });
  });

  group('PDF export', () {
    test('builds a real non-empty PDF', () async {
      final bytes = await FinancialExportService.buildEarningsSummaryPdf(
        _report(),
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));
      expect(bytes.first, 0x25); // '%PDF' header
    });

    test('method breakdown keeps every compensation method counted', () {
      final totals = FinancialExportService.methodTotals(_report());
      expect(totals['cash'], 12000);
      expect(totals['cash_app'], 8000);
      expect(
        totals.values.fold<int>(0, (sum, value) => sum + value),
        _report().earningsTotalCents,
      );
    });

    test('expense category totals keep every recorded expense counted', () {
      final totals = FinancialExportService.expenseCategoryTotals(_report());
      expect(totals['SUPPLIES'], 2400);
      expect(totals['FUEL'], 1500);
      expect(
        totals.values.fold<int>(0, (sum, value) => sum + value),
        _report().expensesTotalCents,
      );
    });
  });

  group('export safety wording', () {
    test('no export claims to be a tax return or an IRS form', () {
      final report = _report();
      final outputs = [
        FinancialExportService.buildEarningsCsv(report),
        FinancialExportService.buildExpensesCsv(report),
        FinancialExportService.buildReceiptIndexCsv(report),
      ];
      for (final output in outputs) {
        final lowered = output.toLowerCase();
        expect(lowered.contains('tax return'), isFalse);
        expect(lowered.contains('irs form'), isFalse);
        expect(lowered.contains('you owe'), isFalse);
        expect(lowered.contains('tax-free'), isFalse);
        expect(lowered.contains('1099'), isFalse);
      }
    });
  });
}
