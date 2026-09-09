import 'package:flutter/material.dart';

import 'mort_colors.dart';
import 'mort_spacing.dart';
import 'mort_tokens.dart';
import 'mort_typography.dart';
import '../routing/mort_page_transitions.dart';

class MortTheme {
  const MortTheme._();

  static ThemeData dark() {
    final colorScheme =
        const ColorScheme(
          brightness: Brightness.dark,
          primary: MortColors.accent,
          onPrimary: MortColors.bg,
          secondary: MortColors.lightBlue,
          onSecondary: MortColors.bg,
          error: MortColors.dangerDeep,
          onError: MortColors.white,
          surface: MortColors.card,
          onSurface: MortColors.text,
        ).copyWith(
          primaryContainer: MortColors.lineStrong,
          onPrimaryContainer: MortColors.text,
          secondaryContainer: MortColors.lightBlueDeep,
          onSecondaryContainer: MortColors.lightBlueSoft,
          surfaceContainerLowest: MortColors.bg,
          surfaceContainerLow: MortColors.black,
          surfaceContainer: MortColors.card,
          surfaceContainerHigh: MortColors.raisedBlack,
          surfaceContainerHighest: MortColors.bgElevated,
          outline: MortColors.lineStrong,
          outlineVariant: MortColors.line,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: MortColors.text,
          onInverseSurface: MortColors.bg,
          inversePrimary: MortColors.silverDark,
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
      highlightColor: MortColors.accent.withValues(alpha: 0.08),
      splashColor: MortColors.accent.withValues(alpha: 0.12),
      splashFactory: InkRipple.splashFactory,
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
          borderSide: const BorderSide(color: MortColors.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: MortColors.danger),
        ),
        labelStyle: const TextStyle(color: MortColors.textSoft),
        hintStyle: const TextStyle(color: MortColors.textMuted),
        prefixIconColor: MortColors.accent,
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
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MortColors.glass,
        selectedColor: MortColors.silverDark,
        disabledColor: MortColors.bgElevated,
        side: const BorderSide(color: MortColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MortRadii.pill),
        ),
        labelStyle: const TextStyle(color: MortColors.textSoft),
        secondaryLabelStyle: const TextStyle(color: MortColors.accent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: MortSpacing.navigationHeight,
        backgroundColor: MortColors.bgElevated.withValues(alpha: 0.94),
        indicatorColor: MortColors.accent.withValues(alpha: 0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? MortColors.accent
                : MortColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? MortColors.accent
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
        color: MortColors.accent,
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
