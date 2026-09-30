import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/teen/teen_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testMortWidgets(
    'Teen shell preserves branch state and gives visible and system Back parity',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2408);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = _teenRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: mortTestTheme(MortTheme.classic()),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home content'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dashboard-search')), 'Yard');

      await tester.tap(find.text('Jobs').last);
      await tester.pumpAndSettle();
      expect(find.text('Jobs content'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Home content'), findsOneWidget);
      expect(find.text('Yard'), findsOneWidget);

      await tester.tap(find.text('Safety').last);
      await tester.pumpAndSettle();
      expect(find.text('Safety content'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Home content'), findsOneWidget);
      expect(find.text('Yard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Teen shell survives repeated destination cycles without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2408);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = _teenRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: mortTestTheme(MortTheme.classic()),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      for (var cycle = 0; cycle < 20; cycle++) {
        await tester.tap(find.text('Profile').last);
        await tester.pumpAndSettle();
        expect(find.text('Profile content'), findsOneWidget);
        await tester.tap(find.text('Home').last);
        await tester.pumpAndSettle();
        expect(find.text('Home content'), findsOneWidget);
      }

      expect(find.byType(MortBottomNavigation), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('teen Messages deep link selects the Messages tab', (
    tester,
  ) async {
    final router = _teenRouter(initialLocation: '/teen/messages');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: MortTheme.classic(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages content'), findsOneWidget);
    final navigation = tester.widget<MortBottomNavigation>(
      find.byType(MortBottomNavigation),
    );
    expect(navigation.index, 2);
    expect(find.text('Safety'), findsOneWidget);
  });
}

GoRouter _teenRouter({String initialLocation = '/teen/home'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          TeenShell(navigationShell: navigationShell),
      branches: [
        _branch('/teen/home', 'Home', includeSearch: true),
        _branch('/teen/jobs', 'Jobs'),
        _branch('/teen/messages', 'Messages'),
        _branch('/teen/safety', 'Safety'),
        _branch('/teen/profile', 'Profile'),
      ],
    ),
  ],
);

StatefulShellBranch _branch(
  String path,
  String title, {
  bool includeSearch = false,
}) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      builder: (_, _) => MortScreen(
        children: [
          MortTeenDestinationHeader(title: title),
          Text('$title content'),
          if (includeSearch)
            const TextField(
              key: Key('dashboard-search'),
              decoration: InputDecoration(labelText: 'Search'),
            ),
        ],
      ),
    ),
  ],
);
