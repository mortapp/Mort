import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_liquid_glass.dart';

import 'helpers/mort_widget_harness.dart';

const _destinations = [
  MortNavigationDestination(
    label: 'Discover',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  MortNavigationDestination(
    label: 'Jobs',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
  ),
  MortNavigationDestination(
    label: 'Safety',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield_rounded,
  ),
  MortNavigationDestination(
    label: 'Messages',
    icon: Icons.chat_bubble_outline_rounded,
    selectedIcon: Icons.chat_bubble_rounded,
  ),
  MortNavigationDestination(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

void main() {
  testWidgets('legacy glass surface renders without backdrop blur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mortTestTheme(MortTheme.dark()),
        home: const Scaffold(
          body: LiquidGlassContainer(
            liveBlur: true,
            child: Text('Safety surface'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Safety surface'), findsOneWidget);
  });

  testWidgets('legacy blur request does not add backdrop blur', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mortTestTheme(MortTheme.light()),
        home: const Scaffold(
          body: LiquidGlassContainer(
            liveBlur: true,
            allowAndroidBlur: true,
            child: Text('Navigation surface'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testMortWidgets(
    'flat navigation is accessible and responsive at large text',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2408);
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: mortTestTheme(MortTheme.light()),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: MortGlassNavigationBar(
                  currentIndex: selected,
                  destinations: _destinations,
                  onDestinationSelected: (index) {
                    setState(() => selected = index);
                  },
                ),
              ),
            ),
          ),
        ),
      );

      for (final destination in _destinations) {
        final label = find.text(destination.label);
        expect(label, findsOneWidget);
        final target = find.ancestor(of: label, matching: find.byType(InkWell));
        expect(target, findsOneWidget);
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      expect(find.byType(LiquidGlassContainer), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Safety'));
      await tester.pumpAndSettle();
      expect(selected, 2);
    },
  );

  testWidgets('destination header uses a flat divider and no glass card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mortTestTheme(MortTheme.light()),
        home: const Scaffold(
          body: Column(
            children: [MortGlassHeader(title: 'Explore', eyebrow: 'MORT')],
          ),
        ),
      ),
    );

    expect(find.text('Explore'), findsOneWidget);
    expect(find.byType(LiquidGlassContainer), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
