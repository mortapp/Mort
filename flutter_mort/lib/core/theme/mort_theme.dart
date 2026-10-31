import 'package:flutter/material.dart';

import 'mort_colors.dart';
import 'mort_spacing.dart';
import 'mort_tokens.dart';
import 'mort_typography.dart';
import '../routing/mort_page_transitions.dart';

class MortTheme {
  const MortTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? MortColors.darkBackground
        : MortColors.lightBackground;
    final surface = isDark ? MortColors.darkSurface : MortColors.lightSurface;
    final surfaceAlt = isDark
        ? MortColors.darkSurfaceAlt
        : MortColors.lightSurfaceAlt;
    final raised = isDark
        ? MortColors.bgElevated
        : MortColors.lightSurfaceRaised;
    final text = isDark ? MortColors.darkText : MortColors.lightText;
    final textSoft = isDark
        ? MortColors.darkTextSoft
        : MortColors.lightTextSoft;
    final muted = isDark ? MortColors.darkTextMuted : MortColors.lightTextMuted;
    final line = isDark ? MortColors.line : MortColors.lightLine;
    final primary = isDark ? MortColors.silverBright : MortColors.lightText;
    final primaryOn = isDark ? MortColors.darkBackground : Colors.white;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: primaryOn,
      secondary: isDark ? MortColors.silver : MortColors.silverDark,
      onSecondary: isDark ? MortColors.darkBackground : Colors.white,
      error: isDark ? MortColors.danger : const Color(0xFFB4232A),
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      primaryContainer: isDark ? MortColors.lineStrong : raised,
      onPrimaryContainer: text,
      secondaryContainer: isDark
          ? MortColors.graphite4
          : MortColors.lightSurfaceAlt,
      onSecondaryContainer: textSoft,
      surfaceContainerLowest: background,
      surfaceContainerLow: isDark ? MortColors.black : surface,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: isDark
          ? MortColors.bgElevated
          : const Color(0xFFDEDEDA),
      outline: isDark ? MortColors.lineStrong : const Color(0xFF999995),
      outlineVariant: line,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: text,
      onInverseSurface: background,
      inversePrimary: isDark ? MortColors.silverDark : MortColors.silverBright,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: MortTypography.textTheme(brightness),
      fontFamily: 'Roboto',
      focusColor: primary.withValues(alpha: 0.28),
      hoverColor: primary.withValues(alpha: 0.07),
      highlightColor: primary.withValues(alpha: 0.07),
      splashColor: primary.withValues(alpha: 0.1),
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: MortPageTransitions.theme,
      iconTheme: IconThemeData(color: textSoft, size: MortIconSizes.standard),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? MortColors.glass : surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MortSpacing.md,
          vertical: MortSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: MortColors.danger),
        ),
        labelStyle: TextStyle(color: textSoft),
        hintStyle: TextStyle(color: muted),
        prefixIconColor: textSoft,
        suffixIconColor: textSoft,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            MortSpacing.minTouchTarget,
            MortSpacing.fieldHeight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MortRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? MortColors.glass : surfaceAlt,
        selectedColor: isDark ? MortColors.silverDark : MortColors.silver,
        disabledColor: raised,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MortRadii.pill),
        ),
        labelStyle: TextStyle(color: textSoft),
        secondaryLabelStyle: TextStyle(color: text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: MortSpacing.navigationHeight,
        backgroundColor: raised,
        indicatorColor: primary.withValues(alpha: isDark ? 0.18 : 0.14),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? primary : muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: isDark ? MortColors.lineStrong : line),
          borderRadius: BorderRadius.circular(MortRadii.sheet),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: line,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.24),
        selectionHandleColor: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? MortColors.cardAlt : surfaceAlt,
        contentTextStyle: TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: raised,
        modalBackgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MortRadii.sheet),
          ),
        ),
      ),
    );
  }
}
