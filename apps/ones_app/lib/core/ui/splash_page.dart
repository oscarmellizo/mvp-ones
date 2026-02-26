import 'package:flutter/material.dart';

import 'ones_colors.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: OnesColors.background,
      body: Center(
        child: _Content(),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: OnesColors.purpleDeep,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w =
                (constraints.maxWidth * 0.90).clamp(240.0, 520.0).toDouble();
            return Center(
              child: Image.asset(
                'assets/splash/ones-logo-grande.png',
                width: w,
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Loading Experience',
          style: textStyle,
        ),
      ],
    );
  }
}
