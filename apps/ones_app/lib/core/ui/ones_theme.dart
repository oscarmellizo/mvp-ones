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
      scaffoldBackgroundColor: OnesColors.surfaceWarm,
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
        fontFamily: OnesTypography.lemonMilk,
        fontWeight: FontWeight.w500,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: OnesTypography.lemonMilk,
        fontWeight: FontWeight.w500,
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
        backgroundColor: OnesColors.surfaceWarm,
        foregroundColor: OnesColors.purpleDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: OnesColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: OnesColors.black.withOpacity(0.06)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: OnesColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: OnesColors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: OnesColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OnesColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(
          fontFamilyFallback: OnesTypography.bodyFallbacks,
          color: OnesColors.inkSoft.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: OnesColors.black.withOpacity(0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: OnesColors.black.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: const BorderSide(color: OnesColors.purpleMid, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: const BorderSide(color: OnesColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: const BorderSide(color: OnesColors.danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: OnesColors.purpleMid,
          foregroundColor: OnesColors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OnesColors.purpleMid,
          foregroundColor: OnesColors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OnesColors.purpleMid,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: OnesColors.purpleMid.withOpacity(0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: OnesColors.black.withOpacity(0.08)),
        selectedColor: OnesColors.purpleMid.withOpacity(0.12),
        backgroundColor: OnesColors.white,
        labelStyle: const TextStyle(color: OnesColors.black),
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
