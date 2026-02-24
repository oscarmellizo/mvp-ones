import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import 'event_detail_page.dart';
import '../../../invitations/presentation/widgets/invitations_sheet.dart';
import '../../../invitations/presentation/invitations_controller.dart';

class EventsListPage extends StatefulWidget {
  static const routeName = '/events';

  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  static const _bg = Color(0xFFF4B64E);
  static const _divider = Color(0xFFE9A52E);

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

    final todayCards = todayEvents.take(3).toList(growable: false);

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
                  onDevice: () {},
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SearchBar(controller: _searchController),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(title: 'Today'),
              ),
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
                          final cover = index.isEven
                              ? 'assets/auth/concierto.png'
                              : 'assets/auth/amigos.png';

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
                                dateText: null,
                                timeText:
                                    '${_formatTimeOfDay(displayStart)} - ${_formatTimeOfDay(displayEnd)}',
                                badgeText: isLiveNow ? 'LIVE NOW' : null,
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _SectionHeader(title: 'Next Events'),
              ),
              const SizedBox(height: 12),
              if (controller.error != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    'Error: ${controller.error}',
                    style: const TextStyle(color: Colors.red),
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
  final VoidCallback onDevice;

  const _Header({required this.onBell, required this.onDevice});

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
                              color: Color(0xFFE25555),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDevice,
                  icon: const Icon(Icons.phone_android),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Search events...',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3B1D6D),
              ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0x99FFFFFF),
        borderRadius: BorderRadius.zero,
      ),
      child: const Center(child: Text('No upcoming events')),
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
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.65),
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
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
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
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateText!,
                          style: const TextStyle(
                            color: Colors.white,
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
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeText,
                        style: const TextStyle(
                          color: Colors.white,
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
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.white,
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
  final hour = dt.hour;
  final minute = dt.minute;
  final isPm = hour >= 12;
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final mm = minute.toString().padLeft(2, '0');
  final suffix = isPm ? 'PM' : 'AM';
  return '$h12:$mm $suffix';
}

String _formatMonthDayYear(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
