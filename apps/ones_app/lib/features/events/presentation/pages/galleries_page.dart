import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import 'event_detail_page.dart';

class GalleriesPage extends StatefulWidget {
  const GalleriesPage({super.key});

  @override
  State<GalleriesPage> createState() => _GalleriesPageState();
}

class _GalleriesPageState extends State<GalleriesPage> {
  final _searchController = TextEditingController();

  static const _divider = OnesColors.orange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<EventsController>();
      if (controller.events.isEmpty && !controller.loading) {
        controller.refresh();
      }
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    final coverUrls = context.watch<EventCoverUrlsController>();

    final q = _searchController.text.trim().toLowerCase();

    final now = DateTime.now();
    final pastEvents = controller.events.where((e) {
      final isPast = e.createdAt.isBefore(now);
      if (!isPast) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q);
    }).toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final filtered = pastEvents;

    return Scaffold(
      backgroundColor: OnesColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<EventsController>().refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              OnesSearchField(
                controller: _searchController,
                hintText: 'Search past events',
              ),
              const SizedBox(height: 14),
              if (controller.loading && controller.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                OnesCard(
                  child: Text(
                    q.isEmpty ? 'No past events yet.' : 'No results for "$q".',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.6)),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 1.0;
                    const minCardWidth = 170.0;

                    final availableWidth = constraints.maxWidth;
                    final crossAxisCount =
                        ((availableWidth + spacing) / (minCardWidth + spacing))
                            .floor()
                            .clamp(1, 10);

                    final computedCardWidth =
                        (availableWidth - (spacing * (crossAxisCount - 1))) /
                            crossAxisCount;

                    final childAspectRatio = computedCardWidth <= 220
                        ? 1.05
                        : computedCardWidth <= 320
                            ? 1.15
                            : 1.25;

                    return ColoredBox(
                      color: _divider,
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemBuilder: (context, i) {
                          final e = filtered[i];
                          final cover = i.isEven
                              ? 'assets/auth/amigos.png'
                              : 'assets/auth/concierto.png';
                          final when = e.startAt.toLocal();
                          final end = e.endAt.toLocal();

                          return FutureBuilder<String?>(
                            future: coverUrls.getUrlIfAny(
                              eventId: e.id,
                              coverKey: e.coverKey,
                            ),
                            builder: (context, snapshot) {
                              final url = snapshot.data;
                              return _UpcomingCard(
                                title: e.title,
                                location: e.location,
                                imageUrl: (url != null && url.isNotEmpty)
                                    ? url
                                    : null,
                                fallbackAsset: cover,
                                dateText: formatMonthDayYear(when),
                                timeText:
                                    '${_formatTimeOfDay(when)} - ${_formatTimeOfDay(end)}',
                                badgeText: null,
                                width: null,
                                onTap: () => Navigator.of(context).pushNamed(
                                  EventDetailPage.routeName,
                                  arguments: e.id,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final String title;
  final String location;
  final String? imageUrl;
  final String fallbackAsset;
  final String? badgeText;
  final String? dateText;
  final String timeText;
  final double? width;
  final VoidCallback onTap;

  const _UpcomingCard({
    required this.title,
    required this.location,
    required this.imageUrl,
    required this.fallbackAsset,
    required this.timeText,
    required this.badgeText,
    required this.dateText,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Ink(
        width: width ?? 260,
        decoration: const BoxDecoration(borderRadius: BorderRadius.zero),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: (imageUrl != null)
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          fallbackAsset,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        fallbackAsset,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.zero,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    OnesColors.black.withOpacity(0.05),
                    OnesColors.black.withOpacity(0.65),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: OnesColors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          color: OnesColors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: OnesColors.white,
                          letterSpacing: 0.6,
                          height: 1.05,
                        ),
                  ),
                  const SizedBox(height: 6),
                  if (dateText != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: OnesColors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateText!,
                          style: const TextStyle(
                            color: OnesColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: OnesColors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeText,
                        style: const TextStyle(
                          color: OnesColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: OnesColors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          color: OnesColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimeOfDay(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
