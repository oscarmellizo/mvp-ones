import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_card.dart';
import '../../../../core/ui/widgets/ones_search_field.dart';
import '../../../../core/ui/widgets/ones_text_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import 'photo_capture_page.dart';
import '../../../invitations/presentation/widgets/invitations_sheet.dart';
import '../../../invitations/presentation/invitations_controller.dart';
import '../../domain/events_repository.dart';

class EventDetailPage extends StatefulWidget {
  static const routeName = '/events/detail';

  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  int _tabIndex = 0;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventsController>().select(widget.eventId);
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
    final auth = context.watch<AuthController>();
    final event = controller.selected;

    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 520 ? 28.0 : 16.0;

    return Scaffold(
      backgroundColor: OnesColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: OnesColors.purpleMid,
        foregroundColor: OnesColors.white,
        onPressed: event == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoCapturePage(eventId: event.id),
                  ),
                ),
        child: const Icon(Icons.photo_camera),
      ),
      body: SafeArea(
        child: controller.loading
            ? const Center(child: CircularProgressIndicator())
            : event == null
                ? Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Text('No event (error: ${controller.error})'),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            horizontalPadding, 6, horizontalPadding, 10),
                        child: _Header(
                          title: event.title,
                          subtitle:
                              _eventSubtitle(event.startAt, event.location),
                          onBack: () => Navigator.of(context).pop(),
                          onBell: () => showInvitationsSheet(context),
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: _Tabs(
                          index: _tabIndex,
                          onChanged: (i) => setState(() => _tabIndex = i),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding),
                          child: _tabIndex == 0
                              ? _GalleryTab(
                                  eventId: event.id,
                                  searchController: _searchController,
                                )
                              : _DetailsTab(
                                  eventId: event.id,
                                  coverKey: event.coverKey,
                                  title: event.title,
                                  eventType: event.objective,
                                  startAt: event.startAt,
                                  endAt: event.endAt,
                                  location: event.location,
                                  isOwner: auth.user?.userId == event.ownerId,
                                  allowGuestInvites: event.allowGuestInvites,
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

String _eventSubtitle(DateTime startAt, String location) {
  final date = formatMonthDayYear(startAt.toLocal());
  final loc = location.trim().isEmpty ? '-' : location.trim();
  return '$date • $loc';
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onBell;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    final invitations = context.watch<InvitationsController>();
    final unread = invitations.unreadCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: OnesColors.black),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      letterSpacing: 0.6,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: OnesColors.black.withOpacity(0.55),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onBell,
              icon:
                  const Icon(Icons.notifications_none, color: OnesColors.black),
            ),
            if (unread > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _Tabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: OnesColors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Gallery',
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Details',
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? OnesColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: OnesColors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? OnesColors.purpleMid : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _GalleryTab extends StatefulWidget {
  final String eventId;
  final TextEditingController searchController;

  const _GalleryTab({required this.eventId, required this.searchController});

  @override
  State<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<_GalleryTab> {
  static const _authors = [
    'Oscar',
    'Andrea',
    'Camila',
    'Luis',
    'Sofia',
  ];

  late final List<_GalleryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = _buildItems();
    widget.searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  List<_GalleryItem> _buildItems() {
    final now = DateTime.now();
    final raw = <_GalleryItem>[];
    for (var i = 0; i < 24; i++) {
      final takenAt = now.subtract(Duration(minutes: i * 7));
      raw.add(
        _GalleryItem(
          id: 'm_$i',
          asset:
              i.isEven ? 'assets/auth/amigos.png' : 'assets/auth/concierto.png',
          takenAt: takenAt,
          author: _authors[i % _authors.length],
          isVideo: i % 5 == 0,
          isRaw: i % 7 == 0,
        ),
      );
    }
    raw.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.searchController.text.trim().toLowerCase();
    final filtered = _items.where((e) {
      if (q.isEmpty) return true;
      if (e.author.toLowerCase().contains(q)) return true;
      final dateStr = formatShortDate(e.takenAt).toLowerCase();
      return dateStr.contains(q);
    }).toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OnesSearchField(
                controller: widget.searchController,
                hintText: 'Search by attendee or date',
              ),
              const SizedBox(height: 14),
              const _HighlightsSection(),
              const SizedBox(height: 14),
            ],
          ),
        ),
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = filtered[index];
              final isNew = DateTime.now().difference(item.takenAt) <
                  const Duration(minutes: 15);
              return _MediaTile(
                item: item,
                isNew: isNew,
                onTap: () {},
              );
            },
            childCount: filtered.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.86,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'HIGHLIGHTS',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: const Text(
                'View Reel',
                style: TextStyle(
                  color: OnesColors.purpleMid,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final title = switch (index) {
                0 => 'Opening',
                1 => 'DJ Set',
                _ => 'Drinks'
              };
              final asset = switch (index) {
                0 => 'assets/auth/amigos.png',
                1 => 'assets/auth/concierto.png',
                _ => 'assets/auth/amigos.png'
              };
              final ring = switch (index) {
                0 => OnesColors.purpleMid,
                1 => OnesColors.green,
                _ => OnesColors.yellowSoft
              };

              return _HighlightChip(
                title: title,
                asset: asset,
                ring: ring,
                onTap: () {},
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final String title;
  final String asset;
  final Color ring;
  final VoidCallback onTap;

  const _HighlightChip({
    required this.title,
    required this.asset,
    required this.ring,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 2.5),
            ),
            child: ClipOval(
              child: Image.asset(asset, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final _GalleryItem item;
  final bool isNew;
  final VoidCallback onTap;

  const _MediaTile({
    required this.item,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: AssetImage(item.asset),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  if (item.isRaw)
                    _TopPill(
                      text: 'RAW',
                      bg: OnesColors.black.withOpacity(0.65),
                      fg: OnesColors.white,
                    ),
                  if (item.isRaw) const SizedBox(width: 8),
                  if (isNew)
                    const _TopPill(
                      text: 'NEW',
                      bg: OnesColors.yellowSoft,
                      fg: OnesColors.black,
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: _BottomAuthorChip(author: item.author),
            ),
            if (item.isVideo)
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: OnesColors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: OnesColors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _TopPill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, color: fg, fontSize: 12),
      ),
    );
  }
}

class _BottomAuthorChip extends StatelessWidget {
  final String author;

  const _BottomAuthorChip({required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: OnesColors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        author,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DetailsTab extends StatefulWidget {
  final String eventId;
  final String? coverKey;
  final String title;
  final String eventType;
  final DateTime startAt;
  final DateTime endAt;
  final String location;
  final bool isOwner;
  final bool allowGuestInvites;

  const _DetailsTab({
    required this.eventId,
    required this.coverKey,
    required this.title,
    required this.eventType,
    required this.startAt,
    required this.endAt,
    required this.location,
    required this.isOwner,
    required this.allowGuestInvites,
  });

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  final _emailController = TextEditingController();

  Future<List<EventGuest>>? _guestsFuture;

  String? _inviteError;

  @override
  void initState() {
    super.initState();
    _refreshGuests();
  }

  void _refreshGuests() {
    setState(() {
      _guestsFuture =
          context.read<EventsRepository>().listEventGuests(widget.eventId);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addInvitee() async {
    final email = _emailController.text.trim();

    final normalizedEmail = email.toLowerCase();

    if (email.isEmpty) {
      setState(() {
        _inviteError = 'Please enter an email.';
      });
      return;
    }

    if (!looksLikeEmail(normalizedEmail)) {
      setState(() {
        _inviteError = 'Please enter a valid email.';
      });
      return;
    }

    final repo = context.read<EventsRepository>();
    try {
      setState(() {
        _inviteError = null;
      });
      await repo.inviteEventGuests(widget.eventId, [normalizedEmail]);
      if (!mounted) return;
      _emailController.clear();
      FocusScope.of(context).unfocus();
      _refreshGuests();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inviteError = 'Failed to invite guest.';
      });
    }

    if (!mounted) return;
    setState(() {
      _inviteError = null;
      _emailController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final coverUrls = context.watch<EventCoverUrlsController>();

    final start = widget.startAt.toLocal();
    final end = widget.endAt.toLocal();
    final location = widget.location.trim().isEmpty ? '-' : widget.location;
    final description =
        widget.eventType.trim().isEmpty ? '-' : widget.eventType;

    return ListView(
      children: [
        if (widget.coverKey != null && widget.coverKey!.trim().isNotEmpty) ...[
          FutureBuilder<String?>(
            future: coverUrls.getUrlIfAny(
              eventId: widget.eventId,
              coverKey: widget.coverKey,
            ),
            builder: (context, snapshot) {
              final url = snapshot.data;
              if (url == null || url.isEmpty) {
                return const SizedBox.shrink();
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(url, fit: BoxFit.cover),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
        ],
        _DetailsCard(
          title: 'Event Details',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ReadOnlyField(
                    label: 'Event Name',
                    value: widget.title,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReadOnlyField(
                    label: 'Location',
                    value: location,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ReadOnlyField(
                    label: 'Starts',
                    value:
                        '${formatMonthDayYear(start)} • ${formatTimeOfDay(start)}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReadOnlyField(
                    label: 'Ends',
                    value:
                        '${formatMonthDayYear(end)} • ${formatTimeOfDay(end)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReadOnlyField(
              label: 'Description',
              value: description,
              maxLines: null,
              overflow: null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DetailsCard(
          title: 'Invite Guests',
          children: [
            if (widget.isOwner || widget.allowGuestInvites) ...[
              OnesTextField(
                controller: _emailController,
                hintText: 'Email (required)',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                fillColor: OnesColors.yellowLight.withOpacity(0.35),
                borderSide: BorderSide.none,
                onSubmitted: (_) {
                  _addInvitee();
                },
              ),
              if (_inviteError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _inviteError!,
                  style: const TextStyle(
                    color: OnesColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OnesColors.purpleMid,
                    foregroundColor: OnesColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    _addInvitee();
                  },
                  child: const Text(
                    'Invite',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Guests',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<EventGuest>>(
              future: _guestsFuture,
              builder: (context, snapshot) {
                final guests = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Failed to load guests.',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.55)),
                  );
                }

                if (guests == null || guests.isEmpty) {
                  return Text(
                    'No guests yet.',
                    style: TextStyle(color: OnesColors.black.withOpacity(0.55)),
                  );
                }

                return ListView.separated(
                  itemCount: guests.length,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  separatorBuilder: (_, __) => Divider(
                    height: 14,
                    color: OnesColors.black.withOpacity(0.06),
                  ),
                  itemBuilder: (context, index) {
                    final g = guests[index];
                    final title = (g.displayName != null &&
                            g.displayName!.trim().isNotEmpty)
                        ? g.displayName!.trim()
                        : (g.email ?? '-');
                    final subtitle = g.email ?? '';

                    final isOwner = g.role == 'owner';
                    final statusText = isOwner
                        ? 'Owner'
                        : switch (g.status) {
                            'accepted' => 'Accepted',
                            'rejected' => 'Rejected',
                            'invited' => 'Invited',
                            _ => g.status,
                          };

                    final statusBg = isOwner
                        ? OnesColors.purpleMid
                        : switch (g.status) {
                            'accepted' => OnesColors.green,
                            'rejected' => OnesColors.danger,
                            _ => OnesColors.yellowSoft,
                          };

                    final statusFg =
                        isOwner ? OnesColors.white : OnesColors.black;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(
                              subtitle,
                              style: TextStyle(
                                color: OnesColors.black.withOpacity(0.6),
                              ),
                            ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: statusFg,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return OnesCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final int? maxLines;
  final TextOverflow? overflow;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isEmpty ? '-' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: OnesColors.black.withOpacity(0.55),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          v,
          maxLines: maxLines,
          overflow: overflow,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: OnesColors.black,
          ),
        ),
      ],
    );
  }
}

class _GalleryItem {
  final String id;
  final String asset;
  final DateTime takenAt;
  final String author;
  final bool isVideo;
  final bool isRaw;

  const _GalleryItem({
    required this.id,
    required this.asset,
    required this.takenAt,
    required this.author,
    required this.isVideo,
    required this.isRaw,
  });
}
