import 'package:flutter/material.dart';

import 'mort_colors.dart';
import 'mort_spacing.dart';
import 'mort_tokens.dart';
import 'mort_typography.dart';

class MortTheme {
  const MortTheme._();

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: MortColors.roseGold,
      primary: MortColors.roseGold,
      onPrimary: MortColors.bg,
      secondary: MortColors.lightBlue,
      onSecondary: MortColors.bg,
      surface: MortColors.card,
      onSurface: MortColors.text,
      error: MortColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MortColors.bg,
      textTheme: MortTypography.textTheme(),
      fontFamily: 'Roboto',
      focusColor: MortColors.lightBlue.withValues(alpha: 0.36),
      hoverColor: MortColors.lightBlue.withValues(alpha: 0.08),
      highlightColor: MortColors.roseGold.withValues(alpha: 0.08),
      splashColor: MortColors.roseGold.withValues(alpha: 0.12),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: const IconThemeData(
        color: MortColors.textSoft,
        size: MortIconSizes.standard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: MortColors.text,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MortColors.glass,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MortSpacing.md,
          vertical: MortSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: MortColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: MortColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: MortColors.roseGold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: MortColors.danger),
        ),
        labelStyle: const TextStyle(color: MortColors.textSoft),
        hintStyle: const TextStyle(color: MortColors.textMuted),
        prefixIconColor: MortColors.roseGold,
        suffixIconColor: MortColors.textSoft,
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
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MortColors.glass,
        selectedColor: MortColors.roseGoldDeep,
        disabledColor: MortColors.bgElevated,
        side: const BorderSide(color: MortColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MortRadii.pill),
        ),
        labelStyle: const TextStyle(color: MortColors.textSoft),
        secondaryLabelStyle: const TextStyle(color: MortColors.roseGoldLight),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: MortSpacing.navigationHeight,
        backgroundColor: MortColors.bgElevated.withValues(alpha: 0.94),
        indicatorColor: MortColors.roseGold.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? MortColors.roseGoldLight
                : MortColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? MortColors.roseGold
                : MortColors.textMuted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MortColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: MortColors.lineStrong),
          borderRadius: BorderRadius.circular(MortRadii.sheet),
        ),
      ),
      dividerTheme: const DividerThemeData(color: MortColors.line, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MortColors.roseGold,
        linearTrackColor: MortColors.line,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: MortColors.lightBlue,
        selectionColor: MortColors.lightBlue.withValues(alpha: 0.32),
        selectionHandleColor: MortColors.lightBlue,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: MortColors.cardAlt,
        contentTextStyle: TextStyle(color: MortColors.text),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MortColors.bgElevated,
        modalBackgroundColor: MortColors.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MortRadii.sheet),
          ),
        ),
      ),
    );
  }
}
