/// MORT Earnings Safety models.
///
/// These mirror the server RPCs in the `20260831120000_mort_earnings_safety_v1`
/// migration. MORT never performs tax or benefits determinations: the models
/// here carry recordkeeping data and informational rule references only.
///
/// Safety invariants encoded in these models:
///   * Every compensation category counts toward tracked gross compensation.
///     Changing payment method never resets or re-baselines totals.
///   * There is no SSN, tax-identity, or wallet/balance field anywhere.
///   * Benefit program selections are stored only in [FinancialPreferences]
///     and are never part of guardian-visible output.
library;

/// Expense ledger categories. These are recordkeeping labels only — MORT does
/// not decide whether an expense is deductible.
enum ExpenseCategory {
  supplies('SUPPLIES', 'Supplies'),
  fuel('FUEL', 'Fuel'),
  tools('TOOLS', 'Tools'),
  equipment('EQUIPMENT', 'Equipment'),
  maintenance('MAINTENANCE', 'Maintenance'),
  transportation('TRANSPORTATION', 'Transportation'),
  phoneOrService('PHONE_OR_SERVICE', 'Phone or service'),
  other('OTHER', 'Other');

  const ExpenseCategory(this.wire, this.label);

  /// Value stored in `expense_records.category`.
  final String wire;

  /// Human label used in the UI and exports.
  final String label;

  static ExpenseCategory fromWire(String wire) => values.firstWhere(
    (value) => value.wire == wire,
    orElse: () => ExpenseCategory.other,
  );

  static bool isValidWire(String wire) =>
      values.any((value) => value.wire == wire);
}

/// Compensation categories MORT currently tracks from completed jobs.
///
/// Only categories supported by real product behavior are exposed. Direct
/// payment (cash, external electronic) remains fully supported; MORT does not
/// claim to have processed or verified money it did not process. If future
/// categories appear (processed payouts, gift cards, other noncash), they are
/// added server-side and all of them count toward the same tracked gross —
/// never as a reporting workaround.
enum CompensationCategory {
  directCash('DIRECT_CASH', 'Direct cash'),
  directElectronic('DIRECT_ELECTRONIC', 'External electronic'),
  unknownDirect('UNKNOWN_DIRECT', 'Other direct');

  const CompensationCategory(this.wire, this.label);

  final String wire;
  final String label;

  static CompensationCategory fromWire(String wire) => values.firstWhere(
    (value) => value.wire == wire,
    orElse: () => CompensationCategory.unknownDirect,
  );
}

/// Per-payment-method earnings split. Informational only: the method split
/// never resets, re-baselines, or subtracts from the single tracked gross.
class FinancialMethodBreakdown {
  const FinancialMethodBreakdown({
    required this.method,
    required this.category,
    required this.amountCents,
    required this.count,
  });

  final String method;
  final String category;
  final int amountCents;
  final int count;

  factory FinancialMethodBreakdown.fromJson(Map<String, dynamic> json) =>
      FinancialMethodBreakdown(
        method: json['method']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
        count: (json['count'] as num?)?.toInt() ?? 0,
      );

  CompensationCategory get compensationCategory =>
      CompensationCategory.fromWire(category);
}

/// Voluntary personal earning target. Always labeled a personal target —
/// never an IRS, government, or benefits threshold.
class FinancialPersonalTarget {
  const FinancialPersonalTarget({
    required this.id,
    required this.year,
    required this.amountCents,
    required this.label,
  });

  final String id;
  final int year;
  final int amountCents;
  final String label;

  factory FinancialPersonalTarget.fromJson(Map<String, dynamic> json) =>
      FinancialPersonalTarget(
        id: json['id']?.toString() ?? '',
        year: (json['year'] as num?)?.toInt() ?? 0,
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
        label: json['label']?.toString() ?? 'Personal earning target',
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'year': year,
    'amount_cents': amountCents,
    'label': label,
  };
}

/// Year-to-date tracked compensation summary for one calendar year.
class FinancialSummary {
  const FinancialSummary({
    required this.year,
    required this.grossTrackedCents,
    required this.jobsCompleted,
    required this.methodBreakdown,
    required this.expensesCents,
    required this.expenseCount,
    required this.receiptsCount,
    required this.personalTargets,
    required this.disclaimer,
  });

  final int year;
  final int grossTrackedCents;
  final int jobsCompleted;
  final List<FinancialMethodBreakdown> methodBreakdown;
  final int expensesCents;
  final int expenseCount;
  final int receiptsCount;
  final List<FinancialPersonalTarget> personalTargets;
  final String disclaimer;

  int get estimatedNetCents =>
      estimatedNet(gross: grossTrackedCents, expenses: expensesCents);

  static int estimatedNet({required int gross, required int expenses}) =>
      gross - expenses;

  bool get isEmpty =>
      grossTrackedCents == 0 && expensesCents == 0 && jobsCompleted == 0;

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = json['method_breakdown'];
    final targets = json['personal_targets'];
    return FinancialSummary(
      year: (json['year'] as num?)?.toInt() ?? 0,
      grossTrackedCents: (json['gross_tracked_cents'] as num?)?.toInt() ?? 0,
      jobsCompleted: (json['jobs_completed'] as num?)?.toInt() ?? 0,
      methodBreakdown: breakdown is List
          ? breakdown
                .whereType<Map>()
                .map(
                  (item) => FinancialMethodBreakdown.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      expensesCents: (json['expenses_cents'] as num?)?.toInt() ?? 0,
      expenseCount: (json['expense_count'] as num?)?.toInt() ?? 0,
      receiptsCount: (json['receipts_count'] as num?)?.toInt() ?? 0,
      personalTargets: targets is List
          ? targets
                .whereType<Map>()
                .map(
                  (item) => FinancialPersonalTarget.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      disclaimer:
          json['disclaimer']?.toString() ??
          'Recordkeeping estimate — not a tax return or tax determination.',
    );
  }
}

/// One recorded expense. Stored as a "recorded expense" / "potential business
/// expense" — never automatically labeled deductible.
class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.amountCents,
    required this.spentOn,
    required this.category,
    required this.merchant,
    required this.description,
    required this.jobId,
    required this.receiptPath,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int amountCents;
  final DateTime spentOn;
  final String category;
  final String merchant;
  final String description;
  final String? jobId;
  final String? receiptPath;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseCategory get expenseCategory => ExpenseCategory.fromWire(category);
  bool get hasReceipt => receiptPath != null && receiptPath!.isNotEmpty;

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
    id: json['id']?.toString() ?? '',
    amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
    spentOn:
        DateTime.tryParse(json['spent_on']?.toString() ?? '') ?? DateTime.now(),
    category: json['category']?.toString() ?? 'OTHER',
    merchant: json['merchant']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    jobId: json['job_id']?.toString(),
    receiptPath: json['receipt_path']?.toString(),
    notes: json['notes']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
        DateTime.now(),
  );
}

/// Financial preferences. Benefit program selections are sensitive and are
/// never exposed to posters, businesses, other teens, or ranking.
class FinancialPreferences {
  const FinancialPreferences({
    required this.alertsEnabled,
    required this.benefitPrograms,
    required this.guardianFinancialVisibility,
  });

  final bool alertsEnabled;

  /// Programs the family optionally asked MORT to help monitor. Empty by
  /// default; participation is never required to use MORT.
  final List<String> benefitPrograms;

  /// Teen opt-in gate for guardian financial visibility. Guardians additionally
  /// need an active guardian connection server-side.
  final bool guardianFinancialVisibility;

  static const benefitProgramChoices = <String, String>{
    'SNAP': 'SNAP',
    'MEDICAID': 'Medicaid',
    'CHIP': 'CHIP',
    'TANF': 'TANF',
    'SSI': 'SSI',
    'HOUSING_ASSISTANCE': 'Housing assistance',
  };

  factory FinancialPreferences.fromJson(Map<String, dynamic> json) {
    final programs = json['benefit_programs'];
    return FinancialPreferences(
      alertsEnabled: json['alerts_enabled'] is bool
          ? json['alerts_enabled'] as bool
          : true,
      benefitPrograms: programs is List
          ? programs.map((item) => item.toString()).toList(growable: false)
          : const [],
      guardianFinancialVisibility: json['guardian_financial_visibility'] is bool
          ? json['guardian_financial_visibility'] as bool
          : false,
    );
  }
}

/// A versioned financial rule served by the rule engine. MORT displays these
/// as references to official sources; it never turns them into individualized
/// determinations.
class FinancialRule {
  const FinancialRule({
    required this.ruleKey,
    required this.category,
    required this.program,
    required this.jurisdiction,
    required this.federalOrState,
    required this.incomeType,
    required this.grossOrNetBasis,
    required this.thresholdCents,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.lastReviewedAt,
    required this.sourceUrl,
    required this.sourceAgency,
    required this.ruleVersion,
    required this.status,
    required this.notes,
    required this.isStale,
  });

  final String ruleKey;
  final String category;
  final String program;
  final String jurisdiction;
  final String federalOrState;
  final String? incomeType;
  final String? grossOrNetBasis;
  final int? thresholdCents;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime lastReviewedAt;
  final String sourceUrl;
  final String sourceAgency;
  final String ruleVersion;
  final String status;
  final String notes;
  final bool isStale;

  String get displayLabel => switch (category) {
    'SELF_EMPLOYMENT' => 'Self-employment earnings reference',
    'TAX_INFORMATION_REPORTING' => 'Tax information reporting reference',
    'BENEFIT_PROGRAM' => 'Program information',
    'PERSONAL_TARGET' => 'Personal target',
    _ => 'Recordkeeping guidance',
  };

  factory FinancialRule.fromJson(Map<String, dynamic> json) => FinancialRule(
    ruleKey: json['rule_key']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    program: json['program']?.toString() ?? '',
    jurisdiction: json['jurisdiction']?.toString() ?? 'US',
    federalOrState: json['federal_or_state']?.toString() ?? 'federal',
    incomeType: json['income_type']?.toString(),
    grossOrNetBasis: json['gross_or_net_basis']?.toString(),
    thresholdCents: (json['threshold_cents'] as num?)?.toInt(),
    effectiveFrom:
        DateTime.tryParse(json['effective_from']?.toString() ?? '') ??
        DateTime.now(),
    effectiveTo: json['effective_to'] == null
        ? null
        : DateTime.tryParse(json['effective_to'].toString()),
    lastReviewedAt:
        DateTime.tryParse(json['last_reviewed_at']?.toString() ?? '') ??
        DateTime.now(),
    sourceUrl: json['source_url']?.toString() ?? '',
    sourceAgency: json['source_agency']?.toString() ?? '',
    ruleVersion: json['rule_version']?.toString() ?? '',
    status: json['status']?.toString() ?? 'active',
    notes: json['notes']?.toString() ?? '',
    isStale: json['is_stale'] == true,
  );
}

/// One activated financial check. Informational only — never a work block.
class FinancialAlert {
  const FinancialAlert({
    required this.ruleKey,
    required this.label,
    required this.level,
    required this.percent,
    required this.basis,
    required this.program,
    required this.thresholdCents,
    required this.sourceUrl,
    required this.sourceAgency,
    required this.ruleVersion,
    required this.isStale,
  });

  final String ruleKey;
  final String label;
  final String level;
  final int percent;
  final String basis;
  final String? program;
  final int? thresholdCents;
  final String? sourceUrl;
  final String? sourceAgency;
  final String? ruleVersion;
  final bool isStale;

  factory FinancialAlert.fromJson(Map<String, dynamic> json) => FinancialAlert(
    ruleKey: json['rule_key']?.toString() ?? '',
    label: json['label']?.toString() ?? 'RULE MAY APPLY',
    level: json['level']?.toString() ?? 'HEADS_UP',
    percent: (json['percent'] as num?)?.toInt() ?? 0,
    basis: json['basis']?.toString() ?? 'gross',
    program: json['program']?.toString(),
    thresholdCents: (json['threshold_cents'] as num?)?.toInt(),
    sourceUrl: json['source_url']?.toString(),
    sourceAgency: json['source_agency']?.toString(),
    ruleVersion: json['rule_version']?.toString(),
    isStale: json['is_stale'] == true,
  );
}

/// Result of the server Financial Check evaluation. `workStatus` is always
/// 'unaffected': reaching a threshold never blocks or limits work.
class FinancialEvaluation {
  const FinancialEvaluation({
    required this.year,
    required this.grossTrackedCents,
    required this.alerts,
    required this.workStatus,
    required this.notice,
  });

  final int year;
  final int grossTrackedCents;
  final List<FinancialAlert> alerts;
  final String workStatus;
  final String notice;

  factory FinancialEvaluation.fromJson(Map<String, dynamic> json) {
    final alerts = json['alerts'];
    return FinancialEvaluation(
      year: (json['year'] as num?)?.toInt() ?? 0,
      grossTrackedCents: (json['gross_tracked_cents'] as num?)?.toInt() ?? 0,
      alerts: alerts is List
          ? alerts
                .whereType<Map>()
                .map(
                  (item) =>
                      FinancialAlert.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      workStatus: json['work_status']?.toString() ?? 'unaffected',
      notice:
          json['notice']?.toString() ??
          'Financial checks are informational. '
              'They never block or limit your ability to keep working.',
    );
  }
}

/// One completed-job earnings row used in exports.
class FinancialEarningsRow {
  const FinancialEarningsRow({
    required this.title,
    required this.completedOn,
    required this.method,
    required this.amountCents,
  });

  final String title;
  final DateTime completedOn;
  final String method;
  final int amountCents;

  factory FinancialEarningsRow.fromJson(Map<String, dynamic> json) =>
      FinancialEarningsRow(
        title: json['title']?.toString() ?? 'Completed job',
        completedOn:
            DateTime.tryParse(json['completed_on']?.toString() ?? '') ??
            DateTime.now(),
        method: json['method']?.toString() ?? '',
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      );
}

/// One expense row used in exports.
class FinancialExpenseRow {
  const FinancialExpenseRow({
    required this.spentOn,
    required this.category,
    required this.merchant,
    required this.description,
    required this.amountCents,
    required this.hasReceipt,
  });

  final DateTime spentOn;
  final String category;
  final String merchant;
  final String description;
  final int amountCents;
  final bool hasReceipt;

  factory FinancialExpenseRow.fromJson(Map<String, dynamic> json) =>
      FinancialExpenseRow(
        spentOn:
            DateTime.tryParse(json['spent_on']?.toString() ?? '') ??
            DateTime.now(),
        category: json['category']?.toString() ?? 'OTHER',
        merchant: json['merchant']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
        hasReceipt: json['has_receipt'] == true,
      );
}

/// Annual record report used to build CSV and PDF exports.
class FinancialYearReport {
  const FinancialYearReport({
    required this.year,
    required this.earnings,
    required this.expenses,
    required this.disclaimer,
  });

  final int year;
  final List<FinancialEarningsRow> earnings;
  final List<FinancialExpenseRow> expenses;
  final String disclaimer;

  int get earningsTotalCents =>
      earnings.fold(0, (total, row) => total + row.amountCents);
  int get expensesTotalCents =>
      expenses.fold(0, (total, row) => total + row.amountCents);
  int get receiptsCount => expenses.where((row) => row.hasReceipt).length;
  int get estimatedNetCents => earningsTotalCents - expensesTotalCents;

  factory FinancialYearReport.fromJson(Map<String, dynamic> json) {
    final earnings = json['earnings'];
    final expenses = json['expenses'];
    return FinancialYearReport(
      year: (json['year'] as num?)?.toInt() ?? 0,
      earnings: earnings is List
          ? earnings
                .whereType<Map>()
                .map(
                  (item) => FinancialEarningsRow.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      expenses: expenses is List
          ? expenses
                .whereType<Map>()
                .map(
                  (item) => FinancialExpenseRow.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      disclaimer:
          json['disclaimer']?.toString() ??
          'For recordkeeping only. This report is not tax, legal, benefits, '
              'or financial advice.',
    );
  }
}
