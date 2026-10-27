import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortTypography {
  const MortTypography._();

  static TextTheme textTheme([Brightness brightness = Brightness.dark]) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? MortColors.darkText : MortColors.lightText;
    final secondary = dark ? MortColors.darkTextSoft : MortColors.lightTextSoft;
    final muted = dark ? MortColors.darkTextMuted : MortColors.lightTextMuted;
    return TextTheme(
      displayLarge: TextStyle(
        color: primary,
        fontSize: 45,
        fontWeight: FontWeight.w300,
        height: 1.02,
      ),
      displayMedium: TextStyle(
        color: primary,
        fontSize: 40,
        fontWeight: FontWeight.w300,
        height: 1.04,
      ),
      displaySmall: TextStyle(
        color: primary,
        fontSize: 34,
        fontWeight: FontWeight.w300,
        height: 1.05,
      ),
      headlineLarge: TextStyle(
        color: primary,
        fontSize: 30,
        fontWeight: FontWeight.w300,
        height: 1.08,
      ),
      headlineMedium: TextStyle(
        color: primary,
        fontSize: 27,
        fontWeight: FontWeight.w300,
        height: 1.12,
      ),
      headlineSmall: TextStyle(
        color: primary,
        fontSize: 22,
        fontWeight: FontWeight.w300,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        color: primary,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: secondary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: secondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: secondary,
        fontSize: 15,
        fontWeight: FontWeight.w300,
        height: 1.42,
      ),
      bodyMedium: TextStyle(
        color: secondary,
        fontSize: 14,
        fontWeight: FontWeight.w300,
        height: 1.38,
      ),
      bodySmall: TextStyle(
        color: muted,
        fontSize: 13,
        fontWeight: FontWeight.w300,
        height: 1.38,
      ),
      labelLarge: TextStyle(
        color: primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        color: muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
