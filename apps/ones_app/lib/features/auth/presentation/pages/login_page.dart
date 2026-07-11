import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../auth_controller.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _accountNotFound = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 520 ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: OnesColors.background,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = (constraints.maxWidth * 0.90)
                          .clamp(200.0, 340.0)
                          .toDouble();
                      return Center(
                        child: Image.asset(
                          'assets/splash/symbol_purple.png',
                          width: w,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: OnesColors.black,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Capture moments, share galleries, and\nrelive the event together.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: OnesColors.black.withOpacity(0.7),
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _HeroStack(height: size.height >= 860 ? 340 : 300),
                  const SizedBox(height: 28),
                  if (_accountNotFound) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: OnesColors.yellowLight.withOpacity(0.6),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: OnesColors.purpleMid.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'No encontramos una cuenta con ese correo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: OnesColors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Crea tu cuenta primero para poder ingresar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: OnesColors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OnesColors.purpleMid,
                              foregroundColor: OnesColors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            onPressed: auth.isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _accountNotFound = false;
                                    });
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterPage(),
                                      ),
                                    );
                                  },
                            child: const Text(
                              'Crear cuenta',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _accountNotFound = false;
                              });
                            },
                            child: const Text(
                              'Intentar con otra cuenta',
                              style: TextStyle(
                                color: OnesColors.purpleDeep,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    if (auth.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: OnesColors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          'Error: ${auth.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: OnesColors.danger),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _accountNotFound = false;
                                });
                                final step = await auth.signInExisting();
                                if (!context.mounted) return;
                                if (step == AuthNextStep.needsRegistration) {
                                  setState(() {
                                    _accountNotFound = true;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OnesColors.white,
                          foregroundColor: OnesColors.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          auth.isLoading
                              ? 'Signing in...'
                              : 'Sign in with Google',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
                            },
                      child: const Text(
                        'Create an account',
                        style: TextStyle(
                          color: OnesColors.purpleDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnesColors.black.withOpacity(0.55),
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStack extends StatelessWidget {
  final double height;

  const _HeroStack({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -28,
            bottom: 12,
            child: Transform.rotate(
              angle: 0.10,
              child: Container(
                width: 240,
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.zero,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.asset(
                    'assets/auth/concierto.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 44,
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                width: 260,
                height: 210,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.asset(
                    'assets/auth/amigos.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            right: 14,
            top: 32,
            child: Opacity(
              opacity: 0.9,
              child: Icon(Icons.auto_awesome,
                  color: OnesColors.purpleDeep, size: 22),
            ),
          ),
          const Positioned(
            right: 34,
            top: 58,
            child: Opacity(
              opacity: 0.7,
              child: Icon(Icons.auto_awesome,
                  color: OnesColors.purpleDeep, size: 16),
            ),
          ),
          const Positioned(
            left: 10,
            bottom: 14,
            child: Opacity(
              opacity: 0.9,
              child: Icon(Icons.camera_alt,
                  color: OnesColors.purpleDeep, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
