import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';

class AdminFramesPage extends StatelessWidget {
  const AdminFramesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: const Text('Frames'),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Frames management (coming soon).'),
        ),
      ),
    );
  }
}
