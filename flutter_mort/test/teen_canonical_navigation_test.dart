import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/teen/teen_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testMortWidgets('teen shell exposes only the four canonical destinations', (
    tester,
  ) async {
    final router = _teenRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: MortTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    final navigation = find.byType(MortGlassNavigationBar);
    expect(
      find.descendant(of: navigation, matching: find.text('Home')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(of: navigation, matching: find.text('Explore')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigation, matching: find.text('Inbox')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigation, matching: find.text('Profile')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigation, matching: find.text('Dashboard')),
      findsNothing,
    );
    expect(
      find.descendant(of: navigation, matching: find.text('Jobs')),
      findsNothing,
    );
    expect(
      find.descendant(of: navigation, matching: find.text('Safety')),
      findsNothing,
    );
    expect(
      find.descendant(of: navigation, matching: find.text('Messages')),
      findsNothing,
    );
    expect(
      find.descendant(of: navigation, matching: find.byIcon(Icons.add)),
      findsNothing,
    );
  });
}

GoRouter _teenRouter() => GoRouter(
  initialLocation: '/teen/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          TeenShell(navigationShell: navigationShell),
      branches: [
        _branch('/teen/home', 'Home'),
        _branch('/teen/jobs', 'Explore'),
        _branch('/teen/messages', 'Inbox'),
        _branch('/teen/profile', 'Profile'),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, String title) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      builder: (_, _) => MortScreen(children: [Text('$title content')]),
    ),
  ],
);
