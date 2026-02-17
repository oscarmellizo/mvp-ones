import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../events_controller.dart';
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
    final event = controller.selected;

    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 520 ? 28.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
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
                          subtitle: _fakeSubtitle(event.createdAt),
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
                                  createdAt: event.createdAt,
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

String _fakeSubtitle(DateTime createdAt) {
  final date = _formatMonthDayYear(createdAt);
  return '$date • NYC';
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
  final DateTime createdAt;

  const _DetailsTab({required this.title, required this.createdAt});

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final List<_Invitee> _invitees = [
    const _Invitee(name: 'Andrea', email: 'andrea@example.com'),
    const _Invitee(name: 'Luis', email: 'luis@example.com'),
  ];

  String? _inviteError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _addInvitee() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    final normalizedEmail = email.toLowerCase();

    if (name.isEmpty || email.isEmpty) {
      setState(() {
        _inviteError = 'Please enter name and email.';
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

    setState(() {
      _invitees.insert(0, _Invitee(name: name, email: normalizedEmail));
      _inviteError = null;
      _nameController.clear();
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
    final start = widget.createdAt.add(const Duration(days: 2));
    final end = widget.createdAt.add(const Duration(days: 2, hours: 5));

    return ListView(
      children: [
        _DetailsCard(
          title: 'Event Details',
          children: [
            _DetailRow(label: 'Event Name', value: widget.title),
            _DetailRow(label: 'Event Type', value: 'Birthday Party'),
            _DetailRow(label: 'Starts', value: _formatMonthDayYear(start)),
            _DetailRow(label: 'Ends', value: _formatMonthDayYear(end)),
            const _DetailRow(label: 'Location', value: 'NYC'),
            const _DetailRow(label: 'Allow Guests to Upload', value: 'Yes'),
          ],
        ),
        const SizedBox(height: 14),
        _DetailsCard(
          title: 'Invite Guests',
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Name',
                      filled: true,
                      fillColor: const Color(0xFFF7F3EA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addInvitee(),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      filled: true,
                      fillColor: const Color(0xFFF7F3EA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
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
                onPressed: _addInvitee,
                child: const Text(
                  'Invite',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
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
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      invitee.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      invitee.email,
                      style: TextStyle(color: Colors.black.withOpacity(0.6)),
                    ),
                    trailing: IconButton(
                      onPressed: () => _removeInvitee(invitee),
                      icon: const Icon(Icons.close),
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

  const _Invitee({required this.name, required this.email});
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
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
