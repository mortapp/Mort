import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/onboarding_progress.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'post-auth account status resumes the server-authoritative onboarding step',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/account-status',
        routes: [
          GoRoute(
            path: '/account-status',
            builder: (_, _) => const AccountStatusScreen(),
          ),
          GoRoute(
            path: '/onboarding/safety',
            builder: (_, _) =>
                const Scaffold(body: Text('Safety resume route')),
          ),
        ],
      );
      addTearDown(router.dispose);

      final profile = Profile(
        id: 'teen-account',
        role: UserRole.teen,
        displayName: 'QA Teen',
        username: 'qa_teen',
        dob: DateTime(2010, 1, 1),
        city: 'Test City',
        state: 'TS',
        onboardingCompleted: false,
        accountStatus: 'active',
        verificationStatus: 'not_started',
        paymentPreference: 'decide_later',
      );
      const progress = OnboardingProgress(
        currentStep: 'safety',
        resumePath: '/onboarding/safety',
        completedSteps: ['age', 'role', 'profile'],
        notificationChoice: 'ask_later',
        accessibilityPreferences: {},
        safetySetupChoice: 'review_later',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(AsyncValue.data(profile)),
            onboardingProgressProvider.overrideWithValue(
              const AsyncValue.data(progress),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue onboarding'));
      await tester.pumpAndSettle();

      expect(find.text('Safety resume route'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/onboarding/safety',
      );
    },
  );
}
