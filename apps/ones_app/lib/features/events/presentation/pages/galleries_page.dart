import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import '../../domain/event.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import 'event_detail_page.dart';

const String _defaultEventCoverAsset = 'assets/branding/ones-logo.png';

class GalleriesPage extends StatefulWidget {
  const GalleriesPage({super.key});

  @override
  State<GalleriesPage> createState() => _GalleriesPageState();
}

class _GalleriesPageState extends State<GalleriesPage> {
  final _searchController = TextEditingController();

  _QuickFilter _filter = _QuickFilter.all;

  static const Set<String> _galleriesRequiredKeys = {
    'galleries.search_past_events',
    'galleries.filter_all',
    'galleries.filter_last_7_days',
    'galleries.filter_last_30_days',
    'galleries.filter_this_year',
    'galleries.no_past_events_yet',
    'galleries.no_results_for',
    'galleries.today',
    'galleries.yesterday',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'galleries',
            requiredKeys: _galleriesRequiredKeys,
          );
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
    final t = context.watch<TranslationsService>();

    final q = _searchController.text.trim().toLowerCase();

    final now = DateTime.now();
    final filteredEvents = controller.events.where((e) {
      final localStart = e.startAt.toLocal();
      if (!_filter.accepts(eventStartLocal: localStart, nowLocal: now)) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q);
    }).toList(growable: false)
      ..sort((a, b) => b.startAt.toLocal().compareTo(a.startAt.toLocal()));

    final groups = <DateTime, List<Event>>{};
    for (final e in filteredEvents) {
      final localStart = e.startAt.toLocal();
      final dayKey =
          DateTime(localStart.year, localStart.month, localStart.day);
      (groups[dayKey] ??= <Event>[]).add(e);
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
              OnesSearchField(
                controller: _searchController,
                hintText: t.translate('galleries.search_past_events'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(t.translate('galleries.filter_all')),
                    selected: _filter == _QuickFilter.all,
                    onSelected: (_) => setState(() {
                      _filter = _QuickFilter.all;
                    }),
                  ),
                  ChoiceChip(
                    label: Text(t.translate('galleries.filter_last_7_days')),
                    selected: _filter == _QuickFilter.last7Days,
                    onSelected: (_) => setState(() {
                      _filter = _QuickFilter.last7Days;
                    }),
                  ),
                  ChoiceChip(
                    label: Text(t.translate('galleries.filter_last_30_days')),
                    selected: _filter == _QuickFilter.last30Days,
                    onSelected: (_) => setState(() {
                      _filter = _QuickFilter.last30Days;
                    }),
                  ),
                  ChoiceChip(
                    label: Text(t.translate('galleries.filter_this_year')),
                    selected: _filter == _QuickFilter.thisYear,
                    onSelected: (_) => setState(() {
                      _filter = _QuickFilter.thisYear;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (controller.loading && controller.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (orderedDays.isEmpty)
                OnesCard(
                  child: Text(
                    q.isEmpty
                        ? t.translate('galleries.no_past_events_yet')
                        : '${t.translate('galleries.no_results_for')} "$q".',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.6)),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final children = <Widget>[];
                    for (final day in orderedDays) {
                      final dayEvents = (groups[day] ?? const <Event>[])
                          .toList(growable: false);
                      dayEvents.sort((a, b) =>
                          b.startAt.toLocal().compareTo(a.startAt.toLocal()));

                      children.add(
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                          child: Text(
                            _friendlyDayHeader(day, now, t),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: OnesColors.black,
                            ),
                          ),
                        ),
                      );

                      for (var i = 0; i < dayEvents.length; i++) {
                        final e = dayEvents[i];
                        final when = e.startAt.toLocal();
                        final end = e.endAt.toLocal();

                        children.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: FutureBuilder<String?>(
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
                                    fallbackAsset: _defaultEventCoverAsset,
                                    dateText: null,
                                    timeText:
                                        '${_formatTimeOfDay(when)} - ${_formatTimeOfDay(end)}',
                                    badgeText: null,
                                    width: double.infinity,
                                    onTap: () =>
                                        Navigator.of(context).pushNamed(
                                      EventDetailPage.routeName,
                                      arguments: e.id,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyDayHeader(DateTime day, DateTime now, TranslationsService t) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDay(day, today)) {
      return '${t.translate('galleries.today')} · ${formatMonthDayYear(day)}';
    }
    if (_isSameDay(day, yesterday)) {
      return '${t.translate('galleries.yesterday')} · ${formatMonthDayYear(day)}';
    }
    return formatMonthDayYear(day);
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
    Widget buildFallback() {
      return ColoredBox(
        color: OnesColors.white,
        child: Center(
          child: Image.asset(
            fallbackAsset,
            width: 84,
            height: 84,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Ink(
        width: width,
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
                        errorBuilder: (_, __, ___) => buildFallback(),
                      )
                    : buildFallback(),
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

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

enum _QuickFilter {
  all,
  last7Days,
  last30Days,
  thisYear;

  bool accepts(
      {required DateTime eventStartLocal, required DateTime nowLocal}) {
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    switch (this) {
      case _QuickFilter.all:
        return true;
      case _QuickFilter.last7Days:
        return eventStartLocal.isAfter(today.subtract(const Duration(days: 7)));
      case _QuickFilter.last30Days:
        return eventStartLocal
            .isAfter(today.subtract(const Duration(days: 30)));
      case _QuickFilter.thisYear:
        return eventStartLocal.year == nowLocal.year;
    }
  }
}
