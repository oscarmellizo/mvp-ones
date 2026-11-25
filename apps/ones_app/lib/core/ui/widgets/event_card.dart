import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../ones_colors.dart';

/// Event card shared by Home and Galerías.
/// Cover on top (16:10) and legible info below on a white surface.
class EventCard extends StatelessWidget {
  final String title;
  final String location;
  final String? imageUrl;
  final String fallbackAsset;
  final String? badgeText;
  final String? dateText;
  final String timeText;
  final double? width;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.title,
    required this.location,
    required this.imageUrl,
    required this.fallbackAsset,
    required this.timeText,
    required this.onTap,
    this.badgeText,
    this.dateText,
    this.width,
  });

  /// Vertical space used below the cover (title + two info rows + padding).
  static const double contentExtent = 118;

  /// Cover height for a given card width (16:10 aspect).
  static double coverExtent(double cardWidth) => cardWidth / 1.6;

  /// Total card extent for a given width, used by grid delegates.
  static double extentForWidth(double cardWidth) =>
      coverExtent(cardWidth) + contentExtent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final schedule = dateText != null ? '$dateText · $timeText' : timeText;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: OnesColors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: OnesColors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: _Cover(
                  imageUrl: imageUrl,
                  fallbackAsset: fallbackAsset,
                  badgeText: badgeText,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: OnesColors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.event_outlined, text: schedule),
                    const SizedBox(height: 4),
                    _InfoRow(
                      icon: Icons.place_outlined,
                      text: location.isEmpty ? '—' : location,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? imageUrl;
  final String fallbackAsset;
  final String? badgeText;

  const _Cover({
    required this.imageUrl,
    required this.fallbackAsset,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      return ColoredBox(
        color: OnesColors.surfaceMuted,
        child: Center(
          child: Image.asset(
            fallbackAsset,
            width: 72,
            height: 72,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null && imageUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                const ColoredBox(color: OnesColors.surfaceMuted),
            errorWidget: (_, __, ___) => fallback(),
          )
        else
          fallback(),
        if (badgeText != null)
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: OnesColors.live,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: OnesColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    badgeText!,
                    style: const TextStyle(
                      color: OnesColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: OnesColors.inkSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OnesColors.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
