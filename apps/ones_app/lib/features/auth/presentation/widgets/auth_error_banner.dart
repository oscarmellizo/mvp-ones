import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';

/// Texto negro sobre blanco con barra roja: el rojo directo sobre ámbar no se lee bien.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: OnesColors.white.withOpacity(0.8),
          border: const Border(left: BorderSide(color: OnesColors.danger, width: 4)),
        ),
        child: Text(
          message,
          style: const TextStyle(color: OnesColors.black, fontWeight: FontWeight.w600, height: 1.3),
        ),
      ),
    );
  }
}
