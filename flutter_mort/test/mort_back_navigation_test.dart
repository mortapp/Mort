import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:go_router/go_router.dart';

GoRouter _publicRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/auth/sign-in',
        builder: (_, _) => const UnifiedAuthScreen(),
      ),
      GoRoute(
        path: '/auth/sign-up',
        builder: (_, _) =>
            const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) => const LegalDocScreen(title: 'Terms'),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const LegalDocScreen(title: 'Privacy'),
      ),
    ],
  );
}

GoRouter _onboardingRouter({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      for (final route in const {
        '/onboarding/profile': 'Profile route',
        '/onboarding/skills': 'Skills route',
        '/onboarding/guardian': 'Guardian route',
        '/onboarding/preferences': 'Preferences route',
      }.entries)
        GoRoute(
          path: route.key,
          builder: (_, _) => MortScreen(children: [Text(route.value)]),
        ),
      GoRoute(
        path: '/onboarding/safety',
        builder: (_, _) => const SafetyRulesScreen(),
      ),
      for (final route in const {
        '/legal/terms': 'Terms document',
        '/legal/privacy': 'Privacy document',
        '/legal/community-rules': 'Community rules document',
        '/legal/teen-safety': 'Teen safety document',
      }.entries)
        GoRoute(
          path: route.key,
          builder: (_, _) => MortScreen(children: [Text(route.value)]),
        ),
    ],
  );
}

Future<void> _pumpPublicRouter(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String label) async {
  final control = find.text(label).first;
  expect(control, findsOneWidget);
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
}

void main() {
  group('MortBackNavigation', () {
    test('recognizes root locations', () {
      expect(MortBackNavigation.isRootLocation('/'), isTrue);
      expect(MortBackNavigation.isRootLocation('/splash'), isTrue);
      expect(MortBackNavigation.isRootLocation('/teen/home'), isTrue);
      expect(MortBackNavigation.isRootLocation('/settings'), isTrue);
      expect(MortBackNavigation.isRootLocation('/teen/jobs/123'), isFalse);
      expect(
        MortBackNavigation.isRootLocation('/auth/forgot-password'),
        isFalse,
      );
      expect(MortBackNavigation.isRootLocation('/auth/sign-in'), isFalse);
      expect(MortBackNavigation.isRootLocation('/auth/sign-up'), isFalse);
    });

    test('provides fallback route for auth entry routes', () {
      expect(MortBackNavigation.fallbackRoute('/auth/sign-in'), '/splash');
      expect(MortBackNavigation.fallbackRoute('/auth/sign-up'), '/splash');
    });

    test('provides fallback route for auth cleanup routes', () {
      expect(
        MortBackNavigation.fallbackRoute('/auth/forgot-password'),
        '/auth/sign-in',
      );
      expect(
        MortBackNavigation.fallbackRoute('/auth/recovery'),
        '/auth/sign-in',
      );
      expect(
        MortBackNavigation.fallbackRoute('/auth-recovery'),
        '/auth/sign-in',
      );
      expect(
        MortBackNavigation.fallbackRoute('/auth/confirm'),
        '/auth/sign-in',
      );
      expect(
        MortBackNavigation.fallbackRoute('/auth-confirm'),
        '/auth/sign-in',
      );
      expect(
        MortBackNavigation.fallbackRoute('/auth-callback'),
        '/auth/sign-in',
      );
    });

    test('provides fallback route for onboarding flow', () {
      expect(
        MortBackNavigation.fallbackRoute('/onboarding/age'),
        '/onboarding',
      );
      expect(
        MortBackNavigation.fallbackRoute('/onboarding/role'),
        '/onboarding/age',
      );
      expect(
        MortBackNavigation.fallbackRoute('/onboarding/profile'),
        '/onboarding/role',
      );
      expect(
        MortBackNavigation.fallbackRoute('/onboarding/review'),
        '/onboarding/preferences',
      );
      expect(
        MortBackNavigation.fallbackRoute('/onboarding/preferences'),
        '/onboarding/guardian',
      );
      expect(
        MortBackNavigation.fallbackRoute('/onboarding/safety'),
        '/onboarding/preferences',
      );
    });

    test('provides fallback route for nested resources', () {
      expect(
        MortBackNavigation.fallbackRoute('/teen/jobs/abc123'),
        '/teen/home',
      );
      expect(
        MortBackNavigation.fallbackRoute(
          '/teen/safety/applications/application-1',
        ),
        '/teen/safety',
      );
      expect(
        MortBackNavigation.fallbackRoute('/teen/messages/thread-1'),
        '/teen/messages',
      );
      expect(
        MortBackNavigation.fallbackRoute('/adult/jobs/xyz/edit'),
        '/adult/jobs/xyz',
      );
      expect(
        MortBackNavigation.fallbackRoute('/adult/post-job'),
        '/adult/home',
      );
      expect(
        MortBackNavigation.fallbackRoute('/adult/applicants/42'),
        '/adult/home',
      );
      expect(
        MortBackNavigation.fallbackRoute('/guardian/approvals/42'),
        '/guardian/home',
      );
      expect(
        MortBackNavigation.fallbackRoute('/guardian/safety-pings'),
        '/guardian/home',
      );
      expect(
        MortBackNavigation.fallbackRoute('/admin/reports/42'),
        '/admin/home',
      );
      expect(
        MortBackNavigation.fallbackRoute('/admin/support/ticket/42'),
        '/admin/home',
      );
      expect(
        MortBackNavigation.fallbackRoute('/support/chat/123'),
        '/support/chat',
      );
      expect(
        MortBackNavigation.fallbackRoute('/guide/conversation/123'),
        '/guide',
      );
    });
  });

  testWidgets(
    'system back repeatedly follows server-authoritative onboarding order',
    (tester) async {
      final router = _onboardingRouter(initialLocation: '/onboarding/skills');
      addTearDown(router.dispose);
      await _pumpPublicRouter(tester, router);
      for (final transition in const {
        '/onboarding/skills': 'Profile route',
        '/onboarding/preferences': 'Guardian route',
        '/onboarding/safety': 'Preferences route',
      }.entries) {
        for (var attempt = 0; attempt < 3; attempt += 1) {
          router.go(transition.key);
          await tester.pumpAndSettle();
          expect(find.byType(PopScope<Object?>), findsOneWidget);

          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();

          expect(find.text(transition.value), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'Safety legal references return to the invoking onboarding step',
    (tester) async {
      final router = _onboardingRouter(initialLocation: '/onboarding/safety');
      addTearDown(router.dispose);
      await _pumpPublicRouter(tester, router);

      for (final legalRoute in const {
        'Terms notice': ('/legal/terms', 'Terms document'),
        'Privacy notice': ('/legal/privacy', 'Privacy document'),
        'Community rules': (
          '/legal/community-rules',
          'Community rules document',
        ),
        'Teen safety': ('/legal/teen-safety', 'Teen safety document'),
      }.entries) {
        final control = find.byWidgetPredicate(
          (widget) => widget is MortButton && widget.label == legalRoute.key,
        );
        expect(control, findsOneWidget);
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, legalRoute.value.$1);
        expect(find.text(legalRoute.value.$2), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/onboarding/safety');
        expect(find.text('Review MORT safety rules'), findsOneWidget);
      }
    },
  );

  group('MortBackButton', () {
    testWidgets('MortHeader is safe without a Navigator ancestor', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MortHeader(title: 'Secure startup stopped'),
        ),
      );

      expect(find.text('Secure startup stopped'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MortHeader shows Back for a pushed canonical root', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MortScreen(
                    children: [MortHeader(title: 'Saved jobs')],
                  ),
                ),
              ),
              child: const Text('Open saved jobs'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open saved jobs'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Open saved jobs'), findsOneWidget);
    });

    testWidgets('falls back to route when navigation stack is not poppable', (
      WidgetTester tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/details',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox(key: ValueKey('home')),
          ),
          GoRoute(
            path: '/details',
            builder: (context, state) {
              return Center(child: MortBackButton(fallbackRoute: '/'));
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/details');
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/');
      expect(find.byKey(const ValueKey('home')), findsOneWidget);
    });

    testWidgets('pushes back when the navigator can pop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    key: const ValueKey('navToDetails'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const Scaffold(
                            body: Center(
                              child: MortBackButton(fallbackRoute: '/'),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Go'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('navToDetails')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('navToDetails')));
      await tester.pumpAndSettle();

      // Now a route was pushed onto the Navigator, MortBackButton should pop it.
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('navToDetails')), findsOneWidget);
    });

    testWidgets('real splash Sign in visible back returns to splash', (
      WidgetTester tester,
    ) async {
      final router = _publicRouter(initialLocation: '/splash');
      addTearDown(router.dispose);
      await _pumpPublicRouter(tester, router);

      await _tapText(tester, 'Sign in');
      expect(router.state.uri.path, '/auth/sign-in');
      expect(find.byType(TextFormField), findsWidgets);

      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/splash');
      expect(find.text('Enter MORT'), findsOneWidget);
    });

    testWidgets('real splash Sign in system back returns to splash', (
      WidgetTester tester,
    ) async {
      final router = _publicRouter(initialLocation: '/splash');
      addTearDown(router.dispose);
      await _pumpPublicRouter(tester, router);

      await _tapText(tester, 'Sign in');
      expect(router.state.uri.path, '/auth/sign-in');
      expect(find.byType(TextFormField), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/splash');
      expect(find.text('Enter MORT'), findsOneWidget);
    });

    testWidgets('real welcome Create account back returns to welcome', (
      WidgetTester tester,
    ) async {
      final router = _publicRouter(initialLocation: '/welcome');
      addTearDown(router.dispose);
      await _pumpPublicRouter(tester, router);

      await _tapText(tester, 'Create account');
      expect(router.state.uri.path, '/auth/sign-up');
      expect(find.text('Age-gated'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/welcome');
      expect(find.text('Welcome to MORT'), findsOneWidget);
    });

    testWidgets('real Sign in Forgot password back returns to Sign in', (
      WidgetTester tester,
    ) async {
      final router = _publicRouter(initialLocation: '/auth/sign-in');
      addTearDown(router.dispose);
      await _pumpPublicRouter(tester, router);

      await _tapText(tester, 'Forgot password');
      expect(router.state.uri.path, '/auth/forgot-password');
      expect(find.text('Reset password'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/auth/sign-in');
      expect(find.text('Welcome back'), findsOneWidget);
    });

    for (final legalRoute in const {
      'Terms': '/legal/terms',
      'Privacy Policy': '/legal/privacy',
    }.entries) {
      testWidgets('real ${legalRoute.key} back returns to invoking Sign in', (
        WidgetTester tester,
      ) async {
        final router = _publicRouter(initialLocation: '/auth/sign-in');
        addTearDown(router.dispose);
        await _pumpPublicRouter(tester, router);

        await _tapText(tester, legalRoute.key);
        expect(router.state.uri.path, legalRoute.value);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/auth/sign-in');
        expect(find.text('Welcome back'), findsOneWidget);
      });
    }
  });
}
