import 'package:flutter/material.dart';

import '../ones_colors.dart';
import '../ones_typography.dart';

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
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
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
      decoration: InputDecoration(
        prefixIcon: prefixIcon ?? const Icon(Icons.search),
        hintText: hintText,
        filled: true,
        fillColor: OnesColors.white,
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide.none,
        ),
        contentPadding: contentPadding,
      ),
    );
  }
}
