import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortTypography {
  const MortTypography._();

  static TextTheme textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(
        color: MortColors.text,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
      headlineMedium: TextStyle(
        color: MortColors.text,
        fontSize: 27,
        fontWeight: FontWeight.w800,
        height: 1.12,
      ),
      headlineSmall: TextStyle(
        color: MortColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        color: MortColors.text,
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: MortColors.textSoft,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: MortColors.textSoft,
        fontSize: 16,
        height: 1.42,
      ),
      bodyMedium: TextStyle(
        color: MortColors.textMuted,
        fontSize: 14,
        height: 1.38,
      ),
      labelLarge: TextStyle(
        color: MortColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        color: MortColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
