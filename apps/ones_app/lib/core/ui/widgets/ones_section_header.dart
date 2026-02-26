import 'package:flutter/material.dart';

import '../ones_colors.dart';

class OnesSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const OnesSectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OnesColors.purpleDeep,
                ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
