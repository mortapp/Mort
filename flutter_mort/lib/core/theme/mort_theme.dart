import 'package:flutter/material.dart';

import 'mort_colors.dart';
import 'mort_spacing.dart';
import 'mort_tokens.dart';
import 'mort_typography.dart';
import '../routing/mort_page_transitions.dart';

class MortTheme {
  const MortTheme._();

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: MortColors.royalBlue,
      primary: MortColors.royalBlue,
      onPrimary: MortColors.text,
      secondary: MortColors.imperialPurple,
      onSecondary: MortColors.text,
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
      focusColor: MortColors.royalBlueSoft.withValues(alpha: 0.36),
      hoverColor: MortColors.royalBlueSoft.withValues(alpha: 0.08),
      highlightColor: MortColors.royalBlue.withValues(alpha: 0.08),
      splashColor: MortColors.imperialPurple.withValues(alpha: 0.12),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: MortPageTransitions.theme,
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
          borderSide: const BorderSide(
            color: MortColors.royalBlueBright,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: MortColors.danger),
        ),
        labelStyle: const TextStyle(color: MortColors.textSoft),
        hintStyle: const TextStyle(color: MortColors.textMuted),
        prefixIconColor: MortColors.royalBlueBright,
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
        selectedColor: MortColors.royalBlueDeep,
        disabledColor: MortColors.bgElevated,
        side: const BorderSide(color: MortColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MortRadii.pill),
        ),
        labelStyle: const TextStyle(color: MortColors.textSoft),
        secondaryLabelStyle: const TextStyle(color: MortColors.royalBlueSoft),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: MortSpacing.navigationHeight,
        backgroundColor: MortColors.bgElevated.withValues(alpha: 0.94),
        indicatorColor: MortColors.royalBlue.withValues(alpha: 0.22),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? MortColors.royalBlueSoft
                : MortColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? MortColors.royalBlueBright
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
        color: MortColors.royalBlueBright,
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
