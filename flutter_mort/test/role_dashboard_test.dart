import 'package:flutter/material.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/mission/partner_staff_screens.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _closedPilotStatus = <String, dynamic>{
  'release_mode': 'closed_test',
  'marketplace_mode': 'closed_pilot',
  'public_marketplace_enabled': false,
  'real_document_collection': false,
  'payments_disabled': true,
  'new_job_publishing_disabled': false,
};

Profile _profile(UserRole role) => Profile(
  id: 'profile-${role.name}',
  role: role,
  displayName: '${role.name} tester',
  username: '${role.name}_tester',
  dob: DateTime(1990, 1, 1),
  city: 'Test City',
  state: 'TS',
  onboardingCompleted: true,
  accountStatus: 'active',
  verificationStatus: 'approved',
  paymentPreference: 'none',
);

Future<GoRouter> _pumpDashboard(
  WidgetTester tester,
  UserRole role, {
  List<Map<String, dynamic>> partnerContexts = const [],
  bool largeText = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => RoleHomeScreen(role: role),
      ),
      GoRoute(
        path: '/adult/post-job',
        builder: (_, _) => const Scaffold(body: Text('Post job destination')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWithValue(
          AsyncValue.data(_profile(role)),
        ),
        partnerStaffContextsProvider.overrideWithValue(
          AsyncValue.data(partnerContexts),
        ),
        releaseModeStatusProvider.overrideWithValue(
          const AsyncValue.data(_closedPilotStatus),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(largeText ? 1.8 : 1)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('Adult dashboard groups real work, account, and safety routes', (
    tester,
  ) async {
    final router = await _pumpDashboard(
      tester,
      UserRole.adult,
      partnerContexts: const [
        {'organization_id': 'qa-organization'},
      ],
    );
    addTearDown(router.dispose);

    expect(find.text('Adult dashboard'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('BUSINESS AND ACCOUNT'), findsOneWidget);
    expect(find.text('SAFETY AND SUPPORT'), findsOneWidget);
    expect(find.text('Post a job'), findsOneWidget);
    expect(find.text('My jobs'), findsOneWidget);
    expect(find.text('Applicants'), findsOneWidget);
    expect(find.text('Verification'), findsOneWidget);
    expect(find.text('Partner workspace'), findsOneWidget);

    await tester.ensureVisible(find.text('Post a job'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post a job'));
    await tester.pumpAndSettle();
    expect(find.text('Post job destination'), findsOneWidget);
  });

  testWidgets(
    'Guardian dashboard keeps free safety and privacy controls visible',
    (tester) async {
      final router = await _pumpDashboard(tester, UserRole.guardian);
      addTearDown(router.dispose);

      expect(find.text('Guardian dashboard'), findsOneWidget);
      expect(find.text('Review approvals'), findsOneWidget);
      expect(find.text('LINKED TEEN SAFETY'), findsOneWidget);
      expect(find.text('Linked teens'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Safety Pings'), findsOneWidget);
      expect(find.text('Guardian Mode settings'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
    },
  );

  testWidgets('Admin dashboard exposes authorized moderation and governance', (
    tester,
  ) async {
    final router = await _pumpDashboard(tester, UserRole.admin);
    addTearDown(router.dispose);

    expect(find.text('Admin dashboard'), findsOneWidget);
    expect(find.text('Review reports'), findsOneWidget);
    expect(find.text('MODERATION'), findsOneWidget);
    expect(find.text('OPERATIONS'), findsOneWidget);
    expect(find.text('GOVERNANCE'), findsOneWidget);
    expect(find.text('Restricted queues'), findsOneWidget);
    expect(find.text('Incident cases'), findsOneWidget);
    expect(find.text('Message moderation'), findsOneWidget);
    expect(find.text('Audit logs'), findsOneWidget);
    expect(find.text('Marketplace and monetization gates'), findsOneWidget);
  });

  testWidgets('Adult dashboard fits a narrow Samsung viewport at large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2408);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = await _pumpDashboard(
      tester,
      UserRole.adult,
      largeText: true,
    );
    addTearDown(router.dispose);

    expect(find.text('Adult dashboard'), findsOneWidget);
    expect(find.text('Post a job'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
