import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_space_background.dart';

void main() {
  test('MORT default theme follows the light monochrome prototype', () {
    final theme = MortTheme.light();

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, MortColors.white);
    expect(theme.colorScheme.primary, MortColors.black);
    expect(theme.colorScheme.onPrimary, MortColors.white);
    expect(theme.colorScheme.surface, MortColors.white);
    expect(MortColors.silverBright, MortColors.black);
    expect(MortColors.text, MortColors.black);
    expect(MortColors.line, const Color(0xFFE6E6E6));
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.textTheme.headlineSmall?.fontFamily, 'Instrument Sans');
  });

  test('prototype fonts are bundled with their licenses', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/fonts/Inter-Variable.ttf'));
    expect(pubspec, contains('assets/fonts/InstrumentSans-Variable.ttf'));
    expect(File('assets/fonts/OFL-Inter.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-InstrumentSans.txt').existsSync(), isTrue);
  });

  testWidgets('space background keeps a plain product surface', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MortSpaceBackground(child: Text('MORT'))),
      ),
    );

    expect(find.text('MORT'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MortSpaceBackground),
        matching: find.byType(ColoredBox),
      ),
      findsOneWidget,
    );
  });

  test('active screen background has no decorative painter', () {
    final source = File(
      'lib/core/widgets/mort_space_background.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('CustomPaint')));
    expect(source, isNot(contains('MortSpacePainter')));
  });
}
