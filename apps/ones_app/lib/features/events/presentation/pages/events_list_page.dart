import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../events_controller.dart';
import 'event_detail_page.dart';

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

    final events = controller.events;
    final upcoming = events.take(3).toList(growable: false);
    final galleries = events.skip(3).toList(growable: false);

    return ColoredBox(
      color: _bg,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => controller.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              _Header(
                onBell: () {},
                onDevice: () {},
              ),
              const SizedBox(height: 14),
              _SearchBar(controller: _searchController),
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'This Weekend',
                actionText: 'See All',
                onAction: () {},
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: controller.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: upcoming.isEmpty ? 1 : upcoming.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          if (upcoming.isEmpty) {
                            return const _EmptyCard();
                          }

                          final e = upcoming[index];
                          final cover = index.isEven
                              ? 'assets/auth/concierto.png'
                              : 'assets/auth/amigos.png';
                          return _UpcomingCard(
                            title: e.title,
                            location: 'Brooklyn, NY',
                            imageAsset: cover,
                            badgeText: 'LIVE NOW',
                            onTap: () => Navigator.of(context).pushNamed(
                              EventDetailPage.routeName,
                              arguments: e.id,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 22),
              const _SectionHeader(title: 'Your Galleries'),
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
                ...List.generate(
                  (galleries.isEmpty ? events : galleries).length,
                  (i) {
                    final e = (galleries.isEmpty ? events : galleries)[i];
                    final privacy = _privacyForIndex(i);
                    final count = 24 + (i * 7);
                    final isPhotos = i.isEven;
                    final thumb = i.isEven
                        ? 'assets/auth/amigos.png'
                        : 'assets/auth/concierto.png';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GalleryRow(
                        title: e.title,
                        privacy: privacy,
                        countText: '$count ${isPhotos ? 'Photos' : 'Videos'}',
                        thumbAsset: thumb,
                        onTap: () => Navigator.of(context).pushNamed(
                          EventDetailPage.routeName,
                          arguments: e.id,
                        ),
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
    return Row(
      children: [
        const Image(
          image: AssetImage('assets/splash/symbol_purple.png'),
          width: 56,
        ),
        const Spacer(),
        IconButton(
          onPressed: onBell,
          icon: const Icon(Icons.notifications_none),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onDevice,
          icon: const Icon(Icons.phone_android),
        ),
      ],
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
  final String? actionText;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionText,
    this.onAction,
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
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionText!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF3B1D6D),
              ),
            ),
          ),
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
  final String imageAsset;
  final String badgeText;
  final VoidCallback onTap;

  const _UpcomingCard({
    required this.title,
    required this.location,
    required this.imageAsset,
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
          image: DecorationImage(
            image: AssetImage(imageAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  badgeText,
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
                  const Icon(Icons.location_on, size: 16, color: Colors.white),
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
      ),
    );
  }
}

class _GalleryRow extends StatelessWidget {
  final String title;
  final _Privacy privacy;
  final String countText;
  final String thumbAsset;
  final VoidCallback onTap;

  const _GalleryRow({
    required this.title,
    required this.privacy,
    required this.countText,
    required this.thumbAsset,
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  thumbAsset,
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
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _PrivacyChip(privacy: privacy),
                        const SizedBox(width: 10),
                        Text(
                          countText,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.55),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Privacy { private, public, shared }

_Privacy _privacyForIndex(int i) {
  if (i % 3 == 0) return _Privacy.private;
  if (i % 3 == 1) return _Privacy.public;
  return _Privacy.shared;
}

class _PrivacyChip extends StatelessWidget {
  final _Privacy privacy;

  const _PrivacyChip({required this.privacy});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (privacy) {
      _Privacy.private => (
          'Private',
          const Color(0xFFE9DDFF),
          const Color(0xFF4D2B8E),
        ),
      _Privacy.public => (
          'Public',
          const Color(0xFFD8F5DF),
          const Color(0xFF1B7B3E),
        ),
      _Privacy.shared => (
          'Shared',
          const Color(0xFFE1E3FF),
          const Color(0xFF2E3CC7),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
