import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';

/// Sign in with Apple solo se ofrece en iOS.
bool get appleSignInAvailable => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Botón de método de acceso: todos comparten alto, ancho y esquinas rectas;
/// solo cambian fondo, borde y logo.
class AuthOptionButton extends StatelessWidget {
  final Widget logo;
  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Color border;

  const AuthOptionButton({
    super.key,
    required this.logo,
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground.withOpacity(0.5),
        side: BorderSide(color: border, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(
          fontFamilyFallback: OnesTypography.bodyFallbacks,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(child: SizedBox.square(dimension: 24, child: Center(child: logo))),
          const SizedBox(width: 12),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;

  const GoogleSignInButton({super.key, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AuthOptionButton(
      key: const Key('auth.google'),
      // Logo oficial sin modificar; borde y colores según las guías de marca de Google.
      logo: Image.asset('assets/auth/google_g.png', width: 20, height: 20, filterQuality: FilterQuality.medium),
      label: busy ? 'Conectando...' : 'Continuar con Google',
      onPressed: onPressed,
      background: OnesColors.white,
      foreground: const Color(0xFF1F1F1F),
      border: const Color(0xFF747775),
    );
  }
}

class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppleSignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AuthOptionButton(
      key: const Key('auth.apple'),
      // Logo oficial de Apple (no el ícono de Material): lo exige la guía de Sign in with Apple.
      logo: Image.asset('assets/auth/apple_logo.png', width: 20, height: 24, filterQuality: FilterQuality.medium),
      label: 'Continuar con Apple',
      onPressed: onPressed,
      background: OnesColors.black,
      foreground: OnesColors.white,
      border: OnesColors.black,
    );
  }
}
