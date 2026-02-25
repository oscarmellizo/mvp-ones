import 'package:flutter/material.dart';

import 'ones_colors.dart';

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
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900),
      displayMedium: base.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900),
      displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      labelSmall: base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
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
