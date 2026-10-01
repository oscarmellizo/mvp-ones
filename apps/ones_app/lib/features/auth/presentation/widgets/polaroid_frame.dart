import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';

/// Marco tipo polaroid con la misma sombra y giro que la pila de fotos del login.
class PolaroidFrame extends StatelessWidget {
  final Widget child;
  final Widget? caption;
  final double angle;
  final double width;

  const PolaroidFrame({
    super.key,
    required this.child,
    this.caption,
    this.angle = -0.035,
    this.width = 260,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        decoration: BoxDecoration(
          color: OnesColors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 28, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 4 / 3, child: child),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: caption ?? const SizedBox(height: 8),
            ),
          ],
        ),
      ),
    );
  }
}
