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
    this.borderRadius = BorderRadius.zero,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? OnesColors.white,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}
