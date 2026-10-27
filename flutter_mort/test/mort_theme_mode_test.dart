import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MORT provides legible monochrome light and dark themes', () {
    final light = MortTheme.light();
    final dark = MortTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
    expect(
      light.textTheme.titleLarge?.color,
      isNot(dark.textTheme.titleLarge?.color),
    );
    expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
    expect(light.textTheme.bodyMedium?.color, MortColors.lightTextSoft);
    expect(light.colorScheme.primary.computeLuminance(), lessThan(0.02));
    expect(dark.colorScheme.primary.computeLuminance(), lessThan(0.9));
  });
}
