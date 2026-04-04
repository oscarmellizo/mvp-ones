import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';

class AdminEventTemplatesPage extends StatelessWidget {
  const AdminEventTemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: const Text('Event templates'),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Event templates management (coming soon).'),
        ),
      ),
    );
  }
}
