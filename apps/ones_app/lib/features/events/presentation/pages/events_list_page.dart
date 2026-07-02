import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import '../../../../core/ui/widgets/ones_section_header.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import 'event_detail_page.dart';
import '../../../invitations/presentation/widgets/invitations_sheet.dart';
import '../../../invitations/presentation/invitations_controller.dart';

const String _defaultEventCoverAsset = 'assets/branding/ones-logo.png';

class EventsListPage extends StatefulWidget {
  static const routeName = '/events';

  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  static const _bg = OnesColors.background;
  static const _divider = OnesColors.orange;

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
    'common.error',
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
      context.read<InvitationsController>().refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    final events = controller.events;
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
                child: _Header(
                  onBell: () => showInvitationsSheet(context),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OnesSearchField(
                  controller: _searchController,
                  hintText: t.translate('home.search_events'),
                  borderRadius: BorderRadius.zero,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 18),
              OnesSectionHeader(title: t.translate('home.today')),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: controller.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: todayCards.isEmpty ? 1 : todayCards.length,
                        separatorBuilder: (_, __) => const SizedBox(
                          width: 1,
                          child: ColoredBox(color: _divider),
                        ),
                        itemBuilder: (context, index) {
                          if (todayCards.isEmpty) {
                            return const _EmptyCard();
                          }

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
                              return _UpcomingCard(
                                title: e.title,
                                location: e.location,
                                imageUrl: (url != null && url.isNotEmpty)
                                    ? url
                                    : null,
                                fallbackAsset: _defaultEventCoverAsset,
                                dateText: null,
                                timeText:
                                    '${_formatTimeOfDay(displayStart)} - ${_formatTimeOfDay(displayEnd)}',
                                badgeText: isLiveNow
                                    ? t.translate('home.live_now')
                                    : null,
                                width: 260,
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
              const SizedBox(height: 22),
              OnesSectionHeader(title: t.translate('home.next_events')),
              const SizedBox(height: 12),
              if (controller.error != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OnesColors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    '${t.translate('common.error')}: ${controller.error}',
                    style: const TextStyle(color: OnesColors.danger),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!controller.loading)
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
                        itemCount: nextEvents.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: childAspectRatio,
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
                              return _UpcomingCard(
                                title: e.title,
                                location: e.location,
                                imageUrl: (url != null && url.isNotEmpty)
                                    ? url
                                    : null,
                                fallbackAsset: _defaultEventCoverAsset,
                                dateText: _formatMonthDayYear(when),
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
              if (controller.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBell;

  const _Header({required this.onBell});

  @override
  Widget build(BuildContext context) {
    final invitations = context.watch<InvitationsController>();
    final unread = invitations.unreadCount;

    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.center,
            child: Image(
              image: AssetImage('assets/splash/symbol_purple.png'),
              width: 120,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onBell,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none),
                      if (unread > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: OnesColors.danger,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              style: const TextStyle(
                                color: OnesColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: OnesColors.white.withOpacity(0.60),
        borderRadius: BorderRadius.zero,
      ),
      child: Center(child: Text(t.translate('home.no_upcoming_events'))),
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

String _formatTimeOfDay(DateTime dt) => formatTimeOfDay(dt);

String _formatMonthDayYear(DateTime dt) => formatMonthDayYear(dt);
