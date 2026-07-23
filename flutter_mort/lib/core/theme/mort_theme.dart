import 'package:flutter/material.dart';

import 'mort_colors.dart';
import 'mort_spacing.dart';
import 'mort_typography.dart';

class MortTheme {
  const MortTheme._();

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: MortColors.neon,
      primary: MortColors.neon,
      secondary: MortColors.safetyBlue,
      surface: MortColors.card,
      error: MortColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MortColors.bg,
      textTheme: MortTypography.textTheme(),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: MortColors.bg,
        foregroundColor: MortColors.text,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MortColors.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MortSpacing.md,
          vertical: MortSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MortColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MortColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MortColors.neon, width: 1.4),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: MortColors.cardAlt,
        contentTextStyle: TextStyle(color: MortColors.text),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MortColors.card,
        modalBackgroundColor: MortColors.card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
