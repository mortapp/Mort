import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_mort/data/models/financial_safety.dart';
import 'package:flutter_mort/data/repositories/financial_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/financial/financial_safety_center.dart';
import 'package:flutter_mort/features/financial/financial_section_screens.dart';
import 'package:image_picker/image_picker.dart';

class _FakeFinancialRepository extends FinancialRepository {
  _FakeFinancialRepository({
    this.summary = _emptySummary,
    this.evaluation = _emptyEvaluation,
    this.expenses = const [],
    this.rules = const [],
  });

  FinancialSummary summary;
  FinancialEvaluation evaluation;
  List<ExpenseRecord> expenses;
  List<FinancialRule> rules;
  FinancialPreferences preferences = const FinancialPreferences(
    alertsEnabled: true,
    benefitPrograms: [],
    guardianFinancialVisibility: false,
  );
  int createExpenseCalls = 0;
  int deleteExpenseCalls = 0;
  int attachReceiptCalls = 0;
  int removeReceiptCalls = 0;
  int setPreferencesCalls = 0;
  String? savedTargetYearAmount;

  @override
  Future<FinancialSummary> getFinancialSummary(int year) async => summary;

  @override
  Future<FinancialEvaluation> evaluateAlerts(int year) async => evaluation;

  @override
  Future<List<ExpenseRecord>> listExpenses(int year) async => expenses;

  @override
  Future<ExpenseRecord> createExpense({
    required int amountCents,
    required DateTime spentOn,
    required ExpenseCategory category,
    String merchant = '',
    String description = '',
    String? jobId,
    String notes = '',
  }) async {
    createExpenseCalls += 1;
    final record = ExpenseRecord(
      id: 'new-expense',
      amountCents: amountCents,
      spentOn: spentOn,
      category: category.wire,
      merchant: merchant,
      description: description,
      jobId: jobId,
      receiptPath: null,
      notes: notes,
      createdAt: DateTime(2027),
      updatedAt: DateTime(2027),
    );
    expenses = [...expenses, record];
    return record;
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    deleteExpenseCalls += 1;
    expenses = expenses.where((expense) => expense.id != expenseId).toList();
  }

  @override
  Future<String> attachReceipt(
    XFile file,
    String expenseId, {
    Uint8List? bytes,
  }) async {
    attachReceiptCalls += 1;
    return 'owner/$expenseId.jpg';
  }

  @override
  Future<void> removeReceipt(String expenseId, String path) async {
    removeReceiptCalls += 1;
  }

  @override
  Future<String?> signedReceiptUrl(String path) async => null;

  @override
  Future<FinancialPreferences> getPreferences() async => preferences;

  @override
  Future<FinancialPreferences> setPreferences({
    bool? alertsEnabled,
    List<String>? benefitPrograms,
    bool? guardianFinancialVisibility,
  }) async {
    setPreferencesCalls += 1;
    preferences = FinancialPreferences(
      alertsEnabled: alertsEnabled ?? preferences.alertsEnabled,
      benefitPrograms: benefitPrograms ?? preferences.benefitPrograms,
      guardianFinancialVisibility:
          guardianFinancialVisibility ??
          preferences.guardianFinancialVisibility,
    );
    return preferences;
  }

  @override
  Future<FinancialPersonalTarget> upsertTarget({
    required int year,
    required int amountCents,
    String label = 'Personal earning target',
  }) async {
    savedTargetYearAmount = '$year:$amountCents';
    return FinancialPersonalTarget(
      id: 't',
      year: year,
      amountCents: amountCents,
      label: label,
    );
  }

  @override
  Future<List<FinancialRule>> listRules({String? category}) async => rules;

  @override
  Future<FinancialYearReport> getYearReport(int year) async =>
      FinancialYearReport(
        year: year,
        earnings: const [],
        expenses: const [],
        disclaimer: financialExportDisclaimerText,
      );
}

const financialExportDisclaimerText =
    'For recordkeeping only. This report is not tax, legal, benefits, or '
    'financial advice.';

const _emptySummary = FinancialSummary(
  year: 2027,
  grossTrackedCents: 0,
  jobsCompleted: 0,
  methodBreakdown: [],
  expensesCents: 0,
  expenseCount: 0,
  receiptsCount: 0,
  personalTargets: [],
  disclaimer: 'Recordkeeping estimate — not a tax return or tax determination.',
);

const _emptyEvaluation = FinancialEvaluation(
  year: 2027,
  grossTrackedCents: 0,
  alerts: [],
  workStatus: 'unaffected',
  notice:
      'Financial checks are informational. They never block or limit your '
      'ability to keep working.',
);

ExpenseRecord _expense({bool withReceipt = false}) => ExpenseRecord(
  id: 'e1',
  amountCents: 2400,
  spentOn: DateTime(2027, 3, 13),
  category: 'SUPPLIES',
  merchant: 'Hardware store',
  description: 'Work bags',
  jobId: null,
  receiptPath: withReceipt ? 'owner/e1.jpg' : null,
  notes: '',
  createdAt: DateTime(2027),
  updatedAt: DateTime(2027),
);

FinancialSummary _summary({
  int gross = 0,
  int expensesCents = 0,
  int jobs = 0,
  int receipts = 0,
  List<Map<String, dynamic>> breakdown = const [],
}) {
  return FinancialSummary.fromJson({
    'ok': true,
    'year': 2027,
    'gross_tracked_cents': gross,
    'jobs_completed': jobs,
    'method_breakdown': breakdown,
    'expenses_cents': expensesCents,
    'expense_count': expensesCents == 0 ? 0 : 2,
    'receipts_count': receipts,
    'personal_targets': [],
    'disclaimer':
        'Recordkeeping estimate — not a tax return or tax determination.',
  });
}

FinancialEvaluation _evaluation(List<Map<String, dynamic>> alerts) {
  return FinancialEvaluation.fromJson({
    'ok': true,
    'year': 2027,
    'gross_tracked_cents': 600000,
    'alerts': alerts,
    'work_status': 'unaffected',
    'notice':
        'Financial checks are informational. They never block or limit your '
        'ability to keep working.',
  });
}

Widget _wrap(
  Widget child, {
  required _FakeFinancialRepository repository,
  Size size = const Size(412, 900),
  double textScale = 1.0,
}) {
  final router = GoRouter(
    initialLocation: '/financial',
    routes: [
      GoRoute(path: '/financial', builder: (_, _) => child),
      GoRoute(
        path: '/financial/expenses',
        builder: (_, _) => const FinancialExpensesScreen(),
      ),
      GoRoute(
        path: '/financial/check',
        builder: (_, _) => const FinancialCheckScreen(),
      ),
      GoRoute(
        path: '/financial/benefits',
        builder: (_, _) => const FinancialBenefitsScreen(),
      ),
      GoRoute(
        path: '/financial/targets',
        builder: (_, _) => const FinancialTargetsScreen(),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: ProviderContainer(
      overrides: [financialRepositoryProvider.overrideWithValue(repository)],
    ),
    child: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  test('financial surfaces stay monochrome and truthful', () {
    final source = [
      File(
        '${Directory.current.path}/lib/features/financial/financial_safety_center.dart',
      ),
      File(
        '${Directory.current.path}/lib/features/financial/financial_section_screens.dart',
      ),
      File(
        '${Directory.current.path}/lib/features/financial/financial_export_service.dart',
      ),
    ].map((file) => file.readAsStringSync()).join('\n');

    expect(source, isNot(contains('MortColors.neon')));
    expect(source, isNot(contains('MortColors.roseGold')));
    expect(source, contains('not tax'));
    expect(source, contains('not recommend a specific bank'));
  });

  testWidgets('empty year shows the real zero-state, never fake numbers', (
    tester,
  ) async {
    final repository = _FakeFinancialRepository(
      summary: _summary(),
      evaluation: _evaluation(const []),
    );
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(const FinancialSafetyCenterScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your financial record starts when you complete work.'),
      findsOneWidget,
    );
    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Learn how earnings tracking works'), findsOneWidget);
    expect(find.text('Add an expense'), findsOneWidget);
  });

  testWidgets('dashboard shows real values and the recordkeeping disclaimer', (
    tester,
  ) async {
    final repository = _FakeFinancialRepository(
      summary: _summary(
        gross: 684000,
        expensesCents: 131000,
        jobs: 37,
        receipts: 14,
        breakdown: [
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
        ],
      ),
      evaluation: _evaluation(const []),
    );
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(const FinancialSafetyCenterScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('\$6,840.00'), findsOneWidget);
    expect(find.text('\$5,530.00'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(
      find.text(
        'Recordkeeping estimate — not a tax return or tax determination.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Every compensation category counts toward the same tracked total. '
        'Changing payment method never resets earnings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('threshold reached shows reassurance and keeps work available', (
    tester,
  ) async {
    final repository = _FakeFinancialRepository(
      summary: _summary(gross: 600000, jobs: 20),
      evaluation: _evaluation([
        {
          'rule_key': 'irs_self_employment_net_earnings',
          'label': 'RULE MAY APPLY',
          'level': 'THRESHOLD_REACHED',
          'percent': 100,
          'basis': 'net',
          'threshold_cents': 400000,
          'source_url': 'https://www.irs.gov/test',
          'source_agency': 'IRS',
          'rule_version': '2026.1',
          'is_stale': false,
        },
      ]),
    );
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(const FinancialCheckScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('THRESHOLD REACHED'), findsOneWidget);
    expect(
      find.textContaining(
        'does not automatically mean you owe tax or lose benefits',
      ),
      findsOneWidget,
    );
    // Income Continuity Mode: continue earning stays available.
    final continueEarning = find.widgetWithText(
      ElevatedButton,
      'Continue earning',
    );
    expect(continueEarning, findsOneWidget);
    final button = tester.widget<ElevatedButton>(continueEarning);
    expect(button.onPressed, isNotNull);
    expect(find.textContaining('never block or limit'), findsWidgets);
  });

  testWidgets(
    'stale rules fail closed and never show the old threshold as fact',
    (tester) async {
      final repository = _FakeFinancialRepository(
        summary: _summary(gross: 600000, jobs: 20),
        evaluation: _evaluation([
          {
            'rule_key': 'snap_income_monitor_notice',
            'label': 'RULE MAY APPLY',
            'level': 'FINANCIAL_CHECK',
            'percent': 60,
            'basis': 'gross',
            'program': 'SNAP',
            'threshold_cents': 2000000,
            'source_url': 'https://www.fns.usda.gov/snap/recipient/eligibility',
            'source_agency': 'USDA FNS',
            'rule_version': '2025.9',
            'is_stale': true,
          },
        ]),
      );
      tester.view.physicalSize = const Size(412, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(const FinancialCheckScreen(), repository: repository),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rule needs review'), findsOneWidget);
      expect(
        find.textContaining("We can't verify the current rule right now."),
        findsOneWidget,
      );
      expect(find.textContaining('Review the official'), findsWidgets);
    },
  );

  testWidgets('benefits check keeps selections private with careful wording', (
    tester,
  ) async {
    final repository = _FakeFinancialRepository(
      rules: [
        FinancialRule.fromJson({
          'rule_key': 'snap_income_monitor_notice',
          'category': 'BENEFIT_PROGRAM',
          'program': 'SNAP',
          'jurisdiction': 'US',
          'federal_or_state': 'federal',
          'income_type': 'household_income',
          'gross_or_net_basis': 'gross',
          'threshold_cents': null,
          'effective_from': '2026-01-01',
          'last_reviewed_at': '2026-08-01T00:00:00Z',
          'source_url': 'https://www.fns.usda.gov/snap/recipient/eligibility',
          'source_agency': 'USDA FNS',
          'rule_version': '2026.1',
          'status': 'active',
          'notes': 'SNAP eligibility depends on household circumstances.',
          'is_stale': false,
        }),
      ],
    );
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(const FinancialBenefitsScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Optional.'), findsOneWidget);
    expect(find.textContaining('never shown to job posters'), findsOneWidget);
    expect(find.textContaining('never required'), findsOneWidget);
    expect(find.textContaining('MORT cannot determine'), findsWidgets);

    // Selecting SNAP and saving persists through the repository.
    await tester.tap(find.text('SNAP'));
    await tester.pump();
    await tester.tap(find.text('Save selections'));
    await tester.pumpAndSettle();
    expect(repository.setPreferencesCalls, 1);
    expect(repository.preferences.benefitPrograms, ['SNAP']);
    expect(find.textContaining('CHECK RECOMMENDED'), findsOneWidget);
    expect(find.textContaining('RULE MAY APPLY'), findsOneWidget);
  });

  testWidgets('expense ledger creates real records through the repository', (
    tester,
  ) async {
    final repository = _FakeFinancialRepository(
      summary: _summary(),
      evaluation: _evaluation(const []),
      expenses: const [],
    );
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(const FinancialExpensesScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('No recorded expenses'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Add an expense').first,
    );
    await tester.pumpAndSettle();

    // Invalid input is rejected.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (USD)'),
      '',
    );
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(repository.createExpenseCalls, 0);

    // Valid input saves.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (USD)'),
      '24.00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Merchant (optional)'),
      'Hardware store',
    );
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(repository.createExpenseCalls, 1);
    expect(find.text('Supplies'), findsOneWidget);
    expect(find.text('\$24.00'), findsOneWidget);
    expect(find.text('No receipt'), findsOneWidget);
  });

  testWidgets('expense detail attaches and removes private receipts', (
    tester,
  ) async {
    final repository = _FakeFinancialRepository(
      summary: _summary(),
      evaluation: _evaluation(const []),
      expenses: [_expense(withReceipt: true)],
    );
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(const FinancialExpensesScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supplies'));
    await tester.pumpAndSettle();

    expect(find.text('Recorded expense'), findsOneWidget);
    expect(
      find.text('Receipt (private — only you can see it)'),
      findsOneWidget,
    );
    expect(find.text('Replace receipt'), findsOneWidget);
    expect(find.text('Remove receipt'), findsOneWidget);
    expect(
      find.text('The receipt preview could not be loaded.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Remove receipt'));
    await tester.pumpAndSettle();
    expect(repository.removeReceiptCalls, 1);
  });

  testWidgets('no SSN collection anywhere in Financial Safety', (tester) async {
    final repository = _FakeFinancialRepository(
      summary: _summary(gross: 684000, jobs: 10),
      evaluation: _evaluation(const []),
    );
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        const Column(
          children: [
            Expanded(child: FinancialSafetyCenterScreen()),
            Expanded(child: FinancialExpensesScreen()),
            Expanded(child: FinancialBenefitsScreen()),
          ],
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    final allText = find
        .byType(Text)
        .evaluate()
        .map((element) {
          final widget = element.widget as Text;
          return widget.data ?? '';
        })
        .join(' ')
        .toLowerCase();
    expect(allText.contains('ssn'), isFalse);
    expect(allText.contains('social security number'), isFalse);
    expect(allText.contains('wallet'), isFalse);
    expect(allText.contains('cash out'), isFalse);
  });

  testWidgets('large text and narrow width stay renderable', (tester) async {
    final repository = _FakeFinancialRepository(
      summary: _summary(
        gross: 684000,
        expensesCents: 131000,
        jobs: 37,
        receipts: 14,
      ),
      evaluation: _evaluation([
        {
          'rule_key': 'irs_self_employment_net_earnings',
          'label': 'RULE MAY APPLY',
          'level': 'HEADS_UP',
          'percent': 75,
          'basis': 'net',
          'threshold_cents': 800000,
          'source_url': 'https://www.irs.gov/test',
          'source_agency': 'IRS',
          'rule_version': '2026.1',
          'is_stale': false,
        },
      ]),
    );
    tester.view.physicalSize = const Size(320, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        const FinancialSafetyCenterScreen(),
        repository: repository,
        size: const Size(320, 2400),
        textScale: 2.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('\$6,840.00'), findsWidgets);
    expect(find.textContaining('Heads up'), findsWidgets);
  });

  testWidgets('personal target saves through the repository', (tester) async {
    final repository = _FakeFinancialRepository(
      summary: _summary(gross: 200000, jobs: 4),
      evaluation: _evaluation(const []),
    );
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final year = DateTime.now().year;

    await tester.pumpWidget(
      _wrap(const FinancialTargetsScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('PERSONAL TARGET'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Target amount for $year (USD)'),
      '8000',
    );
    await tester.tap(find.text('Save target'));
    await tester.pumpAndSettle();
    expect(repository.savedTargetYearAmount, '$year:800000');
  });
}
