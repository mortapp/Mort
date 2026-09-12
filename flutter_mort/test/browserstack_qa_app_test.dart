import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/financial_safety.dart';
import 'package:flutter_mort/data/models/onboarding_progress.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/data/repositories/avatar_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/qa/browserstack_qa_app.dart';
import 'package:flutter_mort/features/qa/browserstack_qa_fixtures.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      'qa-open-teen',
      'qa-open-adult',
      'qa-open-guardian',
      'qa-open-admin',
    ]) {
      expect(find.bySemanticsLabel(identifier), findsOneWidget);
    }
  });

  for (final role in const ['teen', 'adult', 'guardian', 'admin']) {
    testWidgets('QA mounts the real $role role home', (tester) async {
      await _pumpQaApp(tester);

      final route = find.bySemanticsLabel('qa-open-$role');
      await tester.ensureVisible(route);
      await tester.tap(route);
      await tester.pumpAndSettle();

      expect(find.byType(RoleHomeScreen), findsOneWidget);
    });
  }

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
    expect(
      tester
          .widget<MortButton>(find.widgetWithText(MortButton, 'Call 911'))
          .onPressed,
      isNull,
    );

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

  testWidgets('QA permissions use local status and expose no native actions', (
    tester,
  ) async {
    await _pumpQaApp(tester);

    final route = find.bySemanticsLabel('qa-open-permissions');
    await tester.ensureVisible(route);
    await tester.tap(route);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Permission requests are disabled in BrowserStack QA. No device permission or setting can be changed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Request when needed'), findsNothing);
    expect(
      tester
          .widget<MortButton>(
            find.widgetWithText(MortButton, 'Open device settings'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('denied'), findsNWidgets(3));
    expect(
      find.text('denied; accuracy unavailable; services off'),
      findsOneWidget,
    );
  });

  testWidgets('QA onboarding disables native general-area lookup', (
    tester,
  ) async {
    await _pumpQaApp(tester);

    await tester.tap(find.bySemanticsLabel('qa-open-onboarding'));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    final teenBirthday =
        '${today.month.toString().padLeft(2, '0')}/'
        '${today.day.toString().padLeft(2, '0')}/${today.year - 16}';
    await tester.enterText(find.byType(TextFormField).first, teenBirthday);
    await tester.pumpAndSettle();

    final lookup = find.widgetWithText(
      MortButton,
      'Use my current general area',
    );
    await tester.ensureVisible(lookup);
    expect(tester.widget<MortButton>(lookup).onPressed, isNull);
    expect(
      find.text(
        'Current-location lookup is disabled in BrowserStack QA. Enter a ZIP or city manually.',
      ),
      findsOneWidget,
    );
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
    await expectLater(repository.chooseReceiptPhoto(), _rejectsQaMutation);
    await expectLater(repository.deleteTarget(2026), _rejectsQaMutation);
    await expectLater(
      repository.recordUploadFailure(uploadKind: 'qa', safeCode: 'qa_blocked'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.recordOperationalFailure(
        eventType: 'qa',
        safeCode: 'qa_blocked',
      ),
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
      await expectLater(
        repository.recordUploadFailure(
          uploadKind: 'qa',
          safeCode: 'qa_blocked',
        ),
        _rejectsQaMutation,
      );
      await expectLater(
        repository.recordOperationalFailure(
          eventType: 'qa',
          safeCode: 'qa_blocked',
        ),
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

  test('profile fixture rejects inherited Supabase-backed mutations', () async {
    final repository = BrowserStackQaProfileRepository();

    await expectLater(
      repository.saveProfile(
        role: UserRole.teen,
        displayName: 'QA',
        dob: DateTime(2010),
      ),
      _rejectsQaMutation,
    );
    await expectLater(repository.completeOnboarding(), _rejectsQaMutation);
    await expectLater(
      repository.saveOnboardingAge(DateTime(2010)),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.requestUsernameChange('qa_user'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.saveOnboardingRole(UserRole.teen),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.saveOnboardingProgress(completedStep: 'account'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.recordOnboardingAcknowledgement(
        version: 'qa',
        platform: 'qa',
        appVersion: 'qa',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.saveProfileDetails(
        displayName: 'QA',
        bio: '',
        availability: '',
        preferredJobCategories: const [],
        approximateArea: '',
        goals: '',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.saveProfileSetup(
        role: UserRole.teen,
        displayName: 'QA',
        username: 'qa_user',
        dob: DateTime(2010),
        city: '',
        state: '',
        locationSetupMode: 'location_deferred',
        bio: '',
        availability: '',
        preferredJobCategories: const [],
        approximateArea: 'Indianapolis',
        goals: '',
        adultAccountType: '',
        businessName: '',
        editExisting: false,
        clientRequestId: 'qa-profile-setup',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.saveTransportationPreferences(methods: const ['walking']),
      _rejectsQaMutation,
    );
    await expectLater(repository.setAvatarPath(null), _rejectsQaMutation);
    await expectLater(
      repository.updateMyProfile(const {'display_name': 'QA'}),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.saveOnboardingSafetyV2(
        payload: const {},
        clientRequestId: 'qa-safety-save',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.completeOnboardingV2(
        payload: const {},
        clientRequestId: 'qa-complete',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.recordUploadFailure(uploadKind: 'qa', safeCode: 'qa_blocked'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.recordOperationalFailure(
        eventType: 'qa',
        safeCode: 'qa_blocked',
      ),
      _rejectsQaMutation,
    );
  });

  test('legal fixture rejects inherited contract mutations', () async {
    final repository = BrowserStackQaLegalContractRepository();

    await expectLater(
      repository.confirmContractVersion(
        versionId: 'qa-version',
        confirmation: 'agree',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.requestContractChange(
        contractId: 'qa-contract',
        patch: const {},
        reason: 'qa',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.respondContractChange(changeId: 'qa-change', accept: true),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.reportNonpayment(
        obligationId: 'qa-obligation',
        statement: 'qa',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.submitDisputeStatement(
        disputeId: 'qa-dispute',
        statement: 'qa',
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.submitDisputeAppeal(disputeId: 'qa-dispute', reason: 'qa'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.evidenceExport('qa-dispute'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.acceptLegalVersion(
        versionId: 'qa-version',
        teenSummaryViewed: true,
      ),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.recordUploadFailure(uploadKind: 'qa', safeCode: 'qa_blocked'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.recordOperationalFailure(
        eventType: 'qa',
        safeCode: 'qa_blocked',
      ),
      _rejectsQaMutation,
    );
  });

  test(
    'QA native service rejects every mutation without platform calls',
    () async {
      const service = BrowserStackQaNativePermissionsService();

      await expectLater(service.requestCamera(), _rejectsQaMutation);
      await expectLater(service.requestPhotos(), _rejectsQaMutation);
      await expectLater(
        service.requestForegroundLocation(),
        _rejectsQaMutation,
      );
      await expectLater(
        service.resolveCurrentGeneralArea(),
        _rejectsQaMutation,
      );
      await expectLater(service.openSettings(), _rejectsQaMutation);
    },
  );

  test('avatar fixture rejects gallery, camera, upload, and removal without '
      'reaching ImagePicker or Supabase Storage', () async {
    final repository = BrowserStackQaAvatarRepository();
    final file = XFile.fromData(
      Uint8List.fromList(const [1]),
      name: 'avatar.jpg',
    );

    await expectLater(
      repository.choosePhoto(),
      _rejectsQaMutation,
      reason: 'gallery selection must never reach ImagePicker',
    );
    await expectLater(
      repository.choosePhoto(source: ImageSource.camera),
      _rejectsQaMutation,
      reason: 'camera capture must never reach ImagePicker',
    );
    await expectLater(repository.prepareAvatar(file), _rejectsQaMutation);
    await expectLater(
      repository.uploadAvatar(file),
      _rejectsQaMutation,
      reason: 'must never reach ImagePicker or Supabase Storage',
    );
    await expectLater(
      repository.uploadPreparedAvatar(Uint8List.fromList(const [1])),
      _rejectsQaMutation,
      reason: 'must never reach Supabase Storage',
    );
    await expectLater(
      repository.removeAvatar('qa/avatar.jpg'),
      _rejectsQaMutation,
    );
    expect(
      await repository.signedAvatarUrl(
        profileId: 'qa-profile',
        avatarPath: 'qa/avatar.jpg',
      ),
      isNull,
      reason: 'must never call the hosted avatar-url function',
    );
    await expectLater(
      repository.recordUploadFailure(uploadKind: 'qa', safeCode: 'qa'),
      _rejectsQaMutation,
    );
    await expectLater(
      repository.recordOperationalFailure(eventType: 'qa', safeCode: 'qa'),
      _rejectsQaMutation,
    );
  });

  test(
    'production avatar repository is unaffected by BrowserStack QA overrides',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repository = container.read(avatarRepositoryProvider);

      expect(repository, isA<AvatarRepository>());
      expect(repository, isNot(isA<BrowserStackQaAvatarRepository>()));
    },
  );

  testWidgets(
    'post-save onboarding back-navigation renders the real avatar editor '
    'but blocks every ImagePicker, camera, and upload path',
    (tester) async {
      await _pumpQaApp(tester);

      await tester.tap(find.bySemanticsLabel('qa-open-onboarding'));
      await tester.pumpAndSettle();

      final today = DateTime.now();
      final teenBirthday =
          '${today.month.toString().padLeft(2, '0')}/'
          '${today.day.toString().padLeft(2, '0')}/${today.year - 16}';
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), teenBirthday);
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(1), 'QA Tester');
      await tester.enterText(fields.at(2), 'qa_tester');
      await tester.enterText(fields.at(3), '46204');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(MortButton, 'Save account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MortButton, 'Save account').last);
      await tester.pumpAndSettle();

      // Saving advances past the account step -- back-navigate to reach the
      // exact post-save path the reviewer found real avatar controls on.
      await tester.tap(find.widgetWithText(MortButton, 'Back'));
      await tester.pumpAndSettle();

      expect(find.text('Profile photo (optional)'), findsOneWidget);
      final choosePhoto = find.widgetWithText(MortButton, 'Choose photo');
      expect(
        choosePhoto,
        findsOneWidget,
        reason: 'the real production avatar editor must still be mounted',
      );

      await tester.ensureVisible(choosePhoto);
      await tester.tap(choosePhoto);
      await tester.pumpAndSettle();

      // No uncaught exception (an unblocked ImagePicker call would surface
      // as a MissingPluginException in this test harness) and the widget's
      // own generic failure toast, not a native picker sheet.
      expect(tester.takeException(), isNull);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    },
  );
}
