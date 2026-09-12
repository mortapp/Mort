import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/financial_math.dart';
import '../../data/models/financial_safety.dart';

/// Builds record exports (CSV + PDF) for MORT Earnings Safety.
///
/// Exports are records only: they never imitate official IRS forms and are
/// never labeled tax returns. Every export carries the recordkeeping
/// disclaimer.
class FinancialExportService {
  const FinancialExportService._();

  static const earningsDisclaimer =
      'For recordkeeping only. This report is not tax, legal, benefits, or '
      'financial advice.';

  static String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    final escaped = text.replaceAll('"', '""');
    return RegExp(r'[",\n\r]').hasMatch(escaped) ? '"$escaped"' : escaped;
  }

  static String _csvDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  /// Completed-jobs compensation report. Every compensation method that
  /// appears in the rows is included under the same total — the export never
  /// splits income into "counted" and "not counted" groups.
  static String buildEarningsCsv(FinancialYearReport report) {
    final buffer = StringBuffer()
      ..writeln('MORT Earnings Summary ${report.year}');
    buffer.writeln(earningsDisclaimer);
    buffer.writeln(
      [
        'Date completed',
        'Job',
        'Payment method',
        'Amount (USD)',
      ].map(_csvCell).join(','),
    );
    for (final row in report.earnings) {
      buffer.writeln(
        [
          _csvDate(row.completedOn),
          row.title,
          row.method,
          formatUsdCents(row.amountCents),
        ].map(_csvCell).join(','),
      );
    }
    buffer.writeln(
      [
        '',
        '',
        'Total',
        formatUsdCents(report.earningsTotalCents),
      ].map(_csvCell).join(','),
    );
    return buffer.toString();
  }

  /// Expense report. Expenses are recorded expenses / potential business
  /// expenses — never automatically labeled deductible.
  static String buildExpensesCsv(FinancialYearReport report) {
    final buffer = StringBuffer()
      ..writeln('MORT Expense Report ${report.year}');
    buffer.writeln(earningsDisclaimer);
    buffer.writeln(
      [
        'Date',
        'Category',
        'Merchant',
        'Description',
        'Amount (USD)',
        'Receipt',
      ].map(_csvCell).join(','),
    );
    for (final row in report.expenses) {
      buffer.writeln(
        [
          _csvDate(row.spentOn),
          row.category,
          row.merchant,
          row.description,
          formatUsdCents(row.amountCents),
          row.hasReceipt ? 'Yes' : 'No',
        ].map(_csvCell).join(','),
      );
    }
    buffer.writeln(
      [
        '',
        '',
        '',
        'Total',
        formatUsdCents(report.expensesTotalCents),
        '${report.receiptsCount} receipts',
      ].map(_csvCell).join(','),
    );
    return buffer.toString();
  }

  /// Compensation method totals (pure, testable). Every method found in the
  /// rows is included — nothing is excluded from the tracked total.
  static Map<String, int> methodTotals(FinancialYearReport report) {
    final totals = <String, int>{};
    for (final row in report.earnings) {
      final key = row.method.isEmpty ? 'other direct' : row.method;
      totals[key] = (totals[key] ?? 0) + row.amountCents;
    }
    return totals;
  }

  /// Expense category totals (pure, testable).
  static Map<String, int> expenseCategoryTotals(FinancialYearReport report) {
    final totals = <String, int>{};
    for (final row in report.expenses) {
      totals[row.category] = (totals[row.category] ?? 0) + row.amountCents;
    }
    return totals;
  }

  /// Receipt index: one line per expense receipt attached during the year.
  static String buildReceiptIndexCsv(FinancialYearReport report) {
    final buffer = StringBuffer()..writeln('MORT Receipt Index ${report.year}');
    buffer.writeln(earningsDisclaimer);
    buffer.writeln(
      ['Date', 'Category', 'Merchant', 'Amount (USD)'].map(_csvCell).join(','),
    );
    for (final row in report.expenses.where((row) => row.hasReceipt)) {
      buffer.writeln(
        [
          _csvDate(row.spentOn),
          row.category,
          row.merchant,
          formatUsdCents(row.amountCents),
        ].map(_csvCell).join(','),
      );
    }
    return buffer.toString();
  }

  /// Annual PDF earnings summary.
  static Future<List<int>> buildEarningsSummaryPdf(
    FinancialYearReport report,
  ) async {
    final document = pw.Document();
    final gross = report.earningsTotalCents;
    final expenses = report.expensesTotalCents;

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MORT Earnings Summary — ${report.year}',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Generated ${_csvDate(DateTime.now())}'),
              pw.SizedBox(height: 16),
              _pdfStat('Gross tracked compensation', gross),
              _pdfStat('Recorded expenses', expenses),
              _pdfStat('Estimated net earnings', gross - expenses),
              _pdfStat('Jobs completed', report.earnings.length),
              _pdfStat('Receipt count', report.receiptsCount),
              pw.SizedBox(height: 16),
              pw.Text(
                'Compensation method breakdown',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              ..._methodRows(report),
              pw.SizedBox(height: 12),
              pw.Text(
                'Expense categories',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              ..._expenseCategoryRows(report),
              pw.Spacer(),
              pw.Text(earningsDisclaimer),
            ],
          ),
        ),
      ),
    );
    return document.save();
  }

  static List<pw.Widget> _methodRows(FinancialYearReport report) {
    final totals = methodTotals(report);
    if (totals.isEmpty) {
      return [pw.Text('No completed jobs recorded for ${report.year}.')];
    }
    return [
      for (final entry in totals.entries)
        pw.Text('${entry.key}: ${formatUsdCents(entry.value)}'),
    ];
  }

  static List<pw.Widget> _expenseCategoryRows(FinancialYearReport report) {
    final totals = expenseCategoryTotals(report);
    if (totals.isEmpty) {
      return [pw.Text('No recorded expenses for ${report.year}.')];
    }
    return [
      for (final entry in totals.entries)
        pw.Text('${entry.key}: ${formatUsdCents(entry.value)}'),
    ];
  }

  static pw.Widget _pdfStat(String label, num value) {
    final text =
        value is int && label.toLowerCase().contains('jobs') ||
            (value is int && label.toLowerCase().contains('receipt'))
        ? '$value'
        : formatUsdCents(value.toInt());
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text('$label: $text'),
    );
  }

  /// Shares [contents] as a text file via the platform share sheet.
  static Future<void> shareTextFile(
    String contents, {
    required String fileName,
  }) async {
    final directory = await Directory.systemTemp.createTemp('mort_export');
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(contents, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], sharePositionOrigin: null),
    );
  }

  /// Shares [bytes] as a PDF via the platform share sheet.
  static Future<void> sharePdfBytes(
    List<int> bytes, {
    required String fileName,
  }) async {
    final directory = await Directory.systemTemp.createTemp('mort_export');
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], sharePositionOrigin: null),
    );
  }
}
