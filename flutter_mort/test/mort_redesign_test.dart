import 'package:flutter/material.dart';
import 'package:flutter_mort/core/atmosphere/mort_wordmark_reveal.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/core/widgets/mort_motion_mark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('brand mark and safety glass render with centralized colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MortTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              MortBrandMark(size: 64, showWordmark: true),
              MortGlassCard(
                infoAccent: true,
                child: Text('Safety and location status'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The wordmark is written by MortWordmarkReveal's handwriting
    // animation, not a static "M O R T" Text widget -- see mort_brand.dart.
    expect(find.byType(MortWordmarkReveal), findsOneWidget);
    expect(find.text('Safety and location status'), findsOneWidget);
    expect(find.byType(MortMotionMark), findsOneWidget);
    // Black/graphite/silver identity -- MortColors.roseGold/lightBlue are
    // legacy compatibility aliases that now resolve to the silver palette
    // (no rose gold, no bright cobalt-first UI).
    expect(MortColors.roseGold, const Color(0xFFD6DAE0));
    expect(MortColors.lightBlue, const Color(0xFFE9EDF2));
  });

  testWidgets('core controls honor reduced motion and remain focus visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: const Scaffold(
            body: MortButton(label: 'Continue', onPressed: _noop),
          ),
        ),
      ),
    );

    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.duration, Duration.zero);
    expect(MortTheme.dark().focusColor, isNot(Colors.transparent));
  });

  testWidgets('PIN and money controls survive narrow large-text layouts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 1200),
          textScaler: TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 280,
                child: Column(
                  children: [
                    MortPriceDisplay(
                      label: 'Estimated teen payout',
                      formattedAmount: r'$1,234.56',
                      emphasized: true,
                    ),
                    MortJobCard(
                      title: 'Neighborhood lawn and garden cleanup',
                      category: 'Yard work',
                      area: 'Nearby area',
                      payout: r'$25.00',
                      onTap: _noop,
                      onSaved: _noop,
                    ),
                    MortPinPad(value: '123', onChanged: _ignore),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

void _ignore(String _) {}
