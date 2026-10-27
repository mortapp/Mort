import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/adult/adult_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testMortWidgets('adult shell has five destinations and a post-job action', (
    tester,
  ) async {
    final router = _adultRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: MortTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    final navigation = find.byType(MortGlassNavigationBar);
    for (final label in ['Home', 'Explore', '+', 'Inbox', 'Profile']) {
      expect(
        find.descendant(of: navigation, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: navigation, matching: find.byTooltip('Post a job')),
      findsOneWidget,
    );

    final bar = tester.widget<NavigationBar>(
      find.descendant(of: navigation, matching: find.byType(NavigationBar)),
    );
    final colors = MortTheme.light().colorScheme;
    expect(bar.backgroundColor, colors.surface);
    expect(bar.indicatorColor, colors.onSurface.withValues(alpha: 0.10));

    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    expect(find.text('Explore content'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home content'), findsOneWidget);

    await tester.tap(find.byTooltip('Post a job'));
    await tester.pumpAndSettle();
    expect(find.text('Post content'), findsOneWidget);
    expect(find.byType(MortGlassNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _adultRouter() => GoRouter(
  initialLocation: '/adult/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          AdultShell(navigationShell: navigationShell),
      branches: [
        _branch('/adult/home', 'Home'),
        _branch('/adult/explore', 'Explore'),
        _branch('/adult/post-job', 'Post'),
        _branch('/adult/inbox', 'Inbox'),
        _branch('/adult/profile', 'Profile'),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, String label) => StatefulShellBranch(
  routes: [
    GoRoute(
      path: path,
      builder: (_, _) => MortScreen(children: [Text('$label content')]),
    ),
  ],
);
