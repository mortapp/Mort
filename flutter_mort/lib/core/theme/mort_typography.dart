import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortTypography {
  const MortTypography._();

  static TextTheme textTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        color: MortColors.text,
        fontSize: 45,
        fontWeight: FontWeight.w300,
        height: 1.02,
      ),
      displayMedium: TextStyle(
        color: MortColors.text,
        fontSize: 40,
        fontWeight: FontWeight.w300,
        height: 1.04,
      ),
      displaySmall: TextStyle(
        color: MortColors.text,
        fontSize: 34,
        fontWeight: FontWeight.w300,
        height: 1.05,
      ),
      headlineLarge: TextStyle(
        color: MortColors.text,
        fontSize: 30,
        fontWeight: FontWeight.w300,
        height: 1.08,
      ),
      headlineMedium: TextStyle(
        color: MortColors.text,
        fontSize: 27,
        fontWeight: FontWeight.w300,
        height: 1.12,
      ),
      headlineSmall: TextStyle(
        color: MortColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w300,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        color: MortColors.text,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: MortColors.textSoft,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: MortColors.textSoft,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: MortColors.textSoft,
        fontSize: 15,
        fontWeight: FontWeight.w300,
        height: 1.42,
      ),
      bodyMedium: TextStyle(
        color: MortColors.textSoft,
        fontSize: 14,
        fontWeight: FontWeight.w300,
        height: 1.38,
      ),
      bodySmall: TextStyle(
        color: MortColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w300,
        height: 1.38,
      ),
      labelLarge: TextStyle(
        color: MortColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: MortColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        color: MortColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
