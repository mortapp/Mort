import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortTypography {
  const MortTypography._();

  static TextTheme textTheme({Brightness brightness = Brightness.light}) {
    final ink = brightness == Brightness.light
        ? MortColors.black
        : MortColors.white;
    final secondaryInk = brightness == Brightness.light
        ? MortColors.gray8
        : MortColors.gray3;
    final mutedInk = brightness == Brightness.light
        ? MortColors.gray7
        : MortColors.gray5;
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Instrument Sans',
        color: ink,
        fontSize: 45,
        fontWeight: FontWeight.w300,
        height: 1.02,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Instrument Sans',
        color: ink,
        fontSize: 40,
        fontWeight: FontWeight.w300,
        height: 1.04,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Instrument Sans',
        color: ink,
        fontSize: 34,
        fontWeight: FontWeight.w300,
        height: 1.05,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Instrument Sans',
        color: ink,
        fontSize: 30,
        fontWeight: FontWeight.w300,
        height: 1.08,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Instrument Sans',
        color: ink,
        fontSize: 27,
        fontWeight: FontWeight.w300,
        height: 1.12,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Instrument Sans',
        color: ink,
        fontSize: 22,
        fontWeight: FontWeight.w300,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Instrument Sans',
        color: ink,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: secondaryInk,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: secondaryInk,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: secondaryInk,
        fontSize: 15,
        fontWeight: FontWeight.w300,
        height: 1.42,
      ),
      bodyMedium: TextStyle(
        color: secondaryInk,
        fontSize: 14,
        fontWeight: FontWeight.w300,
        height: 1.38,
      ),
      bodySmall: TextStyle(
        color: mutedInk,
        fontSize: 13,
        fontWeight: FontWeight.w300,
        height: 1.38,
      ),
      labelLarge: TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: mutedInk,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        color: mutedInk,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
