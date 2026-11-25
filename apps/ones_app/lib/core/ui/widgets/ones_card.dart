import 'package:flutter/material.dart';

import '../ones_colors.dart';

class OnesCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? color;

  const OnesCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? OnesColors.white,
        borderRadius: borderRadius,
        border: Border.all(color: OnesColors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: OnesColors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
