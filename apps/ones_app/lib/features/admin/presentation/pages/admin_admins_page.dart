import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';

class AdminAdminsPage extends StatelessWidget {
  const AdminAdminsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: const Text('Administrators'),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Administrators management (coming soon).'),
        ),
      ),
    );
  }
}
