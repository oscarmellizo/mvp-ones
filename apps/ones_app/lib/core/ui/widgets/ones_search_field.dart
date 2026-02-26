import 'package:flutter/material.dart';

import '../ones_colors.dart';
import '../ones_typography.dart';

class OnesSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final void Function(String value)? onChanged;

  const OnesSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
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
        prefixIcon: const Icon(Icons.search),
        hintText: hintText,
        filled: true,
        fillColor: OnesColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
