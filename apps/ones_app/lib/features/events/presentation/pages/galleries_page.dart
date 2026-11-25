import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/event_card.dart';
import '../../../../core/ui/widgets/event_card_skeleton.dart';
import '../../../../core/ui/widgets/ones_empty_state.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import '../../domain/event.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import '../widgets/gallery_grid_layout.dart';
import 'create_event_page.dart';
import 'event_detail_page.dart';

const String _defaultEventCoverAsset = 'assets/branding/ones-logo.png';

class GalleriesPage extends StatefulWidget {
  const GalleriesPage({super.key});

  @override
  State<GalleriesPage> createState() => _GalleriesPageState();
}

class _GalleriesPageState extends State<GalleriesPage> {
  final _searchController = TextEditingController();

  String? _lastLanguage;

  _QuickFilter _filter = _QuickFilter.all;

  static const Set<String> _galleriesRequiredKeys = {
    'galleries.search_past_events',
    'galleries.filter_all',
    'galleries.filter_last_7_days',
    'galleries.filter_last_30_days',
    'galleries.filter_this_year',
    'galleries.no_past_events_yet',
    'galleries.empty_title',
    'galleries.empty_message',
    'galleries.no_results_for',
    'galleries.today',
    'galleries.yesterday',
    'galleries.empty_cta_create',
    'common.clear',
  };

  @override
  void initState() {
    super.initState();
    _lastLanguage = context.read<TranslationsService>().getCurrentLanguage();
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

  void _clearSearch() => _searchController.clear();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    final coverUrls = context.watch<EventCoverUrlsController>();
    final t = context.watch<TranslationsService>();

    final lang = t.getCurrentLanguage();
    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TranslationsService>().ensurePageTranslations(
              page: 'galleries',
              requiredKeys: _galleriesRequiredKeys,
            );
      });
    }

    final q = _searchController.text.trim().toLowerCase();
    final searching = q.isNotEmpty;

    final now = DateTime.now();
    // Only events that already started (past or live) belong in Galerías.
    final filteredEvents = controller.events.where((e) {
      final localStart = e.startAt.toLocal();
      if (localStart.isAfter(now)) return false;
      if (!_filter.accepts(eventStartLocal: localStart, nowLocal: now)) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.location.toLowerCase().contains(q);
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

    final chips = [
      (t.translate('galleries.filter_all'), _QuickFilter.all),
      (t.translate('galleries.filter_last_7_days'), _QuickFilter.last7Days),
      (t.translate('galleries.filter_last_30_days'), _QuickFilter.last30Days),
      (t.translate('galleries.filter_this_year'), _QuickFilter.thisYear),
    ];

    return Scaffold(
      backgroundColor: OnesColors.surfaceWarm,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<EventsController>().refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
            children: [
              OnesSearchField(
                controller: _searchController,
                hintText: t.translate('galleries.search_past_events'),
                borderRadius: BorderRadius.circular(14),
                suffixIcon: searching
                    ? IconButton(
                        tooltip: t.translate(
                          'common.clear',
                          fallback: 'Limpiar',
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: chips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final (label, value) = chips[i];
                    return ChoiceChip(
                      label: Text(label),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              if (controller.loading && controller.events.isEmpty)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth = galleryGridWidth(constraints.maxWidth);
                    final columns = galleryCardColumns(contentWidth);
                    final cardWidth =
                        (contentWidth - (columns - 1) * 12.0) / columns;
                    return Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: EventCard.extentForWidth(cardWidth),
                          ),
                          itemCount: 4,
                          itemBuilder: (_, __) => const EventCardSkeleton(),
                        ),
                      ),
                    );
                  },
                )
              else if (orderedDays.isEmpty)
                searching
                    ? OnesEmptyState(
                        icon: Icons.search_off_outlined,
                        title:
                            '${t.translate('galleries.no_results_for')} "$q"',
                        action: FilledButton.tonal(
                          onPressed: _clearSearch,
                          child: Text(
                            t.translate('common.clear', fallback: 'Limpiar'),
                          ),
                        ),
                      )
                    : OnesEmptyState(
                        icon: Icons.photo_library_outlined,
                        title: t.translate(
                          'galleries.empty_title',
                          fallback: 'Aún no hay galerías',
                        ),
                        message: t.translate(
                          'galleries.empty_message',
                          fallback:
                              'Cuando pase un evento, sus fotos aparecerán aquí.',
                        ),
                        action: FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(CreateEventPage.routeName),
                          icon: const Icon(Icons.event_outlined, size: 18),
                          label: Text(
                            t.translate(
                              'galleries.empty_cta_create',
                              fallback: 'Crear evento',
                            ),
                          ),
                        ),
                      )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final children = <Widget>[];
                    final contentWidth = galleryGridWidth(
                      constraints.maxWidth,
                    );
                    final columns = galleryCardColumns(contentWidth);
                    final cardWidth =
                        (contentWidth - (columns - 1) * 12.0) / columns;
                    final gridDelegate =
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: EventCard.extentForWidth(cardWidth),
                    );
                    if (columns > 1) {
                      return Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate: gridDelegate,
                            itemCount: filteredEvents.length,
                            itemBuilder: (context, index) => _buildEventCard(
                              context,
                              filteredEvents[index],
                              coverUrls,
                              lang,
                            ),
                          ),
                        ),
                      );
                    }

                    for (final day in orderedDays) {
                      final dayEvents = (groups[day] ?? const <Event>[])
                          .toList(growable: false);
                      dayEvents.sort((a, b) =>
                          b.startAt.toLocal().compareTo(a.startAt.toLocal()));

                      children.add(
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                          child: Text(
                            _friendlyDayHeader(day, now, t, lang),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: OnesColors.black,
                            ),
                          ),
                        ),
                      );

                      children.add(
                        Center(
                          child: SizedBox(
                            width: contentWidth,
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              gridDelegate: gridDelegate,
                              itemCount: dayEvents.length,
                              itemBuilder: (context, index) => _buildEventCard(
                                context,
                                dayEvents[index],
                                coverUrls,
                                lang,
                              ),
                            ),
                          ),
                        ),
                      );
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

  Widget _buildEventCard(
    BuildContext context,
    Event event,
    EventCoverUrlsController coverUrls,
    String lang,
  ) {
    final when = event.startAt.toLocal();
    final end = event.endAt.toLocal();

    return FutureBuilder<String?>(
      future: coverUrls.getUrlIfAny(
        eventId: event.id,
        coverKey: event.coverKey,
      ),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return EventCard(
          title: event.title,
          location: event.location,
          imageUrl: (url != null && url.isNotEmpty) ? url : null,
          fallbackAsset: _defaultEventCoverAsset,
          dateText: formatEventDateRangeLocalized(when, end, lang),
          timeText:
              '${formatTimeOfDayLocalized(when, lang)} - ${formatTimeOfDayLocalized(end, lang)}',
          badgeText: null,
          onTap: () => Navigator.of(context).pushNamed(
            EventDetailPage.routeName,
            arguments: event.id,
          ),
        );
      },
    );
  }

  String _friendlyDayHeader(
    DateTime day,
    DateTime now,
    TranslationsService t,
    String lang,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDay(day, today)) {
      return '${t.translate('galleries.today')} · ${formatDateLocalized(day, lang)}';
    }
    if (_isSameDay(day, yesterday)) {
      return '${t.translate('galleries.yesterday')} · ${formatDateLocalized(day, lang)}';
    }
    return formatDateLocalized(day, lang);
  }
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
