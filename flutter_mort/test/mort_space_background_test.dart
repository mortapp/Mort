import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_space_background.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared screen background is flat and preserves content', (
    tester,
  ) async {
    await tester.pumpWidget(_host(seed: 7));

    expect(find.byType(MortSpaceBackground), findsOneWidget);
    expect(find.text('Production screen'), findsOneWidget);
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byType(MortSpaceBackground),
              matching: find.byType(ColoredBox),
            ),
          )
          .color,
      MortTheme.light().scaffoldBackgroundColor,
    );
  });

  testWidgets('flat screen background does not animate', (tester) async {
    await tester.pumpWidget(_host(seed: 7, disableAnimations: true));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

Widget _host({required int seed, bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: disableAnimations,
    ),
    child: MaterialApp(
      theme: MortTheme.light(),
      home: MortSpaceBackground(
        seed: seed,
        child: const Center(child: Text('Production screen')),
      ),
    ),
  );
}
