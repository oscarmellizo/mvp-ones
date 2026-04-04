import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../auth/presentation/auth_controller.dart';

class AdminGate extends StatelessWidget {
  final Widget child;

  const AdminGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (!auth.isSignedIn) {
      return Scaffold(
        backgroundColor: OnesColors.background,
        appBar: AppBar(
          title: const Text('Admin'),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Please sign in to access Admin.'),
          ),
        ),
      );
    }

    if (auth.isLoading) {
      return Scaffold(
        backgroundColor: OnesColors.background,
        appBar: AppBar(
          title: const Text('Admin'),
        ),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!auth.isAdmin) {
      return Scaffold(
        backgroundColor: OnesColors.background,
        appBar: AppBar(
          title: const Text('Admin'),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Unauthorized.'),
          ),
        ),
      );
    }

    return child;
  }
}
