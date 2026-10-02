import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';

import '../auth_controller.dart';

import '../widgets/auth_buttons.dart';

import '../widgets/auth_error_banner.dart';

import '../widgets/email_auth_section.dart';

import 'forgot_password_page.dart';

import 'register_page.dart';



class LoginPage extends StatefulWidget {

  const LoginPage({super.key});



  @override

  State<LoginPage> createState() => _LoginPageState();

}



class _LoginPageState extends State<LoginPage> {




  /// Proveedor cuyo inicio de sesión está en curso: solo ese botón muestra "Conectando...".
  String? _pending;

  Future<void> _run(String provider, Future<AuthNextStep> Function() action) async {
    final auth = context.read<AuthController>();
    setState(() => _pending = provider);
    final AuthNextStep step;
    try {
      step = await action();
    } finally {
      if (mounted) setState(() => _pending = null);
    }
    if (!mounted) return;
    // Google/Apple sin cuenta en Ones: directo al formulario de registro (nombre y términos).
    // Las cuentas de correo sin registro las lleva el router a ese mismo formulario.
    if (step == AuthNextStep.needsRegistration && auth.user?.provider != 'password') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
    }
  }



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

              // Arrastrar la pantalla oculta el teclado, como en las apps nativas.

              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

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

                    '¡Bienvenido de nuevo!',

                    textAlign: TextAlign.center,

                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(

                          fontWeight: FontWeight.w800,

                          color: OnesColors.black,

                        ),

                  ),

                  const SizedBox(height: 10),

                  Text(

                    'Captura momentos, comparte galerías y\nrevive el evento juntos.',

                    textAlign: TextAlign.center,

                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                          color: OnesColors.black.withOpacity(0.7),

                          height: 1.3,

                        ),

                  ),

                  const SizedBox(height: 24),

                  _HeroStack(height: size.height >= 860 ? 340 : 300),

                  const SizedBox(height: 28),

                  ...[

                    if (auth.error != null) ...[

                      AuthErrorBanner(message: '${auth.error}'),

                      const SizedBox(height: 16),

                    ],

                    GoogleSignInButton(
                      busy: _pending == 'google',
                      onPressed: auth.isLoading ? null : () => _run('google', auth.signInWithGoogle),
                    ),
                    if (appleSignInAvailable) ...[
                      const SizedBox(height: 12),
                      AppleSignInButton(
                        busy: _pending == 'apple',
                        onPressed: auth.isLoading ? null : () => _run('apple', auth.signInWithApple),
                      ),
                    ],
                    const SizedBox(height: 12),
                    EmailAuthSection(
                      toggleLabel: 'Continuar con correo',
                      submitLabel: 'Iniciar sesión',
                      busy: auth.isLoading,
                      onSubmit: (email, password) => _run('email', () => auth.signInWithEmail(email, password)),
                      footer: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('auth.forgot'),
                          onPressed: auth.isLoading
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                                  ),
                          child: const Text(
                            'Olvidé mi contraseña',
                            style: TextStyle(color: OnesColors.purpleDeep, fontWeight: FontWeight.w700),
                          ),
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

                        'Crear una cuenta',

                        style: TextStyle(

                          color: OnesColors.purpleDeep,

                          fontWeight: FontWeight.w700,

                        ),

                      ),

                    ),

                  ],

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

