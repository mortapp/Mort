import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'post-auth account status enters the four-step server-authoritative flow',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/account-status',
        routes: [
          GoRoute(
            path: '/account-status',
            builder: (_, _) => const AccountStatusScreen(),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (_, _) => const Scaffold(body: Text('Four-step route')),
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(AsyncValue.data(profile)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue onboarding'));
      await tester.pumpAndSettle();

      expect(find.text('Four-step route'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/onboarding');
    },
  );

  testWidgets(
    'completed account status does not expose internal release vocabulary',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/account-status',
        routes: [
          GoRoute(
            path: '/account-status',
            builder: (_, _) => const AccountStatusScreen(),
          ),
          GoRoute(
            path: '/teen/home',
            builder: (_, _) => const Scaffold(body: Text('Teen home')),
          ),
        ],
      );
      addTearDown(router.dispose);

      final profile = Profile(
        id: 'complete-teen-account',
        role: UserRole.teen,
        displayName: 'QA Teen',
        username: 'qa_teen_complete',
        dob: DateTime(2010, 1, 1),
        city: 'Test City',
        state: 'TS',
        onboardingCompleted: true,
        accountStatus: 'active',
        verificationStatus: 'not_started',
        paymentPreference: 'decide_later',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(AsyncValue.data(profile)),
            releaseModeStatusProvider.overrideWithValue(
              const AsyncValue.data({
                'release_mode': 'closed_test',
                'marketplace_mode': 'closed_pilot',
                'public_marketplace_enabled': false,
                'real_document_collection': false,
                'payments_disabled': true,
              }),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      for (final prohibited in const [
        'Closed Pilot',
        'Closed pilot',
        'Closed test',
        'Server-controlled access',
        'Approved participants only',
        'not_started',
      ]) {
        expect(find.textContaining(prohibited), findsNothing);
      }
      expect(find.text('Limited access'), findsWidgets);
      expect(find.text('Identity verification unavailable'), findsOneWidget);
      expect(find.textContaining('Not started'), findsOneWidget);
    },
  );
}
