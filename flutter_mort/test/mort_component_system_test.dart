import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy component tokens resolve to the neutral classic palette', () {
    expect(MortColors.void_, const Color(0xFF000000));
    expect(MortColors.midnight, MortClassicColors.ink);
    expect(MortColors.deepNavy, MortClassicColors.ink);
    for (final ink in [
      MortColors.cobalt,
      MortColors.primary,
      MortColors.primaryBright,
      MortColors.text,
    ]) {
      expect(ink, MortClassicColors.foreground);
    }
    expect(MortColors.lowerNight, MortClassicColors.surface);
    expect(MortColors.surface, MortClassicColors.surface);
    expect(MortColors.surfaceAlternate, const Color(0xFF222222));
    expect(MortColors.surfaceRaised, MortClassicColors.silverSurface);
    expect(MortColors.border, MortClassicColors.line);
    expect(MortColors.borderStrong, MortClassicColors.strongLine);
    expect(MortColors.ice, const Color(0xFFF5F5F5));
    expect(MortColors.textSecondary, MortClassicColors.muted);
    expect(MortColors.textMuted, MortClassicColors.subtle);
  });

  testWidgets('primary and secondary actions retain 48dp touch targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            MortPrimaryButton(label: 'Continue', onPressed: () {}),
            MortSecondaryButton(label: 'Not now', onPressed: () {}),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.text('Continue')).height, lessThan(48));
    expect(
      tester.getSize(find.widgetWithText(ElevatedButton, 'Continue')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.widgetWithText(ElevatedButton, 'Not now')).height,
      greaterThanOrEqualTo(48),
    );
  });
}
