import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/trust_safety_repository.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/mort_widget_harness.dart';

const _limitedReleaseStatus = <String, dynamic>{
  'release_mode': 'closed_test',
  'marketplace_mode': 'closed_pilot',
  'public_marketplace_enabled': false,
  'real_document_collection': false,
  'payments_disabled': true,
};

Profile _profile({
  String status = 'active',
  bool onboardingCompleted = true,
  String verificationStatus = 'not_started',
}) => Profile(
  id: 'account-$status',
  role: UserRole.teen,
  displayName: 'QA Teen',
  username: 'qa_teen_$status',
  dob: DateTime(2010, 1, 1),
  city: 'Test City',
  state: 'TS',
  onboardingCompleted: onboardingCompleted,
  accountStatus: status,
  verificationStatus: verificationStatus,
  paymentPreference: 'decide_later',
);

class _RecordingTrustSafetyRepository extends TrustSafetyRepository {
  String? submittedReason;

  @override
  Future<void> submitAccountBanAppeal({required String reason}) async {
    submittedReason = reason;
  }
}

void main() {
  testMortWidgets(
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(
              AsyncValue.data(_profile(onboardingCompleted: false)),
            ),
            releaseModeStatusProvider.overrideWithValue(
              const AsyncValue.data(_limitedReleaseStatus),
            ),
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(
              AsyncValue.data(_profile()),
            ),
            releaseModeStatusProvider.overrideWithValue(
              const AsyncValue.data(_limitedReleaseStatus),
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
      expect(find.text('Limited access'), findsNothing);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.lock_outline)).color,
        MortColors.silverBright,
      );
      expect(find.text('Marketplace access limited'), findsOneWidget);
      expect(find.text('Identity verification unavailable'), findsOneWidget);
      expect(find.text('Job payment processing unavailable'), findsOneWidget);
      expect(find.textContaining('Not started'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Teen home'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/teen/home');
    },
  );

  testWidgets('enabled release capabilities remain explicit and truthful', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWithValue(
            AsyncValue.data(_profile(verificationStatus: 'approved')),
          ),
          releaseModeStatusProvider.overrideWithValue(
            const AsyncValue.data({
              'public_marketplace_enabled': true,
              'real_document_collection': true,
              'payments_disabled': false,
              'new_job_publishing_disabled': false,
              'maintenance_mode': false,
            }),
          ),
        ],
        child: const MaterialApp(home: AccountStatusScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Public marketplace enabled'), findsOneWidget);
    expect(find.text('Document collection enabled'), findsOneWidget);
    expect(find.text('Job payment controls available'), findsOneWidget);
    expect(find.textContaining('Verification: Approved'), findsOneWidget);
  });

  testWidgets(
    'suspended account keeps support and blocks every continue path',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/account-status',
        routes: [
          GoRoute(
            path: '/account-status',
            builder: (_, _) => const AccountStatusScreen(),
          ),
          GoRoute(
            path: '/support',
            builder: (_, _) =>
                const Scaffold(body: Text('Support destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(
              AsyncValue.data(_profile(status: 'suspended')),
            ),
            releaseModeStatusProvider.overrideWithValue(
              const AsyncValue.data(_limitedReleaseStatus),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account restricted'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Continue onboarding'), findsNothing);

      await tester.tap(find.text('Support'));
      await tester.pumpAndSettle();
      expect(find.text('Support destination'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/support');
    },
  );

  testWidgets(
    'banned account appeal stays in memory and does not restore access',
    (tester) async {
      final repository = _RecordingTrustSafetyRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(
              AsyncValue.data(_profile(status: 'banned')),
            ),
            releaseModeStatusProvider.overrideWithValue(
              const AsyncValue.data(_limitedReleaseStatus),
            ),
            trustSafetyRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: AccountStatusScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account restricted'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Appeal this ban'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Continue onboarding'), findsNothing);

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Why should this decision be reviewed?',
        ),
        '  This synthetic appeal has enough detail for review.  ',
      );
      final submit = find.text('Submit appeal');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        repository.submittedReason,
        'This synthetic appeal has enough detail for review.',
      );
      expect(
        find.text(
          'Your appeal is queued. MORT does not promise 24/7 review coverage.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Continue onboarding'), findsNothing);
    },
  );
}
