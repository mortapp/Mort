import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/navigation/role_navigation_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('adult tabs preserve order and branch state', (tester) async {
    final router = _router(MortRoleTabs.adult);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: MortTheme.classic(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(_labels(tester), ['Home', 'Jobs', 'Messages', 'Safety', 'Profile']);
    await tester.tap(find.text('Messages').last);
    await tester.pumpAndSettle();
    expect(find.text('Messages content'), findsOneWidget);
    expect(
      tester
          .widget<MortBottomNavigation>(find.byType(MortBottomNavigation))
          .index,
      2,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home content'), findsOneWidget);
  });

  testWidgets('guardian has four tabs and Safety deep link selects Safety', (
    tester,
  ) async {
    final router = _router(
      MortRoleTabs.guardian,
      initialLocation: '/guardian/safety',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: MortTheme.classic(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(_labels(tester), ['Home', 'Safety', 'Messages', 'Profile']);
    expect(find.text('Safety content'), findsOneWidget);
    expect(
      tester
          .widget<MortBottomNavigation>(find.byType(MortBottomNavigation))
          .index,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}

List<String> _labels(WidgetTester tester) => tester
    .widget<MortBottomNavigation>(find.byType(MortBottomNavigation))
    .destinations
    .map((destination) => destination.label)
    .toList();

GoRouter _router(MortRoleTabs role, {String? initialLocation}) {
  final prefix = role == MortRoleTabs.adult ? '/adult' : '/guardian';
  final labels = role == MortRoleTabs.adult
      ? ['Home', 'Jobs', 'Messages', 'Safety', 'Profile']
      : ['Home', 'Safety', 'Messages', 'Profile'];
  return GoRouter(
    initialLocation: initialLocation ?? '$prefix/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MortRoleShell(navigationShell: navigationShell, tabs: role),
        branches: [
          for (final label in labels)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '$prefix/${label.toLowerCase()}',
                  builder: (_, _) => Scaffold(body: Text('$label content')),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}
