import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';
import '../auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/email_auth_section.dart';
import '../widgets/polaroid_frame.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  String? _sentTo;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await context.read<AuthController>().sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) _sentTo = email;
    });
  }

  ButtonStyle get _primary => FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: OnesColors.purpleMid,
        foregroundColor: OnesColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      );

  @override
  Widget build(BuildContext context) {
    final error = context.watch<AuthController>().error;
    final text = Theme.of(context).textTheme;
    final body = text.bodyMedium
        ?.copyWith(color: OnesColors.black.withOpacity(0.75), height: 1.35);

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: _sentTo != null
                  ? Column(
                      key: const Key('forgot.sent'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: PolaroidFrame(
                            angle: 0.03,
                            child: const ColoredBox(
                              color: OnesColors.yellowLight,
                              child: Center(
                                  child: Icon(Icons.lock_reset,
                                      size: 72, color: OnesColors.purpleDeep)),
                            ),
                            caption: FittedBox(
                              // Correos largos se achican para verse completos (el dominio importa).
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _sentTo!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: OnesColors.black),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('Revisa tu correo',
                            textAlign: TextAlign.center,
                            style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: OnesColors.black)),
                        const SizedBox(height: 10),
                        Text(
                          'Si hay una cuenta con ese correo, te llegará un enlace para crear una contraseña nueva.',
                          textAlign: TextAlign.center,
                          style: body,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('forgot.back'),
                          style: _primary,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Volver a iniciar sesión',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una contraseña nueva.',
                          style: body,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          key: const Key('forgot.email'),
                          controller: _email,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(
                            fontFamilyFallback: OnesTypography.bodyFallbacks,
                            color: OnesColors.black,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: authFieldDecoration(
                              hintText: 'Correo', icon: Icons.mail_outline),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          AuthErrorBanner(message: '$error'),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('forgot.send'),
                          style: _primary,
                          onPressed: _sending ? null : _send,
                          child: Text(
                              _sending ? 'Enviando...' : 'Enviar enlace',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
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
