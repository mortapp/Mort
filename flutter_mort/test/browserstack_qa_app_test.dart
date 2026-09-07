import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/financial_safety.dart';
import 'package:flutter_mort/data/models/onboarding_progress.dart';
import 'package:flutter_mort/features/qa/browserstack_qa_app.dart';
import 'package:flutter_mort/features/qa/browserstack_qa_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpQaApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const BrowserStackQaApp());
  await tester.pumpAndSettle();
}

Matcher get _rejectsQaMutation => throwsA(
  isA<StateError>().having(
    (error) => error.message,
    'message',
    browserStackQaMutationMessage,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'MORT',
      packageName: 'com.mortapp.mobile',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('QA home exposes stable navigation landmarks', (tester) async {
    await _pumpQaApp(tester);

    expect(find.bySemanticsLabel('qa-home-landmark'), findsOneWidget);
    expect(find.text('BrowserStack functional QA'), findsOneWidget);
    for (final identifier in const [
      'qa-open-onboarding',
      'qa-open-safety',
      'qa-open-financial',
      'qa-open-settings',
      'qa-open-permissions',
      'qa-open-legal',
    ]) {
      expect(find.bySemanticsLabel(identifier), findsOneWidget);
    }
  });

  testWidgets('financial route renders only deterministic zero-state data', (
    tester,
  ) async {
    await _pumpQaApp(tester);

    await tester.tap(find.bySemanticsLabel('qa-open-financial'));
    await tester.pumpAndSettle();

    expect(find.text('Financial Safety'), findsOneWidget);
    expect(
      find.text('Your financial record starts when you complete work.'),
      findsOneWidget,
    );
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('safety, legal, and settings routes mount real product screens', (
    tester,
  ) async {
    await _pumpQaApp(tester);

    await tester.tap(find.bySemanticsLabel('qa-open-safety'));
    await tester.pumpAndSettle();
    expect(find.text('MORT does not dispatch physical help'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('qa-open-legal'));
    await tester.pumpAndSettle();
    expect(find.text('Teen terms summary'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('qa-open-settings'));
    await tester.pumpAndSettle();
    expect(find.text('Control your account'), findsOneWidget);
  });

  test('financial fixture rejects every mounted-screen mutation', () async {
    final repository = BrowserStackQaFinancialRepository();
    final expense = ExpenseRecord(
      id: 'qa-expense',
      amountCents: 100,
      spentOn: DateTime(2026),
      category: 'SUPPLIES',
      merchant: '',
      description: '',
      jobId: null,
      receiptPath: null,
      notes: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await expectLater(
      repository.createExpense(
        amountCents: 100,
        spentOn: DateTime(2026),
        category: ExpenseCategory.supplies,
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.updateExpense(expense.id, amountCents: 200),
      _rejectsQaMutation,
    );
    await expectLater(repository.deleteExpense(expense.id), _rejectsQaMutation);
    await expectLater(
      repository.attachReceipt(
        XFile.fromData(Uint8List.fromList(const [1]), name: 'receipt.jpg'),
        expense.id,
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.removeReceipt(expense.id, 'qa/receipt.jpg'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.upsertTarget(year: 2026, amountCents: 100),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.setPreferences(alertsEnabled: false),
      _rejectsQaMutation,
    );
  });

  test(
    'safety fixture rejects every report, block, ping, and check-in mutation',
    () async {
      final repository = BrowserStackQaSafetyRepository();

      await expectLater(
        repository.createReport(reason: 'unsafe_job', details: 'QA details'),
        _rejectsQaMutation,
      );
      await expectLater(repository.blockUser('qa-user'), _rejectsQaMutation);
      await expectLater(repository.unblockUser('qa-user'), _rejectsQaMutation);
      await expectLater(repository.createSafetyPing(), _rejectsQaMutation);
      await expectLater(
        repository.scheduleActiveJobCheckin(
          applicationId: 'qa-application',
          minutesFromNow: 60,
        ),
        _rejectsQaMutation,
      );
      await expectLater(
        repository.completeActiveJobCheckin(checkinId: 'qa-checkin'),
        _rejectsQaMutation,
      );
    },
  );

  test('profile fixture advances only the account onboarding step', () async {
    final repository = BrowserStackQaProfileRepository();

    expect(
      (await repository.getOnboardingProgressV2()).activeStep,
      OnboardingStepV2.account,
    );
    expect(
      (await repository.saveOnboardingAccountV2(
        payload: const {},
        clientRequestId: 'qa-account-save',
      )).activeStep,
      OnboardingStepV2.workPreferences,
    );
    await expectLater(
      repository.saveOnboardingWorkV2(
        payload: const {},
        clientRequestId: 'qa-work-save',
      ),
      _rejectsQaMutation,
    );
  });
}
