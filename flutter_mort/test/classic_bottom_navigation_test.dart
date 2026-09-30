import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
    NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'Messages'),
    NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Safety'),
    NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
  ];

  testWidgets(
    'classic tab bar uses one elevated active pill and full targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: MortTheme.classic(),
          home: Scaffold(
            bottomNavigationBar: MortBottomNavigation(
              index: 2,
              destinations: destinations,
              onDestinationSelected: (index) => selected = index,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Messages' &&
              widget.properties.selected == true,
        ),
        findsOneWidget,
      );
      final activePill = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('Messages'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect((activePill.decoration as BoxDecoration).boxShadow, isNotEmpty);
      for (final destination in destinations) {
        final target = find.ancestor(
          of: find.text(destination.label),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('Safety'));
      expect(selected, 3);
    semantics.dispose();
    },
  );

  testWidgets('classic tab bar handles narrow large-text reduced-motion mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1372);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: MortTheme.classic(),
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            bottomNavigationBar: MortBottomNavigation(
              index: 0,
              destinations: destinations,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Messages'), findsOneWidget);
    final pill = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text('Home'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(pill.duration, Duration.zero);
  });
}
