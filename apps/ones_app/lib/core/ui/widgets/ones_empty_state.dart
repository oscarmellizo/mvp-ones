import 'package:flutter/material.dart';

import '../ones_colors.dart';

/// Friendly empty state: icon, title, optional message and optional CTA.
class OnesEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const OnesEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 28,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: OnesColors.purpleMid.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: OnesColors.purpleMid),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OnesColors.black,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: OnesColors.inkSoft,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
