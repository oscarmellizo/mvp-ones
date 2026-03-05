import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_text_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../photos/presentation/pages/photo_viewer_page.dart';
import '../../../photos/presentation/photos_gallery_controller.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import '../widgets/event_detail_details_widgets.dart';
import '../widgets/event_detail_header.dart';
import '../widgets/event_detail_tabs.dart';
import 'photo_capture_page.dart';
import '../../../invitations/presentation/widgets/invitations_sheet.dart';
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
            : () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoCapturePage(eventId: event.id),
                  ),
                );
                if (!context.mounted) return;
                await context
                    .read<PhotosGalleryController>()
                    .refreshMerged(eventId: event.id);
              },
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
                        child: EventDetailHeader(
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
                        child: EventDetailTabs(
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

class _GalleryTab extends StatefulWidget {
  final String eventId;
  final TextEditingController searchController;

  const _GalleryTab({required this.eventId, required this.searchController});

  @override
  State<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<_GalleryTab> {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<PhotosGalleryController>()
          .refreshMerged(eventId: widget.eventId);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotosGalleryController>();

    if (!controller.loading &&
        controller.error == null &&
        controller.items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<PhotosGalleryController>()
            .refreshMerged(eventId: widget.eventId);
      });
    }

    if (controller.loading && controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error cargando galería: ${controller.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    controller.refreshMerged(eventId: widget.eventId),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.refreshMerged(eventId: widget.eventId),
      child: Container(
        color: OnesColors.background,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            childAspectRatio: 1,
          ),
          itemCount: controller.items.length,
          itemBuilder: (context, index) {
            final item = controller.items[index];
            final small = item.smallUrl;
            final medium = item.mediumUrl;
            final fallback = item.originalUrl;

            final thumbUrl = (small != null && small.isNotEmpty)
                ? small
                : (medium != null && medium.isNotEmpty)
                    ? medium
                    : fallback;

            final viewerUrl = (medium != null && medium.isNotEmpty)
                ? medium
                : (fallback ?? small);

            return InkWell(
              onTap: (viewerUrl == null || viewerUrl.isEmpty)
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PhotoViewerPage(imageUrl: viewerUrl),
                        ),
                      ),
              borderRadius: BorderRadius.zero,
              child: Ink(
                color: Colors.black12,
                child: (thumbUrl == null || thumbUrl.isEmpty)
                    ? const SizedBox.expand()
                    : Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) {
                          return const SizedBox.expand();
                        },
                      ),
              ),
            );
          },
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
                borderRadius: BorderRadius.zero,
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
        EventDetailSectionCard(
          title: 'Event Details',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ReadOnlyField(
                    label: 'Event Name',
                    value: widget.title,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReadOnlyField(
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
                  child: ReadOnlyField(
                    label: 'Starts',
                    value:
                        '${formatMonthDayYear(start)} • ${formatTimeOfDay(start)}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReadOnlyField(
                    label: 'Ends',
                    value:
                        '${formatMonthDayYear(end)} • ${formatTimeOfDay(end)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReadOnlyField(
              label: 'Description',
              value: description,
              maxLines: null,
              overflow: null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        EventDetailSectionCard(
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
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
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
                          borderRadius: BorderRadius.zero,
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
