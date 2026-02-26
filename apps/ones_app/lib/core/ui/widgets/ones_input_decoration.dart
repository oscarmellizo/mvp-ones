import 'package:flutter/material.dart';

import '../ones_colors.dart';
import '../ones_typography.dart';

class OnesInputDecoration {
  const OnesInputDecoration._();

  static InputDecoration build({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
    Color? fillColor,
    BorderSide? borderSide,
    BorderRadiusGeometry? borderRadius,
  }) {
    final side =
        borderSide ?? BorderSide(color: OnesColors.black.withOpacity(0.12));
    final baseBorder = OutlineInputBorder(
      borderRadius: borderRadius ?? BorderRadius.zero,
      borderSide: side,
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontFamilyFallback: OnesTypography.bodyFallbacks,
        color: OnesColors.black.withOpacity(0.38),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor ?? OnesColors.black.withOpacity(0.04),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: OnesColors.purpleMid, width: 1.6),
      ),
      contentPadding: contentPadding,
    );
  }
}
