import 'package:flutter/material.dart';

class GalleriesPage extends StatelessWidget {
  const GalleriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text('Galleries'),
        ),
      ),
    );
  }
}
