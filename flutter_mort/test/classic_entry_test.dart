import 'package:flutter/material.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmospheric_background.dart';
import 'package:flutter_mort/core/atmosphere/mort_wordmark_reveal.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('classic landing is white, readable, and uses a plain CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendConnectionStatusProvider.overrideWith((ref) async => true),
        ],
        child: MaterialApp(
          theme: MortTheme.classic(),
          home: const SplashScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MORT'), findsOneWidget);
    expect(find.text('Enter MORT'), findsOneWidget);
    expect(find.byType(MortWordmarkReveal), findsNothing);
    expect(find.byType(MortAtmosphericBackground), findsNothing);
    final button = tester.widget<MortButton>(
      find.widgetWithText(MortButton, 'Enter MORT'),
    );
    expect(button.style, MortButtonStyle.primary);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
  });

  testWidgets(
    'classic welcome uses white action area and safety remains free',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: MortTheme.classic(), home: const WelcomeScreen()),
      );

      expect(find.text('Safety stays free'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
      final darkActionArea = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((box) {
            final decoration = box.decoration;
            return decoration is BoxDecoration &&
                decoration.color == Colors.black;
          });
      expect(darkActionArea, isEmpty);
    },
  );
}
