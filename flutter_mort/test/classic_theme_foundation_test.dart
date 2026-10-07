import 'package:flutter/material.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmospheric_background.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classic theme makes black and gray primary, with supporting white', () {
    final theme = MortTheme.classic();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0D0D0D));
    expect(theme.colorScheme.primary, const Color(0xFF424242));
    expect(theme.colorScheme.onPrimary, Colors.white);
    expect(theme.colorScheme.onSurface, const Color(0xFFF1F1F1));
  });

  testWidgets('classic scaffold has no production atmosphere', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MortTheme.classic(),
        home: const MortScaffold(children: [Text('Nearby jobs')]),
      ),
    );

    expect(find.text('Nearby jobs'), findsOneWidget);
    expect(find.byType(MortAtmosphericBackground), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF0D0D0D));
  });

  testWidgets('classic primary action has gray fill and no gradient', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MortTheme.classic(),
        home: Scaffold(
          body: MortButton(label: 'Continue', onPressed: () {}),
        ),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.style?.backgroundColor?.resolve({}), const Color(0xFF424242));
    expect(button.style?.foregroundColor?.resolve({}), Colors.white);
    final decoratedBox = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byType(ElevatedButton),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(decoratedBox.decoration, isA<BoxDecoration>());
    expect((decoratedBox.decoration as BoxDecoration).gradient, isNull);
  });

  testWidgets('classic card is a plain graphite surface without blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MortTheme.classic(),
        home: const Scaffold(body: MortGlassCard(child: Text('A local job'))),
      ),
    );

    expect(find.text('A local job'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    final card = tester
        .widgetList<Material>(find.byType(Material))
        .firstWhere((material) => material.shape is RoundedRectangleBorder);
    expect(card.color, const Color(0xFF1B1B1B));
    expect(card.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('classic field and icon action remain readable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MortTheme.classic(),
        home: Scaffold(
          body: Column(
            children: [
              const MortTextField(label: 'Email', errorText: 'Required'),
              MortIconButton(
                icon: Icons.settings,
                tooltip: 'Settings',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final theme = MortTheme.classic();
    expect(
      theme.inputDecorationTheme.focusedBorder?.borderSide.color,
      theme.colorScheme.onSurface,
    );
    expect(
      theme.inputDecorationTheme.errorBorder?.borderSide.color,
      theme.colorScheme.onSurface,
    );
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      button.style?.foregroundColor?.resolve({}),
      theme.colorScheme.onSurface,
    );
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('classic primary action respects reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MortTheme.classic(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: MortButton(label: 'Continue', onPressed: () {}),
          ),
        ),
      ),
    );

    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(ElevatedButton),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.duration, Duration.zero);
  });
}
