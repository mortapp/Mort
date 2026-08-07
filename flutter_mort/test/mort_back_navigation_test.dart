import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:go_router/go_router.dart';

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
        MortBackNavigation.fallbackRoute('/auth/confirm'),
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
    });

    test('provides fallback route for nested resources', () {
      expect(
        MortBackNavigation.fallbackRoute('/teen/jobs/abc123'),
        '/teen/jobs',
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

  group('MortBackButton', () {
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

      expect(router.routeInformationProvider.value.location, '/details');
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.location, '/');
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
  });
}
