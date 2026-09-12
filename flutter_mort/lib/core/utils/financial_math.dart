/// Pure financial-safety calculations for MORT Earnings Safety.
///
/// Everything here is calendar-year based and presentation-side only: the
/// authoritative totals always come from the server RPCs. These helpers exist
/// so the UI can derive secondary values (net estimate, alert level, check
/// status) without duplicating server rules and without any hidden
/// "income that is not counted".
library;

/// Alert levels, in ascending severity. Reaching any level is informational
/// only and must never gate work, applications, messaging, or any other
/// marketplace surface.
const financialAlertLevels = <String>[
  'HEADS_UP',
  'FINANCIAL_CHECK',
  'REVIEW_RECOMMENDED',
  'THRESHOLD_REACHED',
];

/// Maps a percent-of-threshold value to its alert level.
///
/// 70 -> HEADS_UP, 85 -> FINANCIAL_CHECK, 95 -> REVIEW_RECOMMENDED,
/// 100+ -> THRESHOLD_REACHED. Below 70 there is no alert (null).
String? alertLevelForPercent(int percent) {
  if (percent >= 100) return 'THRESHOLD_REACHED';
  if (percent >= 95) return 'REVIEW_RECOMMENDED';
  if (percent >= 85) return 'FINANCIAL_CHECK';
  if (percent >= 70) return 'HEADS_UP';
  return null;
}

/// Severity rank used to pick the single most important alert for the
/// compact dashboard card.
int alertSeverityRank(String level) {
  final index = financialAlertLevels.indexOf(level);
  return index < 0 ? -1 : index;
}

/// Short, non-alarming status label for the dashboard card. The wording never
/// implies a block, a debt, or a benefit loss.
String financialCheckLabel(List<String> levels) {
  var highest = '';
  for (final level in levels) {
    if (alertSeverityRank(level) > alertSeverityRank(highest)) {
      highest = level;
    }
  }
  return switch (highest) {
    'THRESHOLD_REACHED' => 'Threshold reached',
    'REVIEW_RECOMMENDED' => 'Review recommended',
    'FINANCIAL_CHECK' => 'Financial check',
    'HEADS_UP' => 'Heads up',
    _ => 'Good',
  };
}

/// Estimated net = gross tracked compensation minus recorded expenses.
///
/// Every compensation category (cash, external electronic, processed,
/// gift-card, other noncash) is included in gross before this subtraction.
int estimatedNetCents({required int grossCents, required int expensesCents}) {
  return grossCents - expensesCents;
}

/// Calendar-year bounds for [year], inclusive. Used for year rollover:
/// every tracked record must fall inside [DateTime(year, 1, 1), DateTime(year, 12, 31)].
(DateTime start, DateTime end) calendarYearBounds(int year) {
  return (DateTime(year, 1, 1), DateTime(year, 12, 31, 23, 59, 59));
}

/// True when [date] falls inside the calendar year [year].
bool isWithinCalendarYear(DateTime date, int year) {
  final (start, end) = calendarYearBounds(year);
  final utc = date.toUtc();
  return !utc.isBefore(start.toUtc()) && !utc.isAfter(end.toUtc());
}

/// Progress toward a target, clamped to 0..1 for the progress bar. The raw
/// percent is available via [percentOfThreshold] when the UI needs the exact
/// number.
double targetProgress({required int amountCents, required int targetCents}) {
  if (targetCents <= 0) return 0;
  return (amountCents / targetCents).clamp(0.0, 1.0);
}

/// Percent of a threshold, capped at 200 like the server evaluation.
int percentOfThreshold({
  required int amountCents,
  required int thresholdCents,
}) {
  if (thresholdCents <= 0) return 0;
  return ((amountCents / thresholdCents) * 100).round().clamp(0, 200);
}

/// Formats integer cents as a plain USD string like `$6,840.00`.
/// Negative amounts render as `-$1,310.00`.
String formatUsdCents(int cents) {
  final negative = cents < 0;
  final magnitude = negative ? -cents : cents;
  final dollars = magnitude ~/ 100;
  final remainder = magnitude % 100;
  final dollarsText = dollars.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match.group(1)},',
  );
  final remainderText = remainder.toString().padLeft(2, '0');
  return '${negative ? '-' : ''}\$$dollarsText.$remainderText';
}
