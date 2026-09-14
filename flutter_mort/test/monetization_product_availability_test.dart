import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/monetization/screens/monetization_home_screen.dart';
import 'package:flutter_mort/features/monetization/screens/product_availability_screen.dart';
import 'package:go_router/go_router.dart';

Widget _wrap(Widget screen) => MaterialApp(home: screen);

void main() {
  testWidgets('profile style pack screen shows honest unavailable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProductAvailabilityScreen(
          product: 'profile-style-pack',
          title: 'Profile styles',
          description:
              'Profile style packs are planned optional perks. No store '
              'offering is configured in this release.',
        ),
      ),
    );

    expect(find.text('Profile styles'), findsOneWidget);
    expect(find.text('NOT CURRENTLY AVAILABLE'), findsOneWidget);
    expect(find.text('Back to perks'), findsOneWidget);
    expect(find.textContaining('never require payment'), findsOneWidget);
    // Honesty law: no purchasable affordances, no prices, no fake success.
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('adult pro screen links to entitlement-honest insights', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProductAvailabilityScreen(
          product: 'adult-pro',
          title: 'Adult Pro',
          description:
              'Adult Pro perks are planned optional perks. No store offering '
              'is configured in this release.',
          secondaryRoute: '/adult/analytics',
          secondaryLabel: 'Open job insights status',
        ),
      ),
    );

    expect(find.text('Adult Pro'), findsOneWidget);
    expect(find.text('Open job insights status'), findsOneWidget);
    expect(find.textContaining('No store offering'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('guardian plus screen keeps basic guardian mode free', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ProductAvailabilityScreen(
          product: 'guardian-plus',
          title: 'Guardian Plus',
          description:
              'Basic Guardian Mode is free and always will be. No store '
              'offering is configured in this release.',
          secondaryRoute: '/guardian/home',
          secondaryLabel: 'Open Guardian Mode',
        ),
      ),
    );

    expect(find.text('Guardian Plus'), findsOneWidget);
    expect(find.textContaining('free and always will be'), findsOneWidget);
    expect(find.text('Open Guardian Mode'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('unavailable state remains usable at 320px and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/availability',
      routes: [
        GoRoute(
          path: '/availability',
          builder: (_, _) => const ProductAvailabilityScreen(
            product: 'profile-style-pack',
            title: 'Profile styles',
            description:
                'Profile style packs are planned optional perks. No store '
                'offering is configured in this release.',
          ),
        ),
        GoRoute(
          path: '/monetization',
          builder: (_, _) => const Scaffold(body: Text('Perks destination')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    );

    expect(find.text('NOT CURRENTLY AVAILABLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Back to perks'), 240);
    await tester.tap(find.text('Back to perks'));
    await tester.pumpAndSettle();
    expect(find.text('Perks destination'), findsOneWidget);
  });

  testWidgets('monetization center exposes the full product family', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const MonetizationHomeScreen()));

    for (final label in [
      'MORT Plus',
      'Ad-free',
      'Username token',
      'Job boost',
      'Profile styles',
      'Adult Pro',
      'Guardian Plus',
      'Restore',
      'Manage',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
