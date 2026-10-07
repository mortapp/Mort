import 'package:flutter/material.dart';

import 'mort_colors.dart';
import 'mort_spacing.dart';
import 'mort_tokens.dart';
import 'mort_typography.dart';
import '../routing/mort_page_transitions.dart';

class MortTheme {
  const MortTheme._();

  static ThemeData classic() {
    const ink = MortClassicColors.foreground;
    const action = MortClassicColors.action;
    const background = MortClassicColors.background;
    const muted = MortClassicColors.muted;
    const line = MortClassicColors.line;
    const surface = MortClassicColors.surface;
    const secondarySurface = MortClassicColors.surface;
    const danger = MortClassicColors.danger;
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: action,
      onPrimary: MortClassicColors.canvas,
      secondary: action,
      onSecondary: MortClassicColors.canvas,
      error: action,
      onError: MortClassicColors.canvas,
      surface: surface,
      onSurface: ink,
    );
    return ThemeData(
      useMaterial3: true,
      extensions: const [MortClassicStyle()],
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        surfaceContainerLowest: background,
        secondaryContainer: MortClassicColors.silverSurface,
        onSecondaryContainer: ink,
        onSurfaceVariant: muted,
        surfaceContainerLow: secondarySurface,
        surfaceContainer: secondarySurface,
        surfaceContainerHigh: secondarySurface,
        outline: line,
        outlineVariant: line,
      ),
      scaffoldBackgroundColor: background,
      textTheme: MortTypography.classicTextTheme().apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      fontFamily: 'Roboto',
      iconTheme: const IconThemeData(color: ink, size: MortIconSizes.standard),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: MortPageTransitions.theme,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        surfaceTintColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MortSpacing.md,
          vertical: MortSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: danger),
        ),
        labelStyle: const TextStyle(color: ink),
        hintStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
      ),
      dividerTheme: const DividerThemeData(color: line, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: action,
          foregroundColor: MortClassicColors.canvas,
          disabledBackgroundColor: secondarySurface,
          disabledForegroundColor: muted,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: action,
          foregroundColor: MortClassicColors.canvas,
          disabledBackgroundColor: secondarySurface,
          disabledForegroundColor: muted,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: MortClassicColors.strongLine),
        ),
      ),
      chipTheme: ChipThemeData(
        checkmarkColor: ink,
        backgroundColor: surface,
        selectedColor: secondarySurface,
        disabledColor: secondarySurface,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MortRadii.pill),
        ),
        labelStyle: const TextStyle(color: ink),
        secondaryLabelStyle: const TextStyle(color: ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: MortSpacing.navigationHeight,
        backgroundColor: surface,
        indicatorColor: secondarySurface,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? ink : muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? ink : muted,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ink,
        linearTrackColor: line,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ink,
        selectionColor: ink.withValues(alpha: 0.16),
        selectionHandleColor: ink,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: surface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MortRadii.card),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: action,
        contentTextStyle: TextStyle(color: MortClassicColors.canvas),
      ),
      focusColor: ink.withValues(alpha: 0.16),
      hoverColor: ink.withValues(alpha: 0.05),
      splashColor: ink.withValues(alpha: 0.08),
    );
  }

  static ThemeData dark() {
    final colorScheme =
        const ColorScheme(
          brightness: Brightness.dark,
          primary: MortColors.accent,
          onPrimary: MortColors.bg,
          secondary: MortColors.lightBlue,
          onSecondary: MortColors.bg,
          error: MortColors.dangerDeep,
          onError: MortColors.godBlack,
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
