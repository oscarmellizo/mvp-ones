import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/event_card.dart';
import '../../../../core/ui/widgets/event_card_skeleton.dart';
import '../../../../core/ui/widgets/ones_empty_state.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import '../../../../core/ui/widgets/ones_section_header.dart';
import '../../domain/event.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import 'create_event_page.dart';
import 'event_detail_page.dart';
import 'event_join_code_page.dart';
import '../../../tutorial/presentation/tutorial_keys.dart';

const String _defaultEventCoverAsset = 'assets/branding/ones-logo.png';

class EventsListPage extends StatefulWidget {
  static const routeName = '/events';

  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  static const _bg = OnesColors.surfaceWarm;

  String? _lastLanguage;

  static const Set<String> _homeRequiredKeys = {
    'nav.home',
    'nav.galleries',
    'nav.profile',
    'home.search_events',
    'home.today',
    'home.next_events',
    'home.live_now',
    'home.no_upcoming_events',
    'home.empty_today_title',
    'home.empty_today_message',
    'home.empty_next',
    'home.no_results_for',
    'home.action_create_event',
    'home.action_enter_event_code',
    'home.empty_today_cta_create',
    'home.empty_today_cta_join',
    'common.error',
    'common.clear',
    'common.retry',
  };

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lastLanguage = context.read<TranslationsService>().getCurrentLanguage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'home',
            requiredKeys: _homeRequiredKeys,
          );
      context.read<EventsController>().refresh();
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

  void _clearSearch() {
    _searchController.clear();
  }

  bool _matchesQuery(Event e, String q) {
    if (q.isEmpty) return true;
    return e.title.toLowerCase().contains(q) ||
        e.location.toLowerCase().contains(q);
  }

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
              page: 'home',
              requiredKeys: _homeRequiredKeys,
            );
      });
    }

    final q = _searchController.text.trim().toLowerCase();
    final searching = q.isNotEmpty;

    final events = controller.events.where((e) => _matchesQuery(e, q));
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final todayEvents = events.where((e) {
      final start = e.startAt.toLocal();
      final end = e.endAt.toLocal();
      return start.isBefore(tomorrowStart) && end.isAfter(todayStart);
    }).toList(growable: false)
      ..sort(
        (a, b) => a.startAt.toLocal().compareTo(b.startAt.toLocal()),
      );

    final todayCards = todayEvents;

    final nextEvents = events
        .where((e) =>
            e.startAt.toLocal().isAfter(tomorrowStart) ||
            e.startAt.toLocal().isAtSameMomentAs(tomorrowStart))
        .toList(growable: false)
      ..sort(
        (a, b) => a.startAt.toLocal().compareTo(b.startAt.toLocal()),
      );

    final noResults = searching &&
        !controller.loading &&
        todayCards.isEmpty &&
        nextEvents.isEmpty;

    return ColoredBox(
      color: _bg,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => controller.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OnesSearchField(
                  controller: _searchController,
                  hintText: t.translate('home.search_events'),
                  borderRadius: BorderRadius.circular(14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  prefixIcon: const Icon(Icons.search),
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
                  key: TutorialKeys.homeSearch,
                ),
              ),
              const SizedBox(height: 18),
              if (controller.loading ||
                  !searching ||
                  todayCards.isNotEmpty) ...[
                OnesSectionHeader(
                  key: TutorialKeys.homeHeaderToday,
                  title: t.translate('home.today'),
                ),
                const SizedBox(height: 12),
                if (controller.loading)
                  SizedBox(
                    height: EventCard.extentForWidth(240),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, __) =>
                          const EventCardSkeleton(width: 240),
                    ),
                  )
                else if (todayCards.isEmpty)
                  searching
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TodayEmptyCard(
                            onCreate: () => Navigator.of(context)
                                .pushNamed(CreateEventPage.routeName),
                            onJoin: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EventJoinCodePage(),
                              ),
                            ),
                          ),
                        )
                else
                  SizedBox(
                    height: EventCard.extentForWidth(240),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: todayCards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final e = todayCards[index];
                        final start = e.startAt.toLocal();
                        final end = e.endAt.toLocal();

                        final displayStart =
                            start.isBefore(todayStart) ? todayStart : start;
                        final displayEnd =
                            end.isAfter(tomorrowStart) ? tomorrowStart : end;

                        final isLiveNow = (now.isAfter(start) ||
                                now.isAtSameMomentAs(start)) &&
                            now.isBefore(end);

                        return FutureBuilder<String?>(
                          future: coverUrls.getUrlIfAny(
                            eventId: e.id,
                            coverKey: e.coverKey,
                          ),
                          builder: (context, snapshot) {
                            final url = snapshot.data;
                            return EventCard(
                              title: e.title,
                              location: e.location,
                              imageUrl:
                                  (url != null && url.isNotEmpty) ? url : null,
                              fallbackAsset: _defaultEventCoverAsset,
                              dateText: null,
                              timeText:
                                  '${formatTimeOfDayLocalized(displayStart, lang)} - ${formatTimeOfDayLocalized(displayEnd, lang)}',
                              badgeText: isLiveNow
                                  ? t.translate('home.live_now')
                                  : null,
                              width: 240,
                              onTap: () => Navigator.of(context).pushNamed(
                                EventDetailPage.routeName,
                                arguments: e.id,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 22),
              if (controller.loading ||
                  !searching ||
                  nextEvents.isNotEmpty) ...[
                OnesSectionHeader(
                  key: TutorialKeys.homeHeaderNext,
                  title: t.translate('home.next_events'),
                ),
                const SizedBox(height: 12),
              ],
              if (controller.error != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OnesColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.translate('common.error')}: ${controller.error}',
                        style: const TextStyle(color: OnesColors.danger),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: controller.refresh,
                        child: Text(
                          t.translate('common.retry', fallback: 'Reintentar'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (noResults)
                OnesEmptyState(
                  icon: Icons.search_off_outlined,
                  title:
                      '${t.translate('home.no_results_for', fallback: 'Sin resultados para')} "$q"',
                  message: t.translate(
                    'home.empty_next',
                    fallback: 'Prueba con otro nombre o lugar.',
                  ),
                  action: FilledButton.tonal(
                    onPressed: _clearSearch,
                    child: Text(
                      t.translate('common.clear', fallback: 'Limpiar'),
                    ),
                  ),
                )
              else if (!controller.loading)
                nextEvents.isEmpty
                    ? (searching
                        ? const SizedBox.shrink()
                        : OnesEmptyState(
                            icon: Icons.event_available_outlined,
                            title: t.translate(
                              'home.empty_next',
                              fallback: 'Sin próximos eventos por ahora',
                            ),
                          ))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 14.0;
                          const minCardWidth = 170.0;

                          final availableWidth = constraints.maxWidth - 32;
                          final crossAxisCount = ((availableWidth + spacing) /
                                  (minCardWidth + spacing))
                              .floor()
                              .clamp(1, 10);

                          final computedCardWidth = (availableWidth -
                                  (spacing * (crossAxisCount - 1))) /
                              crossAxisCount;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: nextEvents.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                mainAxisExtent: EventCard.extentForWidth(
                                  computedCardWidth,
                                ),
                              ),
                              itemBuilder: (context, i) {
                                final e = nextEvents[i];
                                final when = e.startAt.toLocal();
                                final end = e.endAt.toLocal();

                                return FutureBuilder<String?>(
                                  future: coverUrls.getUrlIfAny(
                                    eventId: e.id,
                                    coverKey: e.coverKey,
                                  ),
                                  builder: (context, snapshot) {
                                    final url = snapshot.data;
                                    return EventCard(
                                      title: e.title,
                                      location: e.location,
                                      imageUrl: (url != null && url.isNotEmpty)
                                          ? url
                                          : null,
                                      fallbackAsset: _defaultEventCoverAsset,
                                      dateText: formatEventDateRangeLocalized(
                                        when,
                                        end,
                                        lang,
                                      ),
                                      timeText:
                                          '${formatTimeOfDayLocalized(when, lang)} - ${formatTimeOfDayLocalized(end, lang)}',
                                      badgeText: null,
                                      onTap: () =>
                                          Navigator.of(context).pushNamed(
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
              if (controller.loading)
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 14.0;
                    const minCardWidth = 170.0;
                    final availableWidth = constraints.maxWidth - 32;
                    final crossAxisCount =
                        ((availableWidth + spacing) / (minCardWidth + spacing))
                            .floor()
                            .clamp(1, 10);
                    final computedCardWidth =
                        (availableWidth - (spacing * (crossAxisCount - 1))) /
                            crossAxisCount;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 4,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          mainAxisExtent: EventCard.extentForWidth(
                            computedCardWidth,
                          ),
                        ),
                        itemBuilder: (_, __) => const EventCardSkeleton(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayEmptyCard extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _TodayEmptyCard({required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: OnesColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: OnesEmptyState(
        icon: Icons.event_outlined,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: t.translate(
          'home.empty_today_title',
          fallback: 'Nada por aquí… todavía',
        ),
        message: t.translate(
          'home.empty_today_message',
          fallback: 'No tienes eventos hoy. Crea uno o únete con un código.',
        ),
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                t.translate(
                  'home.empty_today_cta_create',
                  fallback: 'Crear evento',
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.key_outlined, size: 18),
              label: Text(
                t.translate(
                  'home.empty_today_cta_join',
                  fallback: 'Ingresar código',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
