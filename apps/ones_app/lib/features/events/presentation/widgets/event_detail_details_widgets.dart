import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';

class EventDetailSectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final Widget? trailing;

  const EventDetailSectionCard({
    super.key,
    this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return OnesCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }
}

class ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final int? maxLines;
  final TextOverflow? overflow;

  const ReadOnlyField({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isEmpty ? '-' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: OnesColors.black.withOpacity(0.55),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          v,
          maxLines: maxLines,
          overflow: overflow,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: OnesColors.black,
          ),
        ),
      ],
    );
  }
}

class EventCodeDisplay extends StatelessWidget {
  final String label;
  final String code;
  final String unavailableText;

  const EventCodeDisplay({
    super.key,
    required this.label,
    required this.code,
    required this.unavailableText,
  });

  @override
  Widget build(BuildContext context) {
    final value = code.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OnesColors.yellowSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: OnesColors.black.withValues(alpha: 0.65),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value.isEmpty ? unavailableText : value,
            key: const ValueKey('event-code-value'),
            style: const TextStyle(
              color: OnesColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
