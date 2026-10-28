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
          theme: mortTestTheme(MortTheme.dark()),
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
      await tester.enterText(find.byKey(const Key('home-search')), 'Yard');

      await tester.tap(find.text('Explore').last);
      await tester.pumpAndSettle();
      expect(find.text('Explore content'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Home content'), findsOneWidget);
      expect(find.text('Yard'), findsOneWidget);

      final safetyRoute = router.push<void>('/teen/safety');
      await tester.pumpAndSettle();
      expect(find.text('Safety content'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      await safetyRoute;
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
          theme: mortTestTheme(MortTheme.dark()),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      for (var cycle = 0; cycle < 20; cycle++) {
        for (final destination in ['Explore', 'Inbox', 'Profile', 'Home']) {
          await tester.tap(find.text(destination).last);
          await tester.pumpAndSettle();
          expect(find.text('$destination content'), findsOneWidget);
        }
      }

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Safety'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

GoRouter _teenRouter() => GoRouter(
  initialLocation: '/teen/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          TeenShell(navigationShell: navigationShell),
      branches: [
        _branch('/teen/home', 'Home', includeSearch: true),
        _branch('/teen/jobs', 'Explore'),
        _branch('/teen/messages', 'Inbox'),
        _branch('/teen/profile', 'Profile'),
      ],
    ),
    GoRoute(
      path: '/teen/safety',
      builder: (_, _) => const MortScreen(children: [Text('Safety content')]),
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
              key: Key('home-search'),
              decoration: InputDecoration(labelText: 'Search'),
            ),
        ],
      ),
    ),
  ],
);
