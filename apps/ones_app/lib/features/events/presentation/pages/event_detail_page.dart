import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_text_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../photos/presentation/pages/photo_viewer_page.dart';
import '../../../photos/presentation/photos_gallery_controller.dart';
import '../../../photos/presentation/photos_upload_controller.dart';
import '../../../photos/presentation/photos_ws_controller.dart';
import '../../../photos/domain/event_photo.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import '../widgets/event_detail_details_widgets.dart';
import '../widgets/event_detail_header.dart';
import '../widgets/event_detail_tabs.dart';
import 'photo_capture_page.dart';
import 'edit_event_page.dart';
import '../../../invitations/presentation/widgets/invitations_sheet.dart';
import '../../domain/events_repository.dart';
import '../../adapters/api/frames_api_repository.dart';

const String _defaultEventCoverAsset = 'assets/branding/ones-logo.png';

class EventDetailPage extends StatefulWidget {
  static const routeName = '/events/detail';

  final String eventId;
  final String? initialPhotoId;

  const EventDetailPage({
    super.key,
    required this.eventId,
    this.initialPhotoId,
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  int _tabIndex = 0;
  final _searchController = TextEditingController();
  bool _openedInitialPhoto = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhotoId != null &&
        widget.initialPhotoId!.trim().isNotEmpty) {
      _tabIndex = 0;
    }
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
    final currentUserId = auth.user?.userId;

    final deepLinkPhotoId = widget.initialPhotoId;

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
                    builder: (_) => PhotoCapturePage(
                      eventId: event.id,
                      frameIds: event.frameIds,
                    ),
                  ),
                );
                if (!context.mounted) return;
                await context
                    .read<PhotosGalleryController>()
                    .refresh(eventId: event.id);
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
                                  currentUserId: currentUserId,
                                  isOwner: auth.user?.userId == event.ownerId,
                                  searchController: _searchController,
                                  initialPhotoId: deepLinkPhotoId,
                                  openedInitialPhoto: _openedInitialPhoto,
                                  onOpenedInitialPhoto: () {
                                    if (_openedInitialPhoto) return;
                                    setState(() {
                                      _openedInitialPhoto = true;
                                    });
                                  },
                                )
                              : _DetailsTab(
                                  eventId: event.id,
                                  coverKey: event.coverKey,
                                  title: event.title,
                                  eventType: event.objective,
                                  startAt: event.startAt,
                                  endAt: event.endAt,
                                  location: event.location,
                                  frameIds: event.frameIds,
                                  isOwner: auth.user?.userId == event.ownerId,
                                  allowGuestInvites: event.allowGuestInvites,
                                  inviteLinkEnabled: event.inviteLinkEnabled,
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
  final String? currentUserId;
  final bool isOwner;
  final TextEditingController searchController;
  final String? initialPhotoId;
  final bool openedInitialPhoto;
  final Function onOpenedInitialPhoto;

  const _GalleryTab({
    required this.eventId,
    required this.currentUserId,
    required this.isOwner,
    required this.searchController,
    this.initialPhotoId,
    required this.openedInitialPhoto,
    required this.onOpenedInitialPhoto,
  });

  @override
  State<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<_GalleryTab> {
  bool _requested = false;
  bool _selecting = false;
  final Set<String> _selectedIds = {};

  final Set<String> _cleanupUploadPhotoIds = {};

  Future<List<EventGuest>>? _guestsFuture;

  late final List<Color> _badgePalette;
  final Map<String, Color> _badgeColorByIdentity = {};
  int _nextBadgeColorIndex = 0;

  PhotosWsController? _ws;
  Timer? _wsDebounce;

  Color _badgeColorForIdentity(String identity) {
    final trimmed = identity.trim();
    if (trimmed.isEmpty) {
      return _badgePalette.isEmpty ? OnesColors.purpleMid : _badgePalette.first;
    }

    final existing = _badgeColorByIdentity[trimmed];
    if (existing != null) return existing;

    final palette = _badgePalette;
    if (palette.isEmpty) return OnesColors.purpleMid;

    final idx = _nextBadgeColorIndex % palette.length;
    _nextBadgeColorIndex++;
    final c = palette[idx];
    _badgeColorByIdentity[trimmed] = c;
    return c;
  }

  Color _badgeTextColor(Color bg) {
    return bg.computeLuminance() > 0.55 ? Colors.black : Colors.white;
  }

  @override
  void initState() {
    super.initState();

    final palette = <Color>[
      Colors.blue,
      Colors.indigo,
      Colors.deepPurple,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.deepOrange,
      Colors.orange,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.cyan,
    ];

    palette.shuffle(Random());
    _badgePalette = palette;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PhotosGalleryController>().refresh(eventId: widget.eventId);

      final ws = context.read<PhotosWsController>();
      _ws = ws;
      ws.onPhotoReady = _onWsPhotoReady;
      ws.subscribe(eventId: widget.eventId);

      // Reuse existing guests listing used in Details tab, but load it here for filters.
      setState(() {
        _guestsFuture =
            context.read<EventsRepository>().listEventGuestsV2(widget.eventId);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _GalleryTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final eventChanged = oldWidget.eventId != widget.eventId;
    final userChanged = oldWidget.currentUserId != widget.currentUserId;
    if (!eventChanged && !userChanged) return;

    _exitSelectionMode();

    _badgeColorByIdentity.clear();
    _nextBadgeColorIndex = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PhotosGalleryController>().refresh(eventId: widget.eventId);

      final ws = _ws ?? context.read<PhotosWsController>();
      _ws = ws;
      ws.onPhotoReady = _onWsPhotoReady;
      if (eventChanged) {
        ws.unsubscribe(eventId: oldWidget.eventId);
      }
      ws.subscribe(eventId: widget.eventId);

      setState(() {
        _guestsFuture =
            context.read<EventsRepository>().listEventGuestsV2(widget.eventId);
      });
    });
  }

  @override
  void dispose() {
    _wsDebounce?.cancel();
    _wsDebounce = null;

    final ws = _ws;
    if (ws != null) {
      ws.unsubscribe(eventId: widget.eventId);
      if (ws.onPhotoReady == _onWsPhotoReady) {
        ws.onPhotoReady = null;
      }
    }
    super.dispose();
  }

  void _onWsPhotoReady(String eventId, String photoId) {
    if (!mounted) return;
    if (eventId != widget.eventId) return;

    _wsDebounce?.cancel();
    _wsDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<PhotosGalleryController>().refresh(eventId: widget.eventId);
    });
  }

  void _exitSelectionMode() {
    if (!_selecting && _selectedIds.isEmpty) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  bool _canSelect(String photoOwnerId) {
    final me = widget.currentUserId;
    if (widget.isOwner) return true;
    if (me == null || me.isEmpty) return false;
    return photoOwnerId == me;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PhotosGalleryController>();
    final uploader = context.watch<PhotosUploadController>();

    final remoteItems = controller.items;

    final deepLinkPhotoId = widget.initialPhotoId;
    if (!widget.openedInitialPhoto &&
        deepLinkPhotoId != null &&
        deepLinkPhotoId.trim().isNotEmpty &&
        remoteItems.isNotEmpty) {
      final idx =
          remoteItems.indexWhere((it) => it.photoId == deepLinkPhotoId.trim());
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.openedInitialPhoto) return;
          widget.onOpenedInitialPhoto();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PhotoViewerPage(
                eventId: widget.eventId,
                initialIndex: idx,
                currentUserId: widget.currentUserId,
              ),
            ),
          );
        });
      }
    }
    final remoteById = <String, EventPhoto>{
      for (final it in remoteItems) it.photoId: it,
    };

    DateTime parseIso(String s) {
      try {
        return DateTime.parse(s).toUtc();
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
    }

    final localActive = uploader.activeByEvent(widget.eventId);
    final localPathById = <String, String>{};
    final localCreatedAtById = <String, DateTime>{};
    final localById = <String, dynamic>{};
    for (final it in localActive) {
      if (it.photoId.isEmpty) continue;
      if (it.localPath.isEmpty) continue;
      localPathById[it.photoId] = it.localPath;
      localCreatedAtById[it.photoId] = parseIso(it.createdAt);
      localById[it.photoId] = it;
    }

    final doneLocal = <String>[];
    for (final it in localActive) {
      final pid = it.photoId;
      if (pid.isEmpty) continue;
      final remote = remoteById[pid];
      if (remote == null) continue;
      final status = (remote.status).trim().toLowerCase();
      if (status == 'ready' && !_cleanupUploadPhotoIds.contains(pid)) {
        doneLocal.add(pid);
      }
    }
    if (doneLocal.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final pid in doneLocal) {
          if (_cleanupUploadPhotoIds.contains(pid)) continue;
          _cleanupUploadPhotoIds.add(pid);
          uploader.markDoneByPhotoId(eventId: widget.eventId, photoId: pid);
        }
      });
    }

    final allPhotoIds = <String>{
      ...remoteById.keys,
      ...localPathById.keys,
    };

    final mergedIds = allPhotoIds.toList(growable: false);
    mergedIds.sort((a, b) {
      final da = remoteById[a]?.createdAt ?? localCreatedAtById[a];
      final db = remoteById[b]?.createdAt ?? localCreatedAtById[b];

      final safeA = da ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final safeB = db ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return safeB.compareTo(safeA);
    });

    if (controller.loading && remoteItems.isEmpty && localPathById.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!controller.loading &&
        controller.error == null &&
        controller.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Aún no hay fotos en este evento.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => controller.refresh(eventId: widget.eventId),
                child: const Text('Actualizar'),
              ),
            ],
          ),
        ),
      );
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
                onPressed: () => controller.refresh(eventId: widget.eventId),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<PhotosGalleryFilter>(
                      segments: const <ButtonSegment<PhotosGalleryFilter>>[
                        ButtonSegment(
                          value: PhotosGalleryFilter.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: PhotosGalleryFilter.sharedByMe,
                          label: Text('Shared'),
                        ),
                        ButtonSegment(
                          value: PhotosGalleryFilter.mine,
                          label: Text('Propias'),
                        ),
                      ],
                      selected: <PhotosGalleryFilter>{controller.filter},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) async {
                        final next = value.isEmpty
                            ? PhotosGalleryFilter.all
                            : value.first;
                        controller.setFilter(next);
                        controller.setGuestIds(<String>{});
                        await controller.refresh(eventId: widget.eventId);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    onPressed: controller.filter != PhotosGalleryFilter.all
                        ? null
                        : () async {
                            final guests = await _guestsFuture;
                            if (!context.mounted) return;
                            if (guests == null || guests.isEmpty) return;

                            final initial = controller.guestIds;
                            final selected =
                                await showModalBottomSheet<Set<String>>(
                              context: context,
                              isScrollControlled: true,
                              builder: (ctx) {
                                final tmp = <String>{...initial};
                                return StatefulBuilder(
                                  builder: (ctx, setModalState) {
                                    return SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 12, 16, 12),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Invitados',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Flexible(
                                              child: ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: guests.length,
                                                itemBuilder: (ctx, i) {
                                                  final g = guests[i];
                                                  final title =
                                                      (g.displayName != null &&
                                                              g.displayName!
                                                                  .trim()
                                                                  .isNotEmpty)
                                                          ? g.displayName!
                                                              .trim()
                                                          : (g.email ?? '-');

                                                  final gid = g.userId ?? '';
                                                  final enabled =
                                                      gid.isNotEmpty;
                                                  final checked =
                                                      tmp.contains(gid);

                                                  return CheckboxListTile(
                                                    value: checked,
                                                    onChanged: !enabled
                                                        ? null
                                                        : (v) {
                                                            setModalState(() {
                                                              if (v == true) {
                                                                tmp.add(gid);
                                                              } else {
                                                                tmp.remove(gid);
                                                              }
                                                            });
                                                          },
                                                    title: Text(title),
                                                    subtitle: g.email != null
                                                        ? Text(g.email!)
                                                        : null,
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(ctx)
                                                        .pop(<String>{});
                                                  },
                                                  child: const Text('Clear'),
                                                ),
                                                const Spacer(),
                                                FilledButton(
                                                  onPressed: () {
                                                    Navigator.of(ctx).pop(tmp);
                                                  },
                                                  child: const Text('Apply'),
                                                )
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );

                            if (selected == null) return;
                            controller.setGuestIds(selected);
                            await controller.refresh(eventId: widget.eventId);
                          },
                    child: const Text('Invitados'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.refresh(eventId: widget.eventId),
                child: Container(
                  color: OnesColors.background,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollUpdateNotification) {
                        final m = n.metrics;
                        final nearBottom = m.pixels >= m.maxScrollExtent - 400;
                        final canScroll = m.maxScrollExtent > 0;
                        if (canScroll &&
                            nearBottom &&
                            !controller.loading &&
                            controller.hasMore) {
                          controller.loadMore(eventId: widget.eventId);
                        }
                      }
                      return false;
                    },
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 1,
                        crossAxisSpacing: 1,
                        childAspectRatio: 1,
                      ),
                      itemCount: mergedIds.length,
                      itemBuilder: (context, index) {
                        final photoId = mergedIds[index];
                        final localPath = localPathById[photoId];
                        final remote = remoteById[photoId];
                        final remoteStatus =
                            (remote?.status ?? '').trim().toLowerCase();
                        final isRemoteReady =
                            remote != null && remoteStatus == 'ready';

                        final isLocalPending = localPath != null &&
                            localPath.isNotEmpty &&
                            !isRemoteReady;

                        final item =
                            !isLocalPending ? remoteById[photoId] : null;

                        final small = item?.smallUrl;
                        final medium = item?.mediumUrl;
                        final thumbUrl =
                            (small != null && small.isNotEmpty) ? small : null;
                        final viewerUrl = (medium != null && medium.isNotEmpty)
                            ? medium
                            : null;

                        final canSelect = (!isLocalPending && item != null)
                            ? _canSelect(item.guestId)
                            : false;
                        final isSelected = _selectedIds.contains(photoId);

                        void toggleSelected() {
                          if (!canSelect) return;
                          setState(() {
                            _selecting = true;
                            if (isSelected) {
                              _selectedIds.remove(photoId);
                              if (_selectedIds.isEmpty) {
                                _selecting = false;
                              }
                            } else {
                              _selectedIds.add(photoId);
                            }
                          });
                        }

                        return InkWell(
                          key: ValueKey(photoId),
                          onLongPress: canSelect ? toggleSelected : null,
                          onTap: () {
                            if (_selecting) {
                              toggleSelected();
                              return;
                            }

                            if (isLocalPending) {
                              return;
                            }
                            if (viewerUrl == null || viewerUrl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('La foto aún se está procesando.'),
                                ),
                              );
                              return;
                            }

                            final remoteIndex = remoteItems
                                .indexWhere((it) => it.photoId == photoId);
                            if (remoteIndex < 0) {
                              return;
                            }

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PhotoViewerPage(
                                  eventId: widget.eventId,
                                  initialIndex: remoteIndex,
                                  currentUserId: widget.currentUserId,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.zero,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Ink(
                                color: Colors.black12,
                                child: isLocalPending
                                    ? Image.file(
                                        File(localPath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) {
                                          return const SizedBox.expand();
                                        },
                                      )
                                    : (thumbUrl == null || thumbUrl.isEmpty)
                                        ? const Center(
                                            child: Text(
                                              'Procesando',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: thumbUrl,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 300,
                                            memCacheHeight: 300,
                                            errorWidget: (context, url, error) {
                                              return const SizedBox.expand();
                                            },
                                          ),
                              ),
                              if (isLocalPending)
                                Container(
                                  color: Colors.black.withOpacity(0.35),
                                  child: Center(
                                    child: () {
                                      final local = localById[photoId];
                                      final localStatus = (local?.status ?? '')
                                          .trim()
                                          .toLowerCase();
                                      final progress = uploader
                                          .uploadProgressByPhotoId(photoId);
                                      final isUploading =
                                          localStatus == 'uploading';

                                      final value =
                                          (isUploading && progress != null)
                                              ? progress
                                              : null;
                                      final pct =
                                          (isUploading && progress != null)
                                              ? (progress * 100).round()
                                              : null;

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              value: value,
                                              valueColor:
                                                  const AlwaysStoppedAnimation(
                                                      Colors.white),
                                            ),
                                          ),
                                          if (pct != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              '$pct%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    }(),
                                  ),
                                ),
                              if (_selecting)
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? OnesColors.purpleMid
                                          : Colors.black.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.85),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: OnesColors.white,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              if (item?.shared == true &&
                                  !(widget.currentUserId == null ||
                                      item?.sharedByUserId == null ||
                                      item?.sharedByUserId !=
                                          widget.currentUserId))
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    color: OnesColors.yellow.withOpacity(0.72),
                                    child: const Text(
                                      'Shared',
                                      style: TextStyle(
                                        color: OnesColors.black,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              if (item?.shared == true &&
                                  (widget.currentUserId == null ||
                                      item?.sharedByUserId == null ||
                                      item?.sharedByUserId !=
                                          widget.currentUserId))
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    color: _badgeColorForIdentity(
                                      (item!.guestId.isNotEmpty)
                                          ? item.guestId
                                          : ((item.ownerName ?? 'Invitado')
                                              .trim()),
                                    ).withOpacity(0.62),
                                    child: Text(
                                      (item.ownerName != null &&
                                              item.ownerName!.isNotEmpty)
                                          ? '${item.ownerName}'
                                          : 'Invitado',
                                      style: TextStyle(
                                        color: _badgeTextColor(
                                          _badgeColorForIdentity(
                                            (item.guestId.isNotEmpty)
                                                ? item.guestId
                                                : ((item.ownerName ??
                                                        'Invitado')
                                                    .trim()),
                                          ),
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              if (_selecting && !canSelect)
                                Container(
                                  color: Colors.black.withOpacity(0.15),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selecting)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              color: OnesColors.white,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.loading ? null : _exitSelectionMode,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: OnesColors.purpleMid,
                        foregroundColor: OnesColors.white,
                      ),
                      onPressed: (controller.loading || _selectedIds.isEmpty)
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ids = _selectedIds.toList(growable: false);

                              final selected = controller.items
                                  .where(
                                      (it) => _selectedIds.contains(it.photoId))
                                  .toList(growable: false);
                              final anyShared = selected.any((it) => it.shared);
                              final anyNotShared =
                                  selected.any((it) => !it.shared);

                              if (anyShared && anyNotShared) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No puedes mezclar fotos compartidas y privadas.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              try {
                                if (anyShared) {
                                  await context
                                      .read<PhotosGalleryController>()
                                      .unsharePhotos(
                                        eventId: widget.eventId,
                                        photoIds: ids,
                                      );
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Fotos descompartidas.'),
                                    ),
                                  );
                                } else {
                                  await context
                                      .read<PhotosGalleryController>()
                                      .sharePhotos(
                                        eventId: widget.eventId,
                                        photoIds: ids,
                                      );
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Fotos compartidas.'),
                                    ),
                                  );
                                }

                                _exitSelectionMode();
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo actualizar: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: Text(
                        (() {
                          final selected = controller.items
                              .where((it) => _selectedIds.contains(it.photoId))
                              .toList(growable: false);
                          final anyShared = selected.any((it) => it.shared);
                          final anyNotShared = selected.any((it) => !it.shared);

                          if (anyShared && !anyNotShared) {
                            return 'Unshare (${_selectedIds.length})';
                          }
                          return 'Share (${_selectedIds.length})';
                        })(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
  final List<String> frameIds;
  final bool isOwner;
  final bool allowGuestInvites;
  final bool inviteLinkEnabled;

  const _DetailsTab({
    required this.eventId,
    required this.coverKey,
    required this.title,
    required this.eventType,
    required this.startAt,
    required this.endAt,
    required this.location,
    required this.frameIds,
    required this.isOwner,
    required this.allowGuestInvites,
    required this.inviteLinkEnabled,
  });

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  final _emailController = TextEditingController();

  Future<List<EventGuest>>? _guestsFuture;
  Future<Map<String, String>>? _frameNamesFuture;
  Future<EventInviteLink>? _inviteLinkFuture;
  bool _updatingInviteLink = false;

  String? _inviteError;

  @override
  void initState() {
    super.initState();
    _refreshGuests();
    _refreshFrameNames();
    _refreshInviteLink();
  }

  void _refreshInviteLink() {
    if (!(widget.isOwner || widget.allowGuestInvites)) return;
    _inviteLinkFuture =
        context.read<EventsRepository>().getInviteLink(widget.eventId);
  }

  void _refreshFrameNames() {
    final ids = widget.frameIds;
    if (ids.isEmpty) {
      setState(() {
        _frameNamesFuture = Future.value(const <String, String>{});
      });
      return;
    }

    setState(() {
      _frameNamesFuture = _loadFrameNames(ids);
    });
  }

  Future<Map<String, String>> _loadFrameNames(List<String> frameIds) async {
    final wanted = frameIds.toSet();
    final resolved = <String, String>{};

    final repo = context.read<FramesApiRepository>();
    String? nextToken;

    for (int guard = 0; guard < 50; guard++) {
      final res = await repo.listFrames(limit: 50, nextToken: nextToken);
      for (final it in res.items) {
        if (!wanted.contains(it.frameId)) continue;
        final name = (it.name != null && it.name!.trim().isNotEmpty)
            ? it.name!.trim()
            : it.frameId;
        resolved[it.frameId] = name;
      }

      if (resolved.length >= wanted.length) break;
      nextToken = res.nextToken;
      if (nextToken == null || nextToken.isEmpty) break;
    }

    return resolved;
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
    final events = context.watch<EventsController>();

    Widget buildFallbackCover() {
      return ColoredBox(
        color: OnesColors.white,
        child: Center(
          child: Image.asset(
            _defaultEventCoverAsset,
            width: 84,
            height: 84,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final start = widget.startAt.toLocal();
    final end = widget.endAt.toLocal();
    final canInvite = (widget.isOwner || widget.allowGuestInvites) &&
        DateTime.now().toUtc().isBefore(widget.endAt.toUtc());
    final location = widget.location.trim().isEmpty ? '-' : widget.location;
    final description =
        widget.eventType.trim().isEmpty ? '-' : widget.eventType;

    return ListView(
      children: [
        FutureBuilder<String?>(
          future: coverUrls.getUrlIfAny(
            eventId: widget.eventId,
            coverKey: widget.coverKey,
          ),
          builder: (context, snapshot) {
            final url = snapshot.data;

            return ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: (url != null && url.isNotEmpty)
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => buildFallbackCover(),
                      )
                    : buildFallbackCover(),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        EventDetailSectionCard(
          title: 'Event Details',
          trailing: widget.isOwner
              ? IconButton(
                  tooltip: 'Editar',
                  onPressed: () async {
                    final current = events.selected;
                    if (current == null) return;

                    final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => EditEventPage(initial: current),
                      ),
                    );
                    if (!context.mounted) return;
                    if (saved == true) {
                      await context
                          .read<EventsController>()
                          .select(widget.eventId);
                      if (!context.mounted) return;
                      _refreshFrameNames();
                    }
                  },
                  icon: const Icon(
                    Icons.edit,
                    color: OnesColors.purpleDeep,
                  ),
                )
              : null,
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
          title: 'Frames',
          children: [
            FutureBuilder<Map<String, String>>(
              future: _frameNamesFuture,
              builder: (context, snapshot) {
                if (widget.frameIds.isEmpty) {
                  return const ReadOnlyField(
                    label: 'Selected frames',
                    value: '-',
                  );
                }

                final resolved = snapshot.data ?? const <String, String>{};
                final lines = widget.frameIds
                    .map((id) => resolved[id] ?? id)
                    .toList(growable: false);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected frames',
                      style: TextStyle(
                        color: OnesColors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...lines.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: OnesColors.black.withOpacity(0.75),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: OnesColors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        EventDetailSectionCard(
          title: 'Invite Guests',
          children: [
            if (canInvite) ...[
              FutureBuilder<EventInviteLink>(
                future: _inviteLinkFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    );
                  }

                  final link = snapshot.data;
                  if (snapshot.hasError || link == null || link.url.isEmpty) {
                    return const SizedBox(height: 0);
                  }

                  final canUseLink = link.enabled || widget.isOwner;

                  Future<void> onCopy() async {
                    await Clipboard.setData(ClipboardData(text: link.url));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied.')),
                    );
                  }

                  Future<void> onShare() async {
                    await Share.share(link.url);
                  }

                  Future<void> onToggle(bool enabled) async {
                    if (_updatingInviteLink) return;
                    setState(() {
                      _updatingInviteLink = true;
                    });
                    try {
                      final updated = await context
                          .read<EventsRepository>()
                          .setInviteLinkEnabled(widget.eventId, enabled);
                      if (!context.mounted) return;
                      setState(() {
                        _inviteLinkFuture = Future.value(updated);
                      });
                      events.select(widget.eventId);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to update invite link.'),
                        ),
                      );
                    } finally {
                      if (context.mounted) {
                        setState(() {
                          _updatingInviteLink = false;
                        });
                      }
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Invite by link',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (widget.isOwner)
                              Switch(
                                value: link.enabled,
                                onChanged:
                                    _updatingInviteLink ? null : onToggle,
                              ),
                          ],
                        ),
                        if (!link.enabled)
                          Text(
                            'Link is disabled.',
                            style: TextStyle(
                              color: OnesColors.black.withOpacity(0.55),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: OnesColors.purpleMid,
                                  foregroundColor: OnesColors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                onPressed: canUseLink ? onCopy : null,
                                child: const Text(
                                  'Copy link',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: OnesColors.yellowSoft,
                                  foregroundColor: OnesColors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                onPressed: canUseLink ? onShare : null,
                                child: const Text(
                                  'Share',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  );
                },
              ),
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

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: OnesColors.black.withOpacity(0.55),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: const TextStyle(
                              color: OnesColors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
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
