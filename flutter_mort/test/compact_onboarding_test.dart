import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/utils/date_of_birth.dart';
import 'package:flutter_mort/data/models/onboarding_progress.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/legal_contract_repository.dart';
import 'package:flutter_mort/data/repositories/profile_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_mort/features/onboarding/compact_onboarding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _initialProgress = OnboardingProgress(
  currentStep: 'age',
  resumePath: '/onboarding/age',
  completedSteps: [],
  notificationChoice: 'ask_later',
  accessibilityPreferences: {},
  safetySetupChoice: 'review_later',
);

const _savedProfile = Profile(
  id: '00000000-0000-4000-8000-000000000101',
  role: UserRole.teen,
  displayName: 'Alex',
  username: 'alex_local',
  dob: null,
  city: null,
  state: null,
  onboardingCompleted: false,
  accountStatus: 'active',
  verificationStatus: 'not_started',
  paymentPreference: 'none',
);

class _FakeProfileRepository extends ProfileRepository {
  int ageSaves = 0;
  int roleSaves = 0;
  int profileUpdates = 0;
  int acknowledgements = 0;
  int completions = 0;
  final completedStepsInOrder = <String>[];

  @override
  Future<OnboardingProgress> getOnboardingProgress() async => _initialProgress;

  @override
  Future<OnboardingProgress> saveOnboardingAge(DateTime dob) async {
    ageSaves++;
    return _initialProgress;
  }

  @override
  Future<OnboardingProgress> saveOnboardingRole(UserRole role) async {
    roleSaves++;
    return _initialProgress;
  }

  @override
  Future<Profile> updateMyProfile(
    Map<String, dynamic> updates, {
    DateTime? expectedUpdatedAt,
    String? clientRequestId,
  }) async {
    profileUpdates++;
    return _savedProfile;
  }

  @override
  Future<OnboardingProgress> saveOnboardingProgress({
    required String completedStep,
    Map<String, dynamic> preferences = const {},
  }) async {
    completedStepsInOrder.add(completedStep);
    return _initialProgress;
  }

  @override
  Future<OnboardingProgress> recordOnboardingAcknowledgement({
    required String version,
    required String platform,
    required String appVersion,
  }) async {
    acknowledgements++;
    return _initialProgress;
  }

  @override
  Future<Profile> completeOnboarding() async {
    completions++;
    return _savedProfile;
  }
}

class _FakeLegalContractRepository extends LegalContractRepository {
  @override
  Future<Map<String, dynamic>> legalRequirements() async => const {
    'requirements': <Map<String, dynamic>>[],
  };
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  _FakeProfileRepository? repository,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) async {
  final fakeRepository = repository ?? _FakeProfileRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(fakeRepository),
        currentProfileProvider.overrideWith((ref) async => null),
        legalContractRepositoryProvider.overrideWithValue(
          _FakeLegalContractRepository(),
        ),
      ],
      child: MaterialApp(
        theme: MortTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: textScaler,
            disableAnimations: disableAnimations,
          ),
          child: const CompactOnboardingScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _teenDob() {
  final today = DateTime.now();
  return DateOfBirthParser.display(
    DateTime(today.year - 16, today.month, today.day),
  );
}

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

  test('compact onboarding never persists raw coordinates as profile area', () {
    final source = File(
      '${Directory.current.path}/lib/features/onboarding/compact_onboarding.dart',
    ).readAsStringSync();

    expect(source, contains('resolveCurrentGeneralArea'));
    expect(source, contains("_zip.text = '\${area.city}, \${area.state}'"));
    expect(source, isNot(contains('position.latitude')));
    expect(source, isNot(contains('position.longitude')));
    expect(source, isNot(contains('toStringAsFixed')));
  });

  testWidgets(
    'compact onboarding completes the canonical five-step teen flow',
    (WidgetTester tester) async {
      // A real phone-sized viewport, not the default tiny headless test
      // surface -- this flow's later steps (e.g. skill chips) need
      // realistic vertical space, matching the "Samsung viewport" test
      // below rather than assuming an unrealistic 800x600 window.
      tester.view.physicalSize = const Size(1080, 2408);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeProfileRepository();
      await _pumpOnboarding(tester, repository: repository);

      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Start with your age'), findsOneWidget);
      expect(find.text('Choose account'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), _teenDob());
      await tester.tap(find.text('Choose account'));
      await tester.pumpAndSettle();

      expect(repository.ageSaves, 1);
      expect(repository.roleSaves, 1);
      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text('Make it yours'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Alex');
      await tester.enterText(find.byType(TextFormField).at(1), 'alex_local');
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Set your area'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Indianapolis');
      await tester.tap(find.text('Save area'));
      await tester.pumpAndSettle();

      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.text('Payment, guardian & interests'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Yard work'));
      await tester.tap(find.widgetWithText(FilterChip, 'Yard work'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(find.text('Rules, review & finish'), findsOneWidget);
      final checkboxCount = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .length;
      expect(checkboxCount, 6);
      for (var i = 0; i < checkboxCount; i++) {
        final finder = find.byType(CheckboxListTile).at(i);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Teen account'));
      expect(find.text('Teen account'), findsOneWidget);
      expect(find.text('Indianapolis'), findsOneWidget);
      expect(find.text('Yard work'), findsOneWidget);
      await tester.ensureVisible(find.text('Finish setup'));
      await tester.tap(find.text('Finish setup'));
      await tester.pumpAndSettle();

      expect(repository.profileUpdates, 3);
      expect(repository.acknowledgements, 1);
      expect(repository.completions, 1);
      expect(
        repository.completedStepsInOrder,
        containsAllInOrder(<String>[
          'profile',
          'skills',
          'availability',
          'transportation',
          'payment',
          'guardian',
          'preferences',
          'safety',
          'review',
        ]),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onboarding stays usable on Samsung viewport with large text and reduced motion',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2408);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpOnboarding(
        tester,
        textScaler: const TextScaler.linear(1.8),
        disableAnimations: true,
      );

      expect(find.text('Start with your age'), findsOneWidget);
      expect(find.text('Choose account'), findsOneWidget);
      final actionButton = find.ancestor(
        of: find.text('Choose account'),
        matching: find.byType(ElevatedButton),
      );
      expect(actionButton, findsOneWidget);
      expect(
        tester.getBottomRight(actionButton).dy,
        lessThanOrEqualTo(tester.view.physicalSize.height / 3),
      );
      final switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switcher.duration, Duration.zero);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsaved age entry is protected by the system Back flow', (
    WidgetTester tester,
  ) async {
    await _pumpOnboarding(tester);

    await tester.enterText(find.byType(TextFormField), _teenDob());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Leave setup?'), findsOneWidget);
    expect(find.text('Leave setup'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('auth screens expose versioned legal acknowledgement links', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: UnifiedAuthScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Terms'), findsWidgets);
    expect(find.textContaining('Privacy Policy'), findsWidgets);
    expect(find.byType(Checkbox), findsWidgets);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Terms'), findsWidgets);
    expect(find.textContaining('Privacy Policy'), findsWidgets);
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
