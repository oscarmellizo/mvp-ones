import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/auth_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (auth.user != null)
                Text(
                  auth.user!.email ?? auth.user!.displayName ?? auth.user!.userId,
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : () => auth.logout(),
                  child: auth.isLoading
                      ? const Text('Signing out...')
                      : const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
