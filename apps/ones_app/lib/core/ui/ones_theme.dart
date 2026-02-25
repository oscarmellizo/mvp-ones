import 'package:flutter/material.dart';

import 'ones_colors.dart';
import 'ones_typography.dart';

class OnesTheme {
  const OnesTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: OnesColors.purpleDeep,
      onPrimary: OnesColors.white,
      secondary: OnesColors.yellow,
      onSecondary: OnesColors.purpleDark,
      error: OnesColors.danger,
      onError: OnesColors.white,
      surface: OnesColors.white,
      onSurface: OnesColors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: OnesColors.background,
      fontFamilyFallback: OnesTypography.bodyFallbacks,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        fontFamily: OnesTypography.airstrike,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
        height: 0.95,
      ),
      displayMedium: base.textTheme.displayMedium?.copyWith(
        fontFamily: OnesTypography.airstrike,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.0,
        height: 0.95,
      ),
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFamily: OnesTypography.airstrike,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.9,
        height: 0.95,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFamily: OnesTypography.airstrike,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.9,
        height: 0.95,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontFamily: OnesTypography.airstrike,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.8,
        height: 0.95,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: OnesTypography.airstrike,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.8,
        height: 0.95,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: OnesTypography.airstrike,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.8,
        height: 0.95,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontFamily: OnesTypography.lemonMilk,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontFamily: OnesTypography.lemonMilk,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge:
          base.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium:
          base.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall:
          base.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge:
          base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium:
          base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      labelSmall:
          base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: OnesColors.background,
        foregroundColor: OnesColors.purpleDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: OnesColors.purpleMid,
        foregroundColor: OnesColors.white,
      ),
      dividerTheme: DividerThemeData(
        color: OnesColors.purpleDeep.withOpacity(0.12),
      ),
    );
  }
}
