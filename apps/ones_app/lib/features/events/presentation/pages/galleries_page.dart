import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/ui/ones_colors.dart';
import '../events_controller.dart';
import 'event_detail_page.dart';

class GalleriesPage extends StatefulWidget {
  const GalleriesPage({super.key});

  @override
  State<GalleriesPage> createState() => _GalleriesPageState();
}

class _GalleriesPageState extends State<GalleriesPage> {
  final _searchController = TextEditingController();

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

    final q = _searchController.text.trim().toLowerCase();

    final now = DateTime.now();
    final pastEvents = controller.events.where((e) {
      final isPast = e.createdAt.isBefore(now);
      if (!isPast) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q);
    }).toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final groups = <DateTime, List<_GalleryCardData>>{};
    for (var i = 0; i < pastEvents.length; i++) {
      final e = pastEvents[i];
      final dayKey =
          DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      final item = _GalleryCardData(
        id: e.id,
        title: e.title,
        location: 'NYC',
        coverAsset:
            (i.isEven) ? 'assets/auth/amigos.png' : 'assets/auth/concierto.png',
        date: e.createdAt,
      );
      (groups[dayKey] ??= []).add(item);
    }

    final orderedDays = groups.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: OnesColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<EventsController>().refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search past events',
                  filled: true,
                  fillColor: OnesColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (controller.loading && controller.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (orderedDays.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: OnesColors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    q.isEmpty ? 'No past events yet.' : 'No results for "$q".',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.6)),
                  ),
                )
              else
                ...orderedDays.expand((day) {
                  final items = groups[day]!;
                  return [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 10),
                      child: Text(
                        _formatDayHeader(day),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: OnesColors.black,
                        ),
                      ),
                    ),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GalleryEventCard(
                          data: item,
                          onTap: () => Navigator.of(context).pushNamed(
                            EventDetailPage.routeName,
                            arguments: item.id,
                          ),
                        ),
                      ),
                    ),
                  ];
                }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDayHeader(DateTime d) {
    return formatMonthDayYear(d);
  }
}

class _GalleryEventCard extends StatelessWidget {
  final _GalleryCardData data;
  final VoidCallback onTap;

  const _GalleryEventCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: OnesColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                data.coverAsset,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: OnesColors.black.withOpacity(0.55),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _GalleryCardData {
  final String id;
  final String title;
  final String location;
  final String coverAsset;
  final DateTime date;

  const _GalleryCardData({
    required this.id,
    required this.title,
    required this.location,
    required this.coverAsset,
    required this.date,
  });
}
