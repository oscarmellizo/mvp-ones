import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';

class CreateEventFormSection extends StatelessWidget {
  final String title;
  final Widget child;

  const CreateEventFormSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return OnesCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class CreateEventFieldLabel extends StatelessWidget {
  final String text;

  const CreateEventFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: OnesColors.black,
      ),
    );
  }
}

class CreateEventDateTimeRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String dateValue;
  final String timeValue;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  const CreateEventDateTimeRow({
    super.key,
    required this.icon,
    required this.title,
    required this.dateValue,
    required this.timeValue,
    required this.onPickDate,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: OnesColors.purpleBright.withOpacity(0.12),
            borderRadius: BorderRadius.zero,
          ),
          child: Icon(icon, color: OnesColors.purpleMid),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CreateEventMiniField(
                      label: t.translate('create_event.date_label'),
                      value: dateValue,
                      icon: Icons.calendar_today,
                      onTap: onPickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CreateEventMiniField(
                      label: t.translate('create_event.time_label'),
                      value: timeValue,
                      icon: Icons.access_time,
                      onTap: onPickTime,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CreateEventMiniField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const CreateEventMiniField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: OnesColors.white.withOpacity(0.75),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: OnesColors.black.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: OnesColors.black.withOpacity(0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(icon, size: 18, color: OnesColors.black.withOpacity(0.55)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CreateEventDashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const CreateEventDashedBorderPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.zero,
    );

    const dash = 6.0;
    const gap = 4.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CreateEventDashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
