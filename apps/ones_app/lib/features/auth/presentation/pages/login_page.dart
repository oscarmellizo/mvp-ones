import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const _bg = Color(0xFFF4B64E);
  static const _purple = Color(0xFF3B1D6D);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 520 ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: _bg,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Image(
                        image: AssetImage('assets/splash/symbol_purple.png'),
                        width: 66,
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Capture moments, share galleries, and\nrelive the event together.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withOpacity(0.7),
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _HeroStack(height: size.height >= 860 ? 340 : 300),
                  const SizedBox(height: 28),
                  if (auth.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Error: ${auth.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : () => auth.signIn(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
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
                    onPressed: () {},
                    child: Text(
                      'Create an account with Email',
                      style: TextStyle(
                        color: _purple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black.withOpacity(0.55),
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

  static const _purple = Color(0xFF3B1D6D);

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
                  borderRadius: BorderRadius.circular(22),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
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
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/auth/amigos.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 32,
            child: Opacity(
              opacity: 0.9,
              child: Icon(Icons.auto_awesome, color: _purple, size: 22),
            ),
          ),
          Positioned(
            right: 34,
            top: 58,
            child: Opacity(
              opacity: 0.7,
              child: Icon(Icons.auto_awesome, color: _purple, size: 16),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 14,
            child: Opacity(
              opacity: 0.9,
              child: Icon(Icons.camera_alt, color: _purple, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
