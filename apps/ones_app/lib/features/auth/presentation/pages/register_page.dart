import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_text_field.dart';
import '../auth_controller.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/email_auth_section.dart';
import 'legal_markdown_page.dart';

class RegisterPage extends StatefulWidget {
  final bool popToRootOnComplete;

  const RegisterPage({
    super.key,
    this.popToRootOnComplete = true,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _preferredNameController =
      TextEditingController();
  bool _showValidation = false;
  bool _termsAccepted = false;
  AuthController? _authController;

  Future<void> _startWith(Future<AuthNextStep> Function() action) async {
    final auth = context.read<AuthController>();
    final step = await action();
    if (!mounted) return;
    switch (step) {
      case AuthNextStep.failed:
        return;
      case AuthNextStep.signedIn:
      case AuthNextStep.needsEmailVerification:
        // La raíz (Home o VerifyEmailPage) toma el control.
        if (widget.popToRootOnComplete) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      case AuthNextStep.needsRegistration:
        final seed = auth.preferredName ?? _guessPreferredName(auth.user?.displayName);
        setState(() {
          _showValidation = false;
          if (_preferredNameController.text.trim().isEmpty && seed != null && seed.trim().isNotEmpty) {
            _preferredNameController.text = seed.trim();
          }
        });
    }
  }

  @override
  void initState() {
    super.initState();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      _authController = auth;
      auth.addListener(_onAuthChanged);
      _maybeSeedPreferredName(auth);
    });
  }

  @override
  void dispose() {
    _authController?.removeListener(_onAuthChanged);
    _preferredNameController.dispose();
    super.dispose();
  }

  void _maybeSeedPreferredName(AuthController auth) {
    if (_preferredNameController.text.trim().isNotEmpty) return;
    final seed =
        auth.preferredName ?? _guessPreferredName(auth.user?.displayName);
    if (seed != null && seed.trim().isNotEmpty) {
      _preferredNameController.text = seed.trim();
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = _authController;
    if (auth == null) return;
    if (_preferredNameController.text.trim().isEmpty) {
      _maybeSeedPreferredName(auth);
    }
  }

  String? _guessPreferredName(String? displayName) {
    if (displayName == null) return null;
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    return parts.first;
  }

  ({String firstName, String lastName}) _splitDisplayName(String? displayName) {
    final safe = (displayName ?? '').trim();
    if (safe.isEmpty) {
      return (firstName: '', lastName: '');
    }

    final parts =
        safe.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty) {
      return (firstName: '', lastName: '');
    }
    if (parts.length == 1) {
      return (firstName: parts.first, lastName: '');
    }
    return (firstName: parts.first, lastName: parts.sublist(1).join(' '));
  }

  String? _preferredNameError() {
    if (!_showValidation) return null;
    if (_preferredNameController.text.trim().isEmpty) {
      return 'El nombre preferido es obligatorio.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 520 ? 32.0 : 20.0;

    final user = auth.user;
    final split = _splitDisplayName(user?.displayName);
    final email = user?.email ?? '';
    final preferredNameError = _preferredNameError();

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        elevation: 0,
        foregroundColor: OnesColors.black,
        title: const Text('Crea tu cuenta'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Registro',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: OnesColors.black,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Elige cómo quieres crear tu cuenta en Ones.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: OnesColors.black.withOpacity(0.7),
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 20),
                  if (auth.error != null) ...[
                    AuthErrorBanner(message: '${auth.error}'),
                    const SizedBox(height: 16),
                  ],
                  OnesCard(
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (user == null) ...[
                          GoogleSignInButton(
                            busy: auth.isLoading,
                            onPressed: auth.isLoading ? null : () => _startWith(auth.beginRegistration),
                          ),
                          if (appleSignInAvailable) ...[
                            const SizedBox(height: 12),
                            AppleSignInButton(
                              onPressed: auth.isLoading ? null : () => _startWith(auth.beginRegistrationWithApple),
                            ),
                          ],
                          const SizedBox(height: 12),
                          EmailAuthSection(
                            toggleLabel: 'Crear cuenta con correo',
                            submitLabel: 'Crear cuenta',
                            busy: auth.isLoading,
                            isRegistration: true,
                            fieldFill: OnesColors.black.withOpacity(0.04),
                            onSubmit: (email, password) => _startWith(() => auth.registerWithEmail(email, password)),
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: OnesColors.yellowLight,
                                backgroundImage: (user.pictureUrl != null &&
                                        user.pictureUrl!.trim().isNotEmpty)
                                    ? NetworkImage(user.pictureUrl!)
                                    : null,
                                child: (user.pictureUrl == null ||
                                        user.pictureUrl!.trim().isEmpty)
                                    ? const Icon(Icons.person,
                                        color: OnesColors.black)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: OnesColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (split.firstName.isNotEmpty)
                                      Text(
                                        'Nombre: ${split.firstName}',
                                        style: TextStyle(
                                          color: OnesColors.black
                                              .withOpacity(0.70),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    if (split.lastName.isNotEmpty)
                                      Text(
                                        'Apellido: ${split.lastName}',
                                        style: TextStyle(
                                          color: OnesColors.black
                                              .withOpacity(0.70),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Nombre preferido',
                            style: TextStyle(
                              color: OnesColors.black,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          OnesTextField(
                            controller: _preferredNameController,
                            hintText: 'Nombre preferido',
                            fillColor: OnesColors.yellowLight.withOpacity(0.35),
                            borderSide: BorderSide.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            onChanged: (_) {
                              if (_showValidation) setState(() {});
                            },
                            textInputAction: TextInputAction.done,
                          ),
                          if (preferredNameError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              preferredNameError,
                              style: const TextStyle(
                                color: OnesColors.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                              'Este nombre se usa para identificar tus fotos.',
                              style: TextStyle(
                                color: OnesColors.black.withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _termsAccepted,
                                onChanged: auth.isLoading
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _termsAccepted = value ?? false;
                                        });
                                      },
                                activeColor: OnesColors.purpleMid,
                                side: const BorderSide(
                                  color: OnesColors.black,
                                  width: 1.5,
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: auth.isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _termsAccepted = !_termsAccepted;
                                          });
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'He leído y acepto los ',
                                        style: TextStyle(
                                          color: OnesColors.black
                                              .withOpacity(0.75),
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Términos y condiciones',
                                            style: const TextStyle(
                                              color: OnesColors.purpleDeep,
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            recognizer:
                                                TapGestureRecognizer()
                                                  ..onTap = () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const LegalMarkdownPage(
                                                          title:
                                                              'Términos y privacidad',
                                                          assetPath:
                                                              'assets/legal/terms_and_privacy.md',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                          ),
                                          const TextSpan(
                                              text: ' y la '),
                                          TextSpan(
                                            text: 'Política de privacidad',
                                            style: const TextStyle(
                                              color: OnesColors.purpleDeep,
                                              fontWeight: FontWeight.w700,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            recognizer:
                                                TapGestureRecognizer()
                                                  ..onTap = () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const LegalMarkdownPage(
                                                          title:
                                                              'Términos y privacidad',
                                                          assetPath:
                                                              'assets/legal/terms_and_privacy.md',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                          ),
                                          const TextSpan(text: '.'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: OnesColors.purpleMid,
                                foregroundColor: OnesColors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              onPressed: auth.isLoading || !_termsAccepted
                                  ? null
                                  : () async {
                                      setState(() {
                                        _showValidation = true;
                                      });
                                      if (_preferredNameController.text
                                          .trim()
                                          .isEmpty) {
                                        return;
                                      }

                                      FocusScope.of(context).unfocus();
                                      try {
                                        await auth.completeRegistration(
                                          _preferredNameController.text,
                                          termsAccepted: _termsAccepted,
                                        );
                                        if (!context.mounted) return;
                                        if (widget.popToRootOnComplete) {
                                          Navigator.of(context)
                                              .popUntil((r) => r.isFirst);
                                        } else {
                                          // Como raíz no hay a dónde volver: el router lleva al Home.
                                          Navigator.of(context).maybePop(true);
                                        }
                                      } catch (_) {
                                        if (!context.mounted) return;
                                      }
                                    },
                              child: Text(
                                auth.isLoading
                                    ? 'Creando cuenta...'
                                    : 'Crear cuenta',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          if (!widget.popToRootOnComplete) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              key: const Key('register.logout'),
                              onPressed: auth.isLoading ? null : () => auth.logout(),
                              child: const Text(
                                'Usar otra cuenta',
                                style: TextStyle(color: OnesColors.purpleDeep, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ],
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
