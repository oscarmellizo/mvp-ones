import 'package:flutter/material.dart';

import '../ones_colors.dart';

/// Pulsing shimmer placeholder for [EventCard] while events load.
class EventCardSkeleton extends StatefulWidget {
  final double? width;

  const EventCardSkeleton({super.key, this.width});

  @override
  State<EventCardSkeleton> createState() => _EventCardSkeletonState();
}

class _EventCardSkeletonState extends State<EventCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: 0.35, end: 0.7).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar({double width = double.infinity, double height = 10}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: OnesColors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: OnesColors.white,
          borderRadius: radius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AspectRatio(
              aspectRatio: 16 / 10,
              child: ColoredBox(color: OnesColors.surfaceMuted),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 140, height: 13),
                  const SizedBox(height: 10),
                  _bar(width: 110),
                  const SizedBox(height: 6),
                  _bar(width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
