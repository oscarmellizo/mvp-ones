import 'package:flutter/material.dart';

import '../ones_colors.dart';
import '../ones_typography.dart';
import 'ones_input_decoration.dart';

class OnesSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final void Function(String value)? onChanged;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final Widget? prefixIcon;

  const OnesSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.borderRadius = BorderRadius.zero,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamilyFallback: OnesTypography.bodyFallbacks,
        color: OnesColors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: OnesInputDecoration.build(
        hintText: hintText,
        prefixIcon: prefixIcon ?? const Icon(Icons.search),
        fillColor: OnesColors.white,
        borderSide: BorderSide.none,
        contentPadding: contentPadding,
        borderRadius: borderRadius,
      ),
    );
  }
}
