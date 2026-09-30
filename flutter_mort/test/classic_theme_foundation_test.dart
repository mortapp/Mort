import 'package:flutter/material.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmospheric_background.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classic theme uses a white surface and near-black primary color', () {
    final theme = MortTheme.classic();

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(theme.colorScheme.primary, const Color(0xFF111111));
    expect(theme.colorScheme.onPrimary, Colors.white);
    expect(theme.colorScheme.onSurface, const Color(0xFF111111));
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
    expect(scaffold.backgroundColor, Colors.white);
  });

  testWidgets('classic primary action has black fill and no gradient', (
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
    expect(button.style?.backgroundColor?.resolve({}), const Color(0xFF111111));
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

  testWidgets('classic card is a plain white surface without blur', (
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
    final card = tester.widgetList<Material>(find.byType(Material)).firstWhere(
      (material) => material.shape is RoundedRectangleBorder,
    );
    expect(card.color, Colors.white);
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
      theme.colorScheme.primary,
    );
    expect(
      theme.inputDecorationTheme.errorBorder?.borderSide.color,
      theme.colorScheme.error,
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
