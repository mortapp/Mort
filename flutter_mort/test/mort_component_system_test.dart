import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('midnight palette uses the approved literal production values', () {
    expect(MortColors.void_, const Color(0xFF000000));
    expect(MortColors.midnight, const Color(0xFF030405));
    expect(MortColors.deepNavy, const Color(0xFF050607));
    expect(MortColors.lowerNight, const Color(0xFF080A0D));
    expect(MortColors.surface, const Color(0xFF0B0D11));
    expect(MortColors.surfaceAlternate, const Color(0xFF101218));
    expect(MortColors.surfaceRaised, const Color(0xFF14171D));
    expect(MortColors.border, const Color(0xFF1A1D23));
    expect(MortColors.borderStrong, const Color(0xFF23272F));
    expect(MortColors.cobalt, const Color(0xFFD6DAE0));
    expect(MortColors.primary, const Color(0xFFD6DAE0));
    expect(MortColors.primaryBright, const Color(0xFFE9EDF2));
    expect(MortColors.ice, const Color(0xFFF2F5F8));
    expect(MortColors.text, const Color(0xFFF7F8FA));
    expect(MortColors.textSecondary, const Color(0xFFADB2BA));
    expect(MortColors.textMuted, const Color(0xFF707680));
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
