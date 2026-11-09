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
    final canvas = isDark ? const Color(0xFF101010) : MortColors.white;
    final surface = isDark ? const Color(0xFF181818) : MortColors.white;
    final raised = isDark ? const Color(0xFF222222) : MortColors.gray0;
    final ink = isDark ? MortColors.white : MortColors.black;
    final secondaryInk = isDark ? MortColors.gray3 : MortColors.gray8;
    final mutedInk = isDark ? MortColors.gray5 : MortColors.gray7;
    final rule = isDark ? const Color(0xFF383838) : MortColors.gray2;
    final strongRule = isDark ? const Color(0xFF505050) : MortColors.gray3;
    final primary = isDark ? MortColors.white : MortColors.black;
    final onPrimary = isDark ? MortColors.black : MortColors.white;

    final colorScheme =
        ColorScheme(
          brightness: brightness,
          primary: primary,
          onPrimary: onPrimary,
          secondary: mutedInk,
          onSecondary: onPrimary,
          error: MortColors.danger,
          onError: MortColors.white,
          surface: surface,
          onSurface: ink,
        ).copyWith(
          primaryContainer: raised,
          onPrimaryContainer: ink,
          secondaryContainer: raised,
          onSecondaryContainer: secondaryInk,
          surfaceContainerLowest: canvas,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: raised,
          surfaceContainerHighest: raised,
          outline: strongRule,
          outlineVariant: rule,
          shadow: Colors.transparent,
          scrim: Colors.black54,
          inverseSurface: ink,
          onInverseSurface: canvas,
          inversePrimary: isDark ? MortColors.black : MortColors.white,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      textTheme: MortTypography.textTheme(brightness: brightness),
      fontFamily: 'Inter',
      focusColor: mutedInk.withValues(alpha: 0.18),
      hoverColor: mutedInk.withValues(alpha: 0.08),
      highlightColor: mutedInk.withValues(alpha: 0.08),
      splashColor: mutedInk.withValues(alpha: 0.1),
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: MortPageTransitions.theme,
      iconTheme: IconThemeData(
        color: secondaryInk,
        size: MortIconSizes.standard,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: MortTypography.textTheme(
          brightness: brightness,
        ).titleMedium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MortSpacing.md,
          vertical: MortSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: BorderSide(color: rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: BorderSide(color: rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
          borderSide: const BorderSide(color: MortColors.danger),
        ),
        labelStyle: TextStyle(color: secondaryInk),
        hintStyle: TextStyle(color: mutedInk),
        prefixIconColor: mutedInk,
        suffixIconColor: secondaryInk,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            MortSpacing.minTouchTarget,
            MortSpacing.fieldHeight,
          ),
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MortRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        selectedColor: isDark ? const Color(0xFF333333) : MortColors.gray1,
        disabledColor: canvas,
        side: BorderSide(color: rule),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MortRadii.pill),
        ),
        labelStyle: TextStyle(color: secondaryInk),
        secondaryLabelStyle: TextStyle(color: ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: MortSpacing.navigationHeight,
        backgroundColor: surface,
        indicatorColor: raised,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? ink : mutedInk,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? ink : mutedInk,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: rule),
          borderRadius: BorderRadius.circular(MortRadii.sheet),
        ),
      ),
      dividerTheme: DividerThemeData(color: rule, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: rule,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: mutedInk.withValues(alpha: 0.28),
        selectionHandleColor: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: raised,
        contentTextStyle: TextStyle(color: ink),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MortRadii.sheet),
          ),
        ),
      ),
    );
  }
}
