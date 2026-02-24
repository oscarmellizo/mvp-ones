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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              _Header(
                onBell: () => showInvitationsSheet(context),
                onDevice: () {},
              ),
              const SizedBox(height: 14),
              _SearchBar(controller: _searchController),
              const SizedBox(height: 18),
              const _SectionHeader(title: 'Today'),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: controller.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: todayCards.isEmpty ? 1 : todayCards.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
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
                                timeText:
                                    '${_formatTimeOfDay(displayStart)} - ${_formatTimeOfDay(displayEnd)}',
                                badgeText: isLiveNow ? 'LIVE NOW' : null,
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
              const _SectionHeader(title: 'Next Events'),
              const SizedBox(height: 12),
              if (controller.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Error: ${controller.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!controller.loading)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: nextEvents.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.30,
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
                        return _NextEventCard(
                          title: e.title,
                          dateText: _formatMonthDayYear(when),
                          timeText:
                              '${_formatTimeOfDay(when)} - ${_formatTimeOfDay(end)}',
                          location: e.location,
                          imageUrl:
                              (url != null && url.isNotEmpty) ? url : null,
                          fallbackAsset: cover,
                          onTap: () => Navigator.of(context).pushNamed(
                            EventDetailPage.routeName,
                            arguments: e.id,
                          ),
                        );
                      },
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
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search events...',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(26),
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
  final String timeText;
  final VoidCallback onTap;

  const _UpcomingCard({
    required this.title,
    required this.location,
    required this.imageUrl,
    required this.fallbackAsset,
    required this.timeText,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        width: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
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
                borderRadius: BorderRadius.circular(26),
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
                        borderRadius: BorderRadius.circular(18),
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

class _NextEventCard extends StatelessWidget {
  final String title;
  final String dateText;
  final String timeText;
  final String location;
  final String? imageUrl;
  final String fallbackAsset;
  final VoidCallback onTap;

  const _NextEventCard({
    required this.title,
    required this.dateText,
    required this.timeText,
    required this.location,
    required this.imageUrl,
    required this.fallbackAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: SizedBox(
                height: 52,
                width: double.infinity,
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 13,
                          color: Colors.black.withOpacity(0.55),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dateText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: Colors.black.withOpacity(0.55),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            timeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 13,
                          color: Colors.black.withOpacity(0.55),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
