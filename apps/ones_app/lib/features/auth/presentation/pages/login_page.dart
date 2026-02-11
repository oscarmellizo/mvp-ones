import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ones - Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Sign in to continue', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                if (auth.error != null) ...[
                  Text('Error: ${auth.error}', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: auth.isLoading ? null : () => auth.signIn(),
                  icon: const Icon(Icons.login),
                  label: auth.isLoading ? const Text('Signing in...') : const Text('Continue with Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
