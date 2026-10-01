import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/polaroid_frame.dart';

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.user?.email ?? '';
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: OnesColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: PolaroidFrame(
                      child: const ColoredBox(
                        color: OnesColors.yellowLight,
                        child: Center(
                          child: Icon(Icons.mark_email_unread_outlined,
                              size: 72, color: OnesColors.purpleDeep),
                        ),
                      ),
                      caption: FittedBox(
                        // Correos largos se achican para verse completos (el dominio importa).
                        fit: BoxFit.scaleDown,
                        child: Text(
                          email,
                          key: const Key('verify.email'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: OnesColors.black),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Revisa tu correo',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: OnesColors.black),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Abre el enlace que te enviamos para activar tu cuenta. Cuando vuelvas, lo detectaremos automáticamente.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                        color: OnesColors.black.withOpacity(0.75),
                        height: 1.35),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 20),
                    AuthErrorBanner(message: '${auth.error}'),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('verify.confirm'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: OnesColors.purpleMid,
                      foregroundColor: OnesColors.white,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    onPressed: auth.isLoading
                        ? null
                        : () => auth.confirmEmailVerified(),
                    child: const Text('Ya verifiqué mi correo',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('verify.resend'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      foregroundColor: OnesColors.purpleDeep,
                      side: const BorderSide(
                          color: OnesColors.purpleDeep, width: 1.5),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final ok = await auth.resendEmailVerification();
                            if (ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Te enviamos un nuevo enlace a $email.')),
                              );
                            }
                          },
                    child: const Text('Reenviar enlace',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('verify.logout'),
                    onPressed: auth.isLoading ? null : () => auth.logout(),
                    child: const Text(
                      'Usar otra cuenta',
                      style: TextStyle(
                          color: OnesColors.purpleDeep,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
