import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/auth_controller.dart';

import '../events_controller.dart';
import '../events_metadata_controller.dart';
import 'photo_capture_page.dart';

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
  bool _metadataLoadTriggered = false;

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
    final metadataController = context.watch<EventsMetadataController>();
    final event = controller.selected;

    if (!_metadataLoadTriggered) {
      _metadataLoadTriggered = true;
      Future.microtask(() async {
        try {
          await metadataController.ensureLoaded();
        } catch (_) {
          // ignore
        }
      });
    }

    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 520 ? 28.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4B64E),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6A0D73),
        foregroundColor: Colors.white,
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
                          onBell: () {},
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
                                  title: event.title,
                                  eventType: _eventTypeLabel(
                                    metadataController,
                                    event.eventTypeId,
                                  ),
                                  startAt: event.startAt,
                                  endAt: event.endAt,
                                  location: event.location,
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
  final date = _formatMonthDayYear(startAt.toLocal());
  final loc = location.trim().isEmpty ? '-' : location.trim();
  return '$date • $loc';
}

String _eventTypeLabel(
    EventsMetadataController controller, String eventTypeId) {
  final metadata = controller.metadata;
  if (metadata == null) return eventTypeId;

  for (final c in metadata.categories) {
    for (final t in c.eventTypes) {
      if (t.id == eventTypeId) return t.label;
    }
  }
  return eventTypeId;
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

String _formatTimeOfDay(DateTime dt) {
  final hour = dt.hour;
  final minute = dt.minute;
  final isPm = hour >= 12;
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final mm = minute.toString().padLeft(2, '0');
  final suffix = isPm ? 'PM' : 'AM';
  return '$h12:$mm $suffix';
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  fontWeight: FontWeight.w600,
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
              icon: const Icon(Icons.notifications_none, color: Colors.black),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE25555),
                  shape: BoxShape.circle,
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
        color: Colors.black.withOpacity(0.04),
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
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
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
            color: selected ? const Color(0xFF6A0D73) : Colors.black54,
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
      final dateStr = _formatShortDate(e.takenAt).toLowerCase();
      return dateStr.contains(q);
    }).toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchRow(controller: widget.searchController),
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

  String _formatShortDate(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$mm/$dd/${dt.year}';
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController controller;

  const _SearchRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Search by attendee or date',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
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
                  color: Color(0xFF6A0D73),
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
                0 => const Color(0xFF6A0D73),
                1 => const Color(0xFF58C7C7),
                _ => const Color(0xFFFFB74D)
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
                      bg: Colors.black.withOpacity(0.65),
                      fg: Colors.white,
                    ),
                  if (item.isRaw) const SizedBox(width: 8),
                  if (isNew)
                    const _TopPill(
                      text: 'NEW',
                      bg: Color(0xFFFFC857),
                      fg: Colors.black,
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
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white),
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
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        author,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _DetailsTab extends StatefulWidget {
  final String title;
  final String eventType;
  final DateTime startAt;
  final DateTime endAt;
  final String location;

  const _DetailsTab({
    required this.title,
    required this.eventType,
    required this.startAt,
    required this.endAt,
    required this.location,
  });

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  final _emailController = TextEditingController();

  final List<_Invitee> _invitees = [];

  String? _inviteError;

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

    if (!_looksLikeEmail(normalizedEmail)) {
      setState(() {
        _inviteError = 'Please enter a valid email.';
      });
      return;
    }

    final alreadyExists =
        _invitees.any((i) => i.email.toLowerCase() == normalizedEmail);
    if (alreadyExists) {
      setState(() {
        _inviteError = 'This email is already invited.';
      });
      return;
    }

    final auth = context.read<AuthController>();
    String displayName = normalizedEmail;
    try {
      final lookup = await auth.lookupUserByEmail(normalizedEmail);
      final pn = lookup?.preferredName?.trim();
      if (pn != null && pn.isNotEmpty) {
        displayName = pn;
      }
    } catch (_) {
      // ignore lookup errors and fall back to email
    }

    if (!mounted) return;
    setState(() {
      _invitees.insert(
        0,
        _Invitee(
          name: displayName,
          email: normalizedEmail,
          accepted: false,
        ),
      );
      _inviteError = null;
      _emailController.clear();
      FocusScope.of(context).unfocus();
    });
  }

  void _removeInvitee(_Invitee invitee) {
    setState(() {
      _invitees.removeWhere((i) => i.email == invitee.email);
    });
  }

  bool _looksLikeEmail(String value) {
    final v = value.trim();
    if (!v.contains('@')) return false;
    if (v.startsWith('@') || v.endsWith('@')) return false;
    if (!v.contains('.')) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.startAt.toLocal();
    final end = widget.endAt.toLocal();
    final location = widget.location.trim().isEmpty ? '-' : widget.location;

    return ListView(
      children: [
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
                    label: 'Event Type',
                    value: widget.eventType,
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
                        '${_formatMonthDayYear(start)} • ${_formatTimeOfDay(start)}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReadOnlyField(
                    label: 'Ends',
                    value:
                        '${_formatMonthDayYear(end)} • ${_formatTimeOfDay(end)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReadOnlyField(label: 'Location', value: location),
          ],
        ),
        const SizedBox(height: 14),
        _DetailsCard(
          title: 'Invite Guests',
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                _addInvitee();
              },
              decoration: InputDecoration(
                hintText: 'Email (required)',
                filled: true,
                fillColor: const Color(0xFFF7F3EA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            if (_inviteError != null) ...[
              const SizedBox(height: 10),
              Text(
                _inviteError!,
                style: const TextStyle(
                  color: Color(0xFFE25555),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6A0D73),
                  foregroundColor: Colors.white,
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
            const SizedBox(height: 14),
            const Text(
              'Invited',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (_invitees.isEmpty)
              Text(
                'No invited guests yet.',
                style: TextStyle(color: Colors.black.withOpacity(0.55)),
              )
            else
              ListView.separated(
                itemCount: _invitees.length,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                separatorBuilder: (_, __) => Divider(
                  height: 14,
                  color: Colors.black.withOpacity(0.06),
                ),
                itemBuilder: (context, index) {
                  final invitee = _invitees[index];
                  final statusText = invitee.accepted ? 'Accepted' : 'Pending';
                  final statusBg = invitee.accepted
                      ? const Color(0xFF58C7C7)
                      : const Color(0xFFFFC857);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      invitee.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      invitee.email,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            statusText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => _removeInvitee(invitee),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
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

class _Invitee {
  final String name;
  final String email;
  final bool accepted;

  const _Invitee(
      {required this.name, required this.email, required this.accepted});
}

class _DetailsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
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

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.isEmpty ? '-' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black.withOpacity(0.55),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Colors.black,
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
