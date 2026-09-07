import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/financial_safety.dart';
import '../../data/models/onboarding_progress.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/financial_repository.dart';
import '../../data/repositories/legal_contract_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/safety_repository.dart';

const browserStackQaMutationMessage =
    'BrowserStack QA mode does not permit mutations.';

Never _mutate() => throw StateError(browserStackQaMutationMessage);

class BrowserStackQaFinancialRepository extends FinancialRepository {
  @override
  Future<FinancialSummary> getFinancialSummary(int year) async =>
      FinancialSummary(
        year: year,
        grossTrackedCents: 0,
        jobsCompleted: 0,
        methodBreakdown: const [],
        expensesCents: 0,
        expenseCount: 0,
        receiptsCount: 0,
        personalTargets: const [],
        disclaimer:
            'Recordkeeping estimate — not a tax return or tax determination.',
      );

  @override
  Future<FinancialEvaluation> evaluateAlerts(int year) async =>
      FinancialEvaluation(
        year: year,
        grossTrackedCents: 0,
        alerts: const [],
        workStatus: 'unaffected',
        notice:
            'Financial checks are informational. They never block or limit '
            'your ability to keep working.',
      );

  @override
  Future<List<ExpenseRecord>> listExpenses(int year) async => const [];

  @override
  Future<List<FinancialRule>> listRules({String? category}) async => const [];

  @override
  Future<FinancialPreferences> getPreferences() async =>
      const FinancialPreferences(
        alertsEnabled: true,
        benefitPrograms: [],
        guardianFinancialVisibility: false,
      );

  @override
  Future<String?> signedReceiptUrl(String path) async => null;

  @override
  Future<FinancialYearReport> getYearReport(int year) async =>
      FinancialYearReport(
        year: year,
        earnings: const [],
        expenses: const [],
        disclaimer:
            'For recordkeeping only. This report is not tax, legal, benefits, '
            'or financial advice.',
      );

  @override
  Future<ExpenseRecord> createExpense({
    required int amountCents,
    required DateTime spentOn,
    required ExpenseCategory category,
    String merchant = '',
    String description = '',
    String? jobId,
    String notes = '',
  }) async => _mutate();

  @override
  Future<ExpenseRecord> updateExpense(
    String expenseId, {
    int? amountCents,
    DateTime? spentOn,
    ExpenseCategory? category,
    String? merchant,
    String? description,
    String? jobId,
    bool clearJob = false,
    String? notes,
  }) async => _mutate();

  @override
  Future<void> deleteExpense(String expenseId) async => _mutate();

  @override
  Future<XFile?> chooseReceiptPhoto({
    ImageSource source = ImageSource.gallery,
  }) async => _mutate();

  @override
  Future<String> attachReceipt(
    XFile file,
    String expenseId, {
    Uint8List? bytes,
  }) async => _mutate();

  @override
  Future<void> removeReceipt(String expenseId, String path) async => _mutate();

  @override
  Future<FinancialPreferences> setPreferences({
    bool? alertsEnabled,
    List<String>? benefitPrograms,
    bool? guardianFinancialVisibility,
  }) async => _mutate();

  @override
  Future<FinancialPersonalTarget> upsertTarget({
    required int year,
    required int amountCents,
    String label = 'Personal earning target',
  }) async => _mutate();

  @override
  Future<void> deleteTarget(int year) async => _mutate();
}

class BrowserStackQaProfileRepository extends ProfileRepository {
  static final DateTime _revision = DateTime.utc(2026, 9, 7, 12);

  OnboardingProgressV2 _progress = _progressFor(OnboardingStepV2.account);
  Profile? _profile;

  Profile? get profile => _profile;

  static OnboardingProgressV2 _progressFor(OnboardingStepV2 activeStep) =>
      OnboardingProgressV2(
        completed: false,
        activeStep: activeStep,
        primarySteps: OnboardingProgressV2.contractSteps,
        completedSteps: activeStep == OnboardingStepV2.account
            ? const []
            : const [OnboardingStepV2.account],
        missingRequirements: activeStep == OnboardingStepV2.account
            ? const ['account']
            : const ['work_preferences'],
        role: UserRole.teen,
        revision: _revision,
      );

  @override
  Future<Profile?> getCurrentProfile() async => _profile;

  @override
  Future<OnboardingProgress> getOnboardingProgress() async =>
      const OnboardingProgress(
        currentStep: 'account',
        resumePath: '/onboarding/account',
        completedSteps: [],
        notificationChoice: 'ask_later',
        accessibilityPreferences: {},
        safetySetupChoice: 'review_later',
      );

  @override
  Future<OnboardingProgressV2> getOnboardingProgressV2() async => _progress;

  @override
  Future<OnboardingProgressV2> saveOnboardingAccountV2({
    required Map<String, dynamic> payload,
    required String clientRequestId,
  }) async {
    final role =
        userRoleFromString(payload['role']?.toString()) ?? UserRole.teen;
    _profile = Profile(
      id: '00000000-0000-4000-8000-0000000000aa',
      role: role,
      displayName: payload['display_name']?.toString(),
      username: payload['username']?.toString(),
      dob: DateTime.tryParse(payload['dob']?.toString() ?? ''),
      city: payload['city']?.toString(),
      state: payload['state']?.toString(),
      locationSetupMode:
          payload['location_setup_mode']?.toString() ?? 'location_deferred',
      approximateArea: payload['approximate_area']?.toString(),
      onboardingCompleted: false,
      accountStatus: 'active',
      verificationStatus: 'not_started',
      paymentPreference: 'none',
    );
    _progress = _progressFor(OnboardingStepV2.workPreferences);
    return _progress;
  }

  @override
  Future<OnboardingProgressV2> saveOnboardingWorkV2({
    required Map<String, dynamic> payload,
    required String clientRequestId,
    DateTime? expectedRevision,
  }) async => _mutate();

  @override
  Future<OnboardingProgressV2> saveOnboardingSafetyV2({
    required Map<String, dynamic> payload,
    required String clientRequestId,
    DateTime? expectedRevision,
  }) async => _mutate();

  @override
  Future<OnboardingProgressV2> completeOnboardingV2({
    required Map<String, dynamic> payload,
    required String clientRequestId,
    DateTime? expectedRevision,
  }) async => _mutate();

  @override
  Future<Profile> updateMyProfile(
    Map<String, dynamic> patch, {
    DateTime? expectedUpdatedAt,
    String? clientRequestId,
  }) async => _mutate();
}

class BrowserStackQaSafetyRepository extends SafetyRepository {
  @override
  Future<Map<String, dynamic>> getSafetyCenterConfig() async => const {
    'ok': true,
    'emergency_guidance': 'MORT does not dispatch physical help',
    'emergency_phone_uri': '',
  };

  @override
  Future<List<Map<String, dynamic>>> listActiveJobCheckins() async => const [];

  @override
  Future<List<Map<String, dynamic>>> listBlockedUsers() async => const [];

  @override
  Future<List<Map<String, dynamic>>> listMyReports() async => const [];

  @override
  Future<List<Map<String, dynamic>>> listVisibleSafetyPings() async => const [];

  @override
  Future<Map<String, dynamic>> createReport({
    String? targetUserId,
    String? targetJobId,
    String? targetMessageId,
    String? targetReviewId,
    required String reason,
    required String details,
    bool immediateDanger = false,
    String? clientRequestId,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> blockUser(
    String blockedId, {
    String? clientRequestId,
  }) async => _mutate();

  @override
  Future<bool> unblockUser(String blockedId) async => _mutate();

  @override
  Future<Map<String, dynamic>> createSafetyPing({
    String status = 'needs_help',
    String? note,
    String? jobId,
    bool immediateDanger = false,
    String? clientRequestId,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> scheduleActiveJobCheckin({
    required String applicationId,
    required int minutesFromNow,
    String? clientRequestId,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> completeActiveJobCheckin({
    required String checkinId,
    String? clientRequestId,
  }) async => _mutate();
}

class BrowserStackQaLegalContractRepository extends LegalContractRepository {
  @override
  Future<Map<String, dynamic>> legalRequirements() async => const {
    'requirements': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> acceptLegalVersion({
    required String versionId,
    required bool teenSummaryViewed,
    String? signature,
  }) async => _mutate();
}

List<Override> browserStackQaFixtureOverrides() {
  final profileRepository = BrowserStackQaProfileRepository();
  return [
    currentProfileProvider.overrideWith(
      (ref) => profileRepository.getCurrentProfile(),
    ),
    profileRepositoryProvider.overrideWithValue(profileRepository),
    financialRepositoryProvider.overrideWithValue(
      BrowserStackQaFinancialRepository(),
    ),
    safetyRepositoryProvider.overrideWithValue(
      BrowserStackQaSafetyRepository(),
    ),
    legalContractRepositoryProvider.overrideWithValue(
      BrowserStackQaLegalContractRepository(),
    ),
  ];
}
