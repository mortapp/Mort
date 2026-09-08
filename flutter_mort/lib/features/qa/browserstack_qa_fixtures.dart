import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/financial_safety.dart';
import '../../data/models/onboarding_progress.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/avatar_repository.dart';
import '../../data/repositories/financial_repository.dart';
import '../../data/repositories/legal_contract_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/repository_base.dart';
import '../../data/repositories/safety_repository.dart';
import '../../services/native_permissions_service.dart';

const browserStackQaMutationMessage =
    'BrowserStack QA mode does not permit mutations.';

Never _mutate() => throw StateError(browserStackQaMutationMessage);

class BrowserStackQaNativePermissionsService extends NativePermissionsService {
  const BrowserStackQaNativePermissionsService();

  @override
  Future<NativePermissionSnapshot> snapshot() async =>
      const NativePermissionSnapshot(
        notifications: PermissionStatus.denied,
        camera: PermissionStatus.denied,
        photos: PermissionStatus.denied,
        location: LocationPermission.denied,
        locationAccuracy: null,
        locationServicesEnabled: false,
        photoPickerNeedsBroadPermission: true,
      );

  @override
  Future<PermissionStatus> requestCamera() async => _mutate();

  @override
  Future<PermissionStatus> requestPhotos() async => _mutate();

  @override
  Future<LocationPermission> requestForegroundLocation() async => _mutate();

  @override
  Future<GeneralSearchArea> resolveCurrentGeneralArea() async => _mutate();

  @override
  Future<bool> openSettings() async => _mutate();
}

mixin _BrowserStackQaMutationGuard on RepositoryBase {
  @override
  Future<void> recordUploadFailure({
    required String uploadKind,
    required String safeCode,
  }) async => _mutate();

  @override
  Future<void> recordOperationalFailure({
    required String eventType,
    required String safeCode,
  }) async => _mutate();
}

class BrowserStackQaFinancialRepository extends FinancialRepository
    with _BrowserStackQaMutationGuard {
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

class BrowserStackQaProfileRepository extends ProfileRepository
    with _BrowserStackQaMutationGuard {
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
  Future<Profile?> getProfile(String profileId) async =>
      _profile?.id == profileId ? _profile : null;

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
  Future<Profile> saveProfile({
    required UserRole role,
    required String displayName,
    required DateTime dob,
    String? city,
    String? state,
    String locationSetupMode = 'city_state',
    bool completeOnboarding = true,
    String paymentPreference = 'none',
  }) async => _mutate();

  @override
  Future<Profile> completeOnboarding() async => _mutate();

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
  Future<OnboardingProgress> saveOnboardingAge(DateTime dob) async => _mutate();

  @override
  Future<OnboardingProgress> saveOnboardingRole(UserRole role) async =>
      _mutate();

  @override
  Future<OnboardingProgress> saveOnboardingProgress({
    required String completedStep,
    Map<String, dynamic> preferences = const {},
  }) async => _mutate();

  @override
  Future<OnboardingProgress> recordOnboardingAcknowledgement({
    required String version,
    required String platform,
    required String appVersion,
  }) async => _mutate();

  @override
  Future<Profile> saveProfileDetails({
    required String displayName,
    required String bio,
    required String availability,
    required List<String> preferredJobCategories,
    required String approximateArea,
    required String goals,
  }) async => _mutate();

  @override
  Future<Profile> saveProfileSetup({
    required UserRole role,
    required String displayName,
    required String username,
    required DateTime dob,
    required String city,
    required String state,
    required String locationSetupMode,
    required String bio,
    required String availability,
    required List<String> preferredJobCategories,
    required String approximateArea,
    required String goals,
    required String adultAccountType,
    required String businessName,
    required bool editExisting,
    required String clientRequestId,
  }) async => _mutate();

  @override
  Future<Profile> saveTransportationPreferences({
    required List<String> methods,
    int? maxDistanceMiles,
    int? maxTravelMinutes,
    bool walkingDistanceOnly = false,
    bool guardianTransportationPossible = false,
  }) async => _mutate();

  @override
  Future<Profile> setAvatarPath(String? path) async => _mutate();

  @override
  Future<Profile> updateMyProfile(
    Map<String, dynamic> patch, {
    DateTime? expectedUpdatedAt,
    String? clientRequestId,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> getUsernameChangeStatus() async => const {
    'current_username': null,
    'free_changes_used': 0,
    'free_changes_remaining': 0,
    'token_credits': 0,
    'admin_credits': 0,
    'plus_allowance_available': false,
    'plus_changes_used': 0,
    'plus_period_start': null,
  };

  @override
  Future<Map<String, dynamic>> requestUsernameChange(String username) async =>
      _mutate();
}

// The real onboarding "Save account" -> Back navigation path (and the
// settings profile screen) mount ProfileAvatarEditor, which calls
// avatarRepositoryProvider directly rather than profileRepositoryProvider.
// Without this override, that widget's "Choose photo"/"Take photo" buttons
// would invoke the real ImagePicker (real camera/gallery permission
// prompts) and, on a selected photo, real Supabase Storage uploads -- none
// of which BrowserStack QA mode may ever trigger. Every entry point is
// blocked before it reaches ImagePicker or the network, never merely
// after.
class BrowserStackQaAvatarRepository extends AvatarRepository
    with _BrowserStackQaMutationGuard {
  @override
  Future<XFile?> choosePhoto({
    ImageSource source = ImageSource.gallery,
  }) async => _mutate();

  @override
  Future<Uint8List> prepareAvatar(XFile file) async => _mutate();

  @override
  Future<String> uploadAvatar(XFile file, {String? previousPath}) async =>
      _mutate();

  @override
  Future<String> uploadPreparedAvatar(
    Uint8List processed, {
    String? previousPath,
  }) async => _mutate();

  @override
  Future<void> removeAvatar(String? currentPath) async => _mutate();

  @override
  Future<String?> signedAvatarUrl({
    required String profileId,
    required String? avatarPath,
    DateTime? avatarUpdatedAt,
    bool forceRefresh = false,
  }) async => null;
}

class BrowserStackQaSafetyRepository extends SafetyRepository
    with _BrowserStackQaMutationGuard {
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

class BrowserStackQaLegalContractRepository extends LegalContractRepository
    with _BrowserStackQaMutationGuard {
  @override
  Future<Map<String, dynamic>> legalRequirements() async => const {
    'requirements': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> publishedLegalVersion(String versionId) async =>
      const {};

  @override
  Future<List<Map<String, dynamic>>> contracts() async => const [];

  @override
  Future<List<Map<String, dynamic>>> contractVersions(
    String contractId,
  ) async => const [];

  @override
  Future<List<Map<String, dynamic>>> contractAcceptances(
    String contractId,
  ) async => const [];

  @override
  Future<Map<String, dynamic>> acceptLegalVersion({
    required String versionId,
    required bool teenSummaryViewed,
    String? signature,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> confirmContractVersion({
    required String versionId,
    required String confirmation,
  }) async => _mutate();

  @override
  Future<List<Map<String, dynamic>>> contractChanges(String contractId) async =>
      const [];

  @override
  Future<Map<String, dynamic>> requestContractChange({
    required String contractId,
    required Map<String, dynamic> patch,
    required String reason,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> respondContractChange({
    required String changeId,
    required bool accept,
  }) async => _mutate();

  @override
  Future<List<Map<String, dynamic>>> paymentObligations(
    String contractId,
  ) async => const [];

  @override
  Future<List<Map<String, dynamic>>> paymentDisputes(String contractId) async =>
      const [];

  @override
  Future<Map<String, dynamic>> paymentDispute(String disputeId) async =>
      const {};

  @override
  Future<List<Map<String, dynamic>>> disputeTimeline(String disputeId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> disputeStatements(
    String disputeId,
  ) async => const [];

  @override
  Future<List<Map<String, dynamic>>> disputeAppeals(String disputeId) async =>
      const [];

  @override
  Future<Map<String, dynamic>> reportNonpayment({
    required String obligationId,
    required String statement,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> submitDisputeStatement({
    required String disputeId,
    required String statement,
    String? clientRequestId,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> submitDisputeAppeal({
    required String disputeId,
    required String reason,
    String? clientRequestId,
  }) async => _mutate();

  @override
  Future<Map<String, dynamic>> evidenceExport(String disputeId) async =>
      _mutate();

  @override
  Future<Map<String, dynamic>> firstPartyTrustStatus() async => const {};
}

List<Override> browserStackQaFixtureOverrides() {
  final profileRepository = BrowserStackQaProfileRepository();
  final financialRepository = BrowserStackQaFinancialRepository();
  return [
    authStateProvider.overrideWith(
      (ref) => Stream<AuthState>.value(
        const AuthState(AuthChangeEvent.initialSession, null),
      ),
    ),
    currentProfileProvider.overrideWith(
      (ref) => profileRepository.getCurrentProfile(),
    ),
    profileRepositoryProvider.overrideWithValue(profileRepository),
    avatarRepositoryProvider.overrideWithValue(
      BrowserStackQaAvatarRepository(),
    ),
    financialRepositoryProvider.overrideWithValue(financialRepository),
    financialSummaryProvider.overrideWith(
      (ref, year) => financialRepository.getFinancialSummary(year),
    ),
    financialAlertsProvider.overrideWith(
      (ref, year) => financialRepository.evaluateAlerts(year),
    ),
    safetyRepositoryProvider.overrideWithValue(
      BrowserStackQaSafetyRepository(),
    ),
    legalContractRepositoryProvider.overrideWithValue(
      BrowserStackQaLegalContractRepository(),
    ),
  ];
}
