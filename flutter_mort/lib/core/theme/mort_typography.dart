import 'package:flutter/material.dart';

import 'mort_colors.dart';

class MortTypography {
  const MortTypography._();

  /// Ceremonial display treatment used for hero moments (Welcome, Dashboard
  /// identity, Leaderboard, Profile rank, section-of-honor headings) --
  /// wider letter-spacing and weight stand in for a dedicated display
  /// serif, avoiding a new font dependency's build/licensing risk while
  /// this rebrand touches this many files in one pass.
  static const ceremonialLetterSpacing = 0.6;

  static TextTheme textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(
        color: MortColors.text,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: ceremonialLetterSpacing,
      ),
      headlineMedium: TextStyle(
        color: MortColors.text,
        fontSize: 27,
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: ceremonialLetterSpacing,
      ),
      headlineSmall: TextStyle(
        color: MortColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.4,
      ),
      titleLarge: TextStyle(
        color: MortColors.text,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
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
        color: MortColors.textSoft,
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
        letterSpacing: 0.8,
      ),
    );
  }
}
