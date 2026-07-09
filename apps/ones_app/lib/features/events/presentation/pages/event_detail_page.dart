import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/utils/datetime_formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/widgets/ones_text_field.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../photos/presentation/pages/photo_viewer_page.dart';
import '../../../photos/adapters/api/event_photos_api.dart';
import '../../../photos/presentation/photos_gallery_controller.dart';
import '../../../photos/presentation/photos_upload_controller.dart';
import '../../../photos/presentation/photos_ws_controller.dart';
import '../../../photos/domain/event_photo.dart';
import '../../../photos/adapters/local/photo_storage.dart';
import '../event_cover_urls_controller.dart';
import '../events_controller.dart';
import '../widgets/event_detail_details_widgets.dart';
import '../widgets/event_detail_header.dart';
import '../widgets/event_detail_tabs.dart';
import 'photo_capture_page.dart';
import 'edit_event_page.dart';
import '../../../invitations/presentation/widgets/invitations_sheet.dart';
import '../../domain/event_exceptions.dart';
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
  bool _gallerySelecting = false;

  PhotosGalleryController? _galleryController;

  String? _lastLanguage;

  static const Set<String> _eventDetailRequiredKeys = {
    'event_detail.no_event',
    'event_detail.tab_gallery',
    'event_detail.tab_details',
    'event_detail.no_photos',
    'event_detail.action_refresh',
    'event_detail.error_loading_gallery',
    'event_detail.action_retry',
    'event_detail.filter_all',
    'event_detail.filter_shared',
    'event_detail.filter_mine',
    'event_detail.guests',
    'event_detail.action_clear',
    'event_detail.action_apply',
    'event_detail.photo_processing',
    'event_detail.processing',
    'event_detail.shared',
    'event_detail.guest',
    'event_detail.action_cancel',
    'event_detail.error_mix_shared_private',
    'event_detail.photos_unshared',
    'event_detail.photos_shared',
    'event_detail.error_update_failed',
    'event_detail.action_unshare',
    'event_detail.action_share',
    'event_detail.section_event_details',
    'event_detail.action_edit_tooltip',
    'event_detail.field_event_name',
    'event_detail.field_location',
    'event_detail.field_starts',
    'event_detail.field_ends',
    'event_detail.field_description',
    'event_detail.section_frames',
    'event_detail.selected_frames',
    'event_detail.section_invite_guests',
    'event_detail.invite_by_link',
    'event_detail.link_disabled',
    'event_detail.copy_link',
    'event_detail.share_link',
    'event_detail.invite_link_copied',
    'event_detail.invite_link_update_failed',
    'event_detail.email_required_hint',
    'event_detail.action_invite',
    'event_detail.guests_title',
    'event_detail.error_enter_email',
    'event_detail.error_invalid_email',
    'event_detail.error_invite_failed',
    'event_detail.error_load_guests',
    'event_detail.no_guests_yet',
    'event_detail.guest_status_owner',
    'event_detail.guest_status_accepted',
    'event_detail.guest_status_rejected',
    'event_detail.guest_status_invited',
  };

  void _purgeFlutterImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }

  @override
  void initState() {
    super.initState();
    _purgeFlutterImageCache();
    _lastLanguage = context.read<TranslationsService>().getCurrentLanguage();
    if (widget.initialPhotoId != null &&
        widget.initialPhotoId!.trim().isNotEmpty) {
      _tabIndex = 0;
    }
    final api = context.read<EventPhotosApi>();
    final auth = context.read<AuthController>();
    _galleryController = PhotosGalleryController(api: api)
      ..setIdToken(auth.idToken)
      ..prepare(eventId: widget.eventId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EventsController>().select(widget.eventId);
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'event_detail',
            requiredKeys: _eventDetailRequiredKeys,
          );
      _galleryController?.refresh(eventId: widget.eventId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.read<AuthController>().idToken;
    _galleryController?.setIdToken(token);
  }

  @override
  void didUpdateWidget(covariant EventDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId == widget.eventId) return;
    _purgeFlutterImageCache();
    final api = context.read<EventPhotosApi>();
    final auth = context.read<AuthController>();
    final next = PhotosGalleryController(api: api)
      ..setIdToken(auth.idToken)
      ..prepare(eventId: widget.eventId);
    final prev = _galleryController;

    _galleryController = next;
    _openedInitialPhoto = false;
    _gallerySelecting = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EventsController>().select(widget.eventId);
      prev?.dispose();
      next.refresh(eventId: widget.eventId);
    });
  }

  @override
  void dispose() {
    _galleryController?.dispose();
    _galleryController = null;
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    final auth = context.watch<AuthController>();
    final t = context.watch<TranslationsService>();

    final lang = t.getCurrentLanguage();
    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TranslationsService>().ensurePageTranslations(
              page: 'event_detail',
              requiredKeys: _eventDetailRequiredKeys,
            );
      });
    }
    final selected = controller.selected;
    final event = selected != null && selected.id == widget.eventId ? selected : null;
    final currentUserId = auth.user?.userId;

    final deepLinkPhotoId = widget.initialPhotoId;

    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width >= 520 ? 28.0 : 16.0;

    final galleryController = _galleryController;
    if (galleryController == null) return const SizedBox.shrink();

    return ChangeNotifierProvider<PhotosGalleryController>.value(
      value: galleryController,
      child: Consumer<PhotosGalleryController>(
        builder: (context, photos, _) {
          final eventReady =
              !controller.loading && controller.selected?.id == widget.eventId;
          final photosReady =
              photos.currentEventId == widget.eventId && photos.loadedOnce;

          return Scaffold(
            backgroundColor: OnesColors.background,
            floatingActionButton: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(
                  bottom: _gallerySelecting ? 68.0 : 0.0),
              child: FloatingActionButton(
                backgroundColor: OnesColors.purpleMid,
                foregroundColor: OnesColors.white,
                onPressed: event == null || !eventReady || !photosReady
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
            ),
            body: SafeArea(
              child: !eventReady || !photosReady
                  ? const Center(child: CircularProgressIndicator())
                  : event == null
                      ? Padding(
                          padding: EdgeInsets.all(horizontalPadding),
                          child: Text(
                            '${t.translate('event_detail.no_event', fallback: 'No event')} (error: ${controller.error})',
                          ),
                        )
                      : Column(
                          children: [
                            ColoredBox(
                              color: OnesColors.background,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        horizontalPadding,
                                        6,
                                        horizontalPadding,
                                        10),
                                    child: EventDetailHeader(
                                      title: event.title,
                                      subtitle: _eventSubtitle(
                                          event.startAt, event.location),
                                      onBack: () => Navigator.of(context).pop(),
                                      onBell: () =>
                                          showInvitationsSheet(context),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: horizontalPadding),
                                    child: EventDetailTabs(
                                      index: _tabIndex,
                                      onChanged: (i) =>
                                          setState(() => _tabIndex = i),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ClipRect(
                                child: _tabIndex == 0
                                    ? _GalleryTab(
                                        key:
                                            ValueKey('gallery:${widget.eventId}'),
                                        eventId: widget.eventId,
                                        currentUserId: currentUserId,
                                        isOwner:
                                            auth.user?.userId == event.ownerId,
                                        searchController: _searchController,
                                        initialPhotoId: deepLinkPhotoId,
                                        openedInitialPhoto: _openedInitialPhoto,
                                        onOpenedInitialPhoto: () {
                                          if (_openedInitialPhoto) return;
                                          setState(() {
                                            _openedInitialPhoto = true;
                                          });
                                        },
                                        onSelectionChanged: (selecting) {
                                          if (_gallerySelecting == selecting) return;
                                          setState(() {
                                            _gallerySelecting = selecting;
                                          });
                                        },
                                      )
                                    : Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: horizontalPadding),
                                        child: _DetailsTab(
                                          eventId: event.id,
                                          coverKey: event.coverKey,
                                          title: event.title,
                                          eventType: event.objective,
                                          startAt: event.startAt,
                                          endAt: event.endAt,
                                          location: event.location,
                                          frameIds: event.frameIds,
                                          isOwner: auth.user?.userId ==
                                              event.ownerId,
                                          allowGuestInvites:
                                              event.allowGuestInvites,
                                          inviteLinkEnabled:
                                              event.inviteLinkEnabled,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
            ),
          );
        },
      ),
    );
  }
}

String _eventSubtitle(DateTime startAt, String location) {
  final date = formatMonthDayYear(startAt.toLocal());
  final loc = location.trim().isEmpty ? '-' : location.trim();
  return '$date ÔÇó $loc';
}

class _GalleryTab extends StatefulWidget {
  final String eventId;
  final String? currentUserId;
  final bool isOwner;
  final TextEditingController searchController;
  final String? initialPhotoId;
  final bool openedInitialPhoto;
  final Function onOpenedInitialPhoto;
  final void Function(bool selecting)? onSelectionChanged;

  const _GalleryTab({
    super.key,
    required this.eventId,
    required this.currentUserId,
    required this.isOwner,
    required this.searchController,
    this.initialPhotoId,
    required this.openedInitialPhoto,
    required this.onOpenedInitialPhoto,
    this.onSelectionChanged,
  });

  @override
  State<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<_GalleryTab> {
  bool _selecting = false;
  final Set<String> _selectedIds = {};

  final Set<String> _cleanupUploadPhotoIds = {};

  final ScrollController _gridScrollController = ScrollController();

  int _autoFillLoadMoreAttempts = 0;
  String? _autoFillEventId;

  Timer? _pendingUploadsPoll;
  int _pendingUploadsPollTicks = 0;
  String? _pendingUploadsEventId;
  Set<String> _pendingUploadsPhotoIds = <String>{};

  Future<List<EventGuest>>? _guestsFuture;

  late final List<Color> _badgePalette;
  final Map<String, Color> _badgeColorByIdentity = {};
  int _nextBadgeColorIndex = 0;

  PhotosWsController? _ws;
  Timer? _wsDebounce;

  PhotoStorage? _photoStorage;
  PhotosGalleryController? _galleryController;
  PhotosUploadController? _uploader;

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

  bool _urlBelongsToEvent(String url, String eventId) {
    if (url.isEmpty) return false;
    final trimmed = eventId.trim();
    if (trimmed.isEmpty) return false;

    final parsed = Uri.tryParse(url);
    final path = parsed?.path ?? url;
    final decoded = Uri.decodeFull(path);

    return decoded.contains('/eventos/$trimmed/') ||
        decoded.contains('eventos/$trimmed/');
  }

  void _maybeLoadMore() {
    if (!mounted) return;
    if (!_gridScrollController.hasClients) return;

    final controller = context.read<PhotosGalleryController>();

    if (controller.loading || !controller.hasMore) return;

    final pos = _gridScrollController.position;
    final threshold =
        (pos.viewportDimension * 2.0).clamp(1200.0, 3500.0).toDouble();
    final nearBottom = pos.extentAfter < threshold;
    if (!nearBottom) return;

    controller.loadMore(eventId: widget.eventId);
  }

  @override
  void initState() {
    super.initState();
    _gridScrollController.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ws = context.read<PhotosWsController>();
      _ws = ws;
      ws.onPhotoReady = _onWsPhotoReady;
      ws.subscribe(eventId: widget.eventId);
      unawaited(ws.connect());
      setState(() {
        _guestsFuture =
            context.read<EventsRepository>().listEventGuestsV2(widget.eventId);
      });
    });

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
    _photoStorage ??= context.read<PhotoStorage>();
    _galleryController ??= context.read<PhotosGalleryController>();
    _uploader ??= context.read<PhotosUploadController>();
  }

  @override
  void didUpdateWidget(covariant _GalleryTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final eventChanged = oldWidget.eventId != widget.eventId;
    final userChanged = oldWidget.currentUserId != widget.currentUserId;
    if (!eventChanged && !userChanged) return;

    if (eventChanged) {
      _autoFillEventId = null;
      _autoFillLoadMoreAttempts = 0;
      if (_gridScrollController.hasClients) {
        _gridScrollController.jumpTo(0);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _selecting = false;
        _selectedIds.clear();
        if (eventChanged) {
          _cleanupUploadPhotoIds.clear();
        }
        _badgeColorByIdentity.clear();
        _nextBadgeColorIndex = 0;
        _guestsFuture =
            context.read<EventsRepository>().listEventGuestsV2(widget.eventId);
      });

      final ws = _ws ?? context.read<PhotosWsController>();
      _ws = ws;
      ws.onPhotoReady = _onWsPhotoReady;
      if (eventChanged) {
        ws.unsubscribe(eventId: oldWidget.eventId);
      }
      ws.subscribe(eventId: widget.eventId);
      unawaited(ws.connect());
    });
  }

  @override
  void dispose() {
    _wsDebounce?.cancel();
    _wsDebounce = null;

    _pendingUploadsPoll?.cancel();
    _pendingUploadsPoll = null;

    _gridScrollController.removeListener(_maybeLoadMore);
    _gridScrollController.dispose();

    final ws = _ws;
    if (ws != null) {
      ws.unsubscribe(eventId: widget.eventId);
      if (ws.onPhotoReady == _onWsPhotoReady) {
        ws.onPhotoReady = null;
      }
    }

    // Limpiar fotos locales del evento
    final storage = _photoStorage;
    if (storage != null) {
      final uploader = _uploader;
      if (uploader != null) {
        unawaited(() async {
          final active = await uploader.db
              .listActiveByEvent(eventId: widget.eventId, limit: 1);
          if (active.isEmpty) {
            await storage.deleteEventPhotos(eventId: widget.eventId);
          }
        }());
      }
    }

    // Limpiar cache de fotos remotas del evento
    _clearEventImageCache();

    super.dispose();
  }

  void _clearEventImageCache() {
    final controller = _galleryController;
    final items = controller?.items ?? const <EventPhoto>[];

    for (final photo in items) {
      final pid = photo.photoId.trim();
      if (pid.isEmpty) continue;
      DefaultCacheManager().removeFile('${widget.eventId}:$pid:s');
      DefaultCacheManager().removeFile('${widget.eventId}:$pid:m');
    }
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

  void _syncPendingUploadsPolling(Set<String> pendingPhotoIds) {
    if (pendingPhotoIds.isEmpty) {
      _pendingUploadsPoll?.cancel();
      _pendingUploadsPoll = null;
      _pendingUploadsPollTicks = 0;
      _pendingUploadsEventId = null;
      _pendingUploadsPhotoIds = <String>{};
      return;
    }

    final sameEvent = _pendingUploadsEventId == widget.eventId;
    final sameIds = setEquals(_pendingUploadsPhotoIds, pendingPhotoIds);
    if (sameEvent && sameIds && _pendingUploadsPoll != null) return;

    _pendingUploadsPoll?.cancel();
    _pendingUploadsPollTicks = 0;
    _pendingUploadsEventId = widget.eventId;
    _pendingUploadsPhotoIds = {...pendingPhotoIds};

    _pendingUploadsPoll =
        Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _pendingUploadsPollTicks++;
      if (_pendingUploadsPollTicks > 30) {
        timer.cancel();
        _pendingUploadsPoll = null;
        return;
      }

      // Sparse safety-net refresh (ticks 1=2s, 5=10s, 15=30s) in case the
      // WS photo.ready event was missed. All other ticks just setState to
      // re-evaluate doneLocal without resetting pagination.
      const sparseRefreshTicks = {1, 5, 15};
      final gallery = context.read<PhotosGalleryController>();
      if (sparseRefreshTicks.contains(_pendingUploadsPollTicks) &&
          !gallery.loading &&
          gallery.currentEventId == widget.eventId) {
        gallery.refresh(eventId: widget.eventId);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  void _exitSelectionMode() {
    if (!_selecting && _selectedIds.isEmpty) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
    widget.onSelectionChanged?.call(false);
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
    final t = context.watch<TranslationsService>();

    final isCurrentEvent = controller.currentEventId == widget.eventId;
    final remoteItems = isCurrentEvent ? controller.items : const <EventPhoto>[];

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
          final gallery = context.read<PhotosGalleryController>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<PhotosGalleryController>.value(
                value: gallery,
                child: PhotoViewerPage(
                  eventId: widget.eventId,
                  initialIndex: idx,
                  currentUserId: widget.currentUserId,
                ),
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
    final pendingUploadIds = <String>{
      for (final it in localActive)
        if (it.photoId.trim().isNotEmpty) it.photoId.trim(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPendingUploadsPolling(pendingUploadIds);
    });
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
      final hasThumb =
          remote.smallUrl != null && remote.smallUrl!.trim().isNotEmpty;
      if ((status == 'ready' || hasThumb) &&
          !_cleanupUploadPhotoIds.contains(pid)) {
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

    if (!isCurrentEvent || !controller.loadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!isCurrentEvent) return;
      if (!controller.loadedOnce) return;
      if (controller.loading) return;
      if (!controller.hasMore) return;

      if (_autoFillEventId != widget.eventId) {
        _autoFillEventId = widget.eventId;
        _autoFillLoadMoreAttempts = 0;
      }
      if (_autoFillLoadMoreAttempts >= 4) return;

      if (!_gridScrollController.hasClients) return;
      final pos = _gridScrollController.position;
      final canScroll = pos.maxScrollExtent > 0;
      if (!canScroll) {
        _autoFillLoadMoreAttempts++;
        controller.loadMore(eventId: widget.eventId);
      }
    });

    if (controller.loading && remoteItems.isEmpty && localPathById.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isCurrentEvent &&
        controller.loadedOnce &&
        !controller.loading &&
        controller.error == null &&
        remoteItems.isEmpty &&
        localPathById.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.translate(
                  'event_detail.no_photos',
                  fallback: 'A├║n no hay fotos en este evento.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => controller.refresh(eventId: widget.eventId),
                child: Text(
                  t.translate(
                    'event_detail.action_refresh',
                    fallback: 'Actualizar',
                  ),
                ),
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
                '${t.translate('event_detail.error_loading_gallery', fallback: 'Error cargando galer├¡a')}: ${controller.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => controller.refresh(eventId: widget.eventId),
                child: Text(
                  t.translate(
                    'event_detail.action_retry',
                    fallback: 'Reintentar',
                  ),
                ),
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
            ColoredBox(
              color: OnesColors.background,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<PhotosGalleryFilter>(
                        segments: <ButtonSegment<PhotosGalleryFilter>>[
                          ButtonSegment(
                            value: PhotosGalleryFilter.all,
                            label: Tooltip(
                              message: t.translate(
                                'event_detail.filter_all',
                                fallback: 'Todas',
                              ),
                              child: Semantics(
                                label: t.translate(
                                  'event_detail.filter_all',
                                  fallback: 'Todas',
                                ),
                                child: const Icon(Icons.photo_library_outlined),
                              ),
                            ),
                          ),
                          ButtonSegment(
                            value: PhotosGalleryFilter.sharedByMe,
                            label: Tooltip(
                              message: t.translate(
                                'event_detail.filter_shared',
                                fallback: 'Compartidas',
                              ),
                              child: Semantics(
                                label: t.translate(
                                  'event_detail.filter_shared',
                                  fallback: 'Compartidas',
                                ),
                                child: const Icon(Icons.ios_share_outlined),
                              ),
                            ),
                          ),
                          ButtonSegment(
                            value: PhotosGalleryFilter.mine,
                            label: Tooltip(
                              message: t.translate(
                                'event_detail.filter_mine',
                                fallback: 'M├¡as',
                              ),
                              child: Semantics(
                                label: t.translate(
                                  'event_detail.filter_mine',
                                  fallback: 'M├¡as',
                                ),
                                child: const Icon(Icons.person_outline),
                              ),
                            ),
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
                                              Text(
                                                t.translate(
                                                  'event_detail.guests_title',
                                                  fallback: 'Invitados',
                                                ),
                                                style: const TextStyle(
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
                                                    final title = (g.displayName !=
                                                                null &&
                                                            g.displayName!
                                                                .trim()
                                                                .isNotEmpty)
                                                        ? g.displayName!.trim()
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
                                                    child: Text(
                                                      t.translate(
                                                        'event_detail.action_clear',
                                                        fallback: 'Clear',
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  FilledButton(
                                                    onPressed: () {
                                                      Navigator.of(ctx)
                                                          .pop(tmp);
                                                    },
                                                    child: Text(
                                                      t.translate(
                                                        'event_detail.action_apply',
                                                        fallback: 'Apply',
                                                      ),
                                                    ),
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
                              await controller.refresh(
                                  eventId: widget.eventId);
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        minimumSize: const Size(48, 44),
                      ),
                      child: Tooltip(
                        message: t.translate(
                          'event_detail.guests',
                          fallback: 'Invitados',
                        ),
                        child: Semantics(
                          label: t.translate(
                            'event_detail.guests',
                            fallback: 'Invitados',
                          ),
                          child: const Icon(Icons.groups_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.refresh(eventId: widget.eventId),
                child: Container(
                  color: OnesColors.background,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis != Axis.vertical) {
                        return false;
                      }
                      if (notification is ScrollUpdateNotification ||
                          notification is OverscrollNotification ||
                          notification is UserScrollNotification) {
                        _maybeLoadMore();
                      }
                      return false;
                    },
                    child: GridView.builder(
                      controller: _gridScrollController,
                      primary: false,
                      clipBehavior: Clip.hardEdge,
                      key: ValueKey('grid:${widget.eventId}'),
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 1,
                        crossAxisSpacing: 1,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: mergedIds.length,
                      itemBuilder: (context, index) {
                        final photoId = mergedIds[index];
                        if (index >= mergedIds.length - 6) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            final controller =
                                context.read<PhotosGalleryController>();
                            if (controller.loading || !controller.hasMore) {
                              return;
                            }
                            if (!_gridScrollController.hasClients) return;
                            final pos = _gridScrollController.position;
                            final threshold = (pos.viewportDimension * 2.0)
                                .clamp(1200.0, 3500.0)
                                .toDouble();
                            final nearBottom = pos.extentAfter < threshold;
                            if (!nearBottom) return;
                            controller.loadMore(eventId: widget.eventId);
                          });
                        }
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
                        final rawThumbUrl = (small != null && small.isNotEmpty)
                            ? small
                            : null;
                        final rawViewerUrl =
                            (medium != null && medium.isNotEmpty)
                                ? medium
                                : null;

                        final thumbUrl = (rawThumbUrl != null &&
                                _urlBelongsToEvent(
                                    rawThumbUrl, widget.eventId))
                            ? rawThumbUrl
                            : null;
                        final viewerUrl = (rawViewerUrl != null &&
                                _urlBelongsToEvent(
                                    rawViewerUrl, widget.eventId))
                            ? rawViewerUrl
                            : null;

                        if (kDebugMode &&
                            rawThumbUrl != null &&
                            thumbUrl == null) {
                          debugPrint(
                            'gallery_url_guard: eventId=${widget.eventId} photoId=$photoId rejectedThumbUrl=$rawThumbUrl',
                          );
                        }
                        if (kDebugMode &&
                            rawViewerUrl != null &&
                            viewerUrl == null) {
                          debugPrint(
                            'gallery_url_guard: eventId=${widget.eventId} photoId=$photoId rejectedViewerUrl=$rawViewerUrl',
                          );
                        }

                        final canSelect = (!isLocalPending && item != null)
                            ? _canSelect(item.guestId)
                            : false;
                        final isSelected = _selectedIds.contains(photoId);

                        void toggleSelected() {
                          if (!canSelect) return;
                          setState(() {
                            final wasSelecting = _selecting;
                            _selecting = true;
                            if (isSelected) {
                              _selectedIds.remove(photoId);
                              if (_selectedIds.isEmpty) {
                                _selecting = false;
                              }
                            } else {
                              _selectedIds.add(photoId);
                            }
                            if (!wasSelecting && _selecting) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => widget.onSelectionChanged?.call(true));
                            } else if (wasSelecting && !_selecting) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => widget.onSelectionChanged?.call(false));
                            }
                          });
                        }

                        return InkWell(
                          key: ValueKey('${widget.eventId}:$photoId'),
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
                                SnackBar(
                                  content: Text(
                                    t.translate(
                                      'event_detail.photo_processing',
                                      fallback:
                                          'La foto a├║n se est├í procesando.',
                                    ),
                                  ),
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
                                builder: (_) =>
                                    ChangeNotifierProvider<PhotosGalleryController>.value(
                                  value:
                                      context.read<PhotosGalleryController>(),
                                  child: PhotoViewerPage(
                                    eventId: widget.eventId,
                                    initialIndex: remoteIndex,
                                    currentUserId: widget.currentUserId,
                                  ),
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
                                        ? Center(
                                            child: Text(
                                              t.translate(
                                                'event_detail.processing',
                                                fallback: 'Procesando',
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          )
                                        : Image(
                                            key: ValueKey(
                                                'thumb:${widget.eventId}:$photoId'),
                                            image: CachedNetworkImageProvider(
                                              thumbUrl,
                                              cacheKey:
                                                  '${widget.eventId}:$photoId:s',
                                            ),
                                            fit: BoxFit.cover,
                                            gaplessPlayback: false,
                                            frameBuilder:
                                                (context, child, frame, _) {
                                              if (frame != null) return child;
                                              return const SizedBox.expand(
                                                child: ColoredBox(
                                                  color: Colors.black12,
                                                ),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) {
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
                                    child: Text(
                                      t.translate(
                                        'event_detail.shared',
                                        fallback: 'Shared',
                                      ),
                                      style: const TextStyle(
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
                                          : t.translate(
                                              'event_detail.guest',
                                              fallback: 'Invitado',
                                            ),
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
              child: Builder(
                builder: (context) {
                  final selected = controller.items
                      .where((it) => _selectedIds.contains(it.photoId))
                      .toList(growable: false);
                  final anyShared = selected.any((it) => it.shared);
                  final anyNotShared = selected.any((it) => !it.shared);
                  final me = widget.currentUserId;
                  final allOwnUnshared = _selectedIds.isNotEmpty &&
                      !anyShared &&
                      me != null &&
                      selected.every((it) => it.guestId == me);

                  return Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: t.translate(
                            'event_detail.action_cancel',
                            fallback: 'Cancelar',
                          ),
                          child: OutlinedButton(
                            onPressed:
                                controller.loading ? null : _exitSelectionMode,
                            child: const Icon(Icons.close),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: anyShared && !anyNotShared
                              ? t.translate(
                                  'event_detail.action_unshare',
                                  fallback: 'Descompartir',
                                )
                              : t.translate(
                                  'event_detail.action_share',
                                  fallback: 'Compartir',
                                ),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: OnesColors.purpleMid,
                              foregroundColor: OnesColors.white,
                            ),
                            onPressed:
                                (controller.loading || _selectedIds.isEmpty)
                                    ? null
                                    : () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        final ids = _selectedIds
                                            .toList(growable: false);

                                        if (anyShared && anyNotShared) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                t.translate(
                                                  'event_detail.error_mix_shared_private',
                                                  fallback:
                                                      'No puedes mezclar fotos compartidas y privadas.',
                                                ),
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
                                              SnackBar(
                                                content: Text(
                                                  t.translate(
                                                    'event_detail.photos_unshared',
                                                    fallback:
                                                        'Fotos descompartidas.',
                                                  ),
                                                ),
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
                                              SnackBar(
                                                content: Text(
                                                  t.translate(
                                                    'event_detail.photos_shared',
                                                    fallback:
                                                        'Fotos compartidas.',
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          _exitSelectionMode();
                                        } catch (e) {
                                          if (!mounted) return;
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${t.translate('event_detail.error_update_failed', fallback: 'No se pudo actualizar')}: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                            child: anyShared && !anyNotShared
                                ? const Icon(Icons.remove_circle_outline)
                                : const Icon(Icons.ios_share_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: t.translate(
                            'event_detail.action_delete',
                            fallback: 'Eliminar',
                          ),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: OnesColors.white,
                            ),
                            onPressed: (controller.loading || !allOwnUnshared)
                                ? null
                                : () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final ids = _selectedIds
                                        .toList(growable: false);
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                          t.translate(
                                            'event_detail.delete_confirm_title',
                                            fallback: 'Eliminar fotos',
                                          ),
                                        ),
                                        content: Text(
                                          t.translate(
                                            'event_detail.delete_confirm_body',
                                            fallback:
                                                '┬┐Eliminar ${ids.length} foto(s)? Esta acci├│n no se puede deshacer.',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: Text(
                                              t.translate(
                                                'event_detail.action_cancel',
                                                fallback: 'Cancelar',
                                              ),
                                            ),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  Colors.red.shade700,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: Text(
                                              t.translate(
                                                'event_detail.action_delete',
                                                fallback: 'Eliminar',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    try {
                                      await context
                                          .read<PhotosGalleryController>()
                                          .deletePhotos(
                                            eventId: widget.eventId,
                                            photoIds: ids,
                                          );
                                      if (!mounted) return;
                                      _exitSelectionMode();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            t.translate(
                                              'event_detail.photos_deleted',
                                              fallback: 'Fotos eliminadas.',
                                            ),
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${t.translate('event_detail.error_update_failed', fallback: 'No se pudo eliminar')}: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
          context.read<EventsRepository>().listEventGuestsV2(widget.eventId);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addInvitee() async {
    final t = context.read<TranslationsService>();
    final email = _emailController.text.trim();

    final normalizedEmail = email.toLowerCase();

    if (email.isEmpty) {
      setState(() {
        _inviteError = t.translate(
          'event_detail.error_enter_email',
          fallback: 'Please enter an email.',
        );
      });
      return;
    }

    if (!looksLikeEmail(normalizedEmail)) {
      setState(() {
        _inviteError = t.translate(
          'event_detail.error_invalid_email',
          fallback: 'Please enter a valid email.',
        );
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
        _inviteError = t.translate(
          'event_detail.error_invite_failed',
          fallback: 'Failed to invite guest.',
        );
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
    final t = context.watch<TranslationsService>();

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
          title: t.translate(
            'event_detail.section_event_details',
            fallback: 'Event Details',
          ),
          trailing: widget.isOwner
              ? IconButton(
                  tooltip: t.translate(
                    'event_detail.action_edit_tooltip',
                    fallback: 'Editar',
                  ),
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
                    label: t.translate(
                      'event_detail.field_event_name',
                      fallback: 'Event Name',
                    ),
                    value: widget.title,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReadOnlyField(
                    label: t.translate(
                      'event_detail.field_location',
                      fallback: 'Location',
                    ),
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
                    label: t.translate(
                      'event_detail.field_starts',
                      fallback: 'Starts',
                    ),
                    value:
                        '${formatMonthDayYear(start)} ÔÇó ${formatTimeOfDay(start)}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReadOnlyField(
                    label: t.translate(
                      'event_detail.field_ends',
                      fallback: 'Ends',
                    ),
                    value:
                        '${formatMonthDayYear(end)} ÔÇó ${formatTimeOfDay(end)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReadOnlyField(
              label: t.translate(
                'event_detail.field_description',
                fallback: 'Description',
              ),
              value: description,
              maxLines: null,
              overflow: null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        EventDetailSectionCard(
          title: t.translate(
            'event_detail.section_frames',
            fallback: 'Frames',
          ),
          children: [
            FutureBuilder<Map<String, String>>(
              future: _frameNamesFuture,
              builder: (context, snapshot) {
                if (widget.frameIds.isEmpty) {
                  return ReadOnlyField(
                    label: t.translate(
                      'event_detail.selected_frames',
                      fallback: 'Selected frames',
                    ),
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
                      t.translate(
                        'event_detail.selected_frames',
                        fallback: 'Selected frames',
                      ),
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
                              'ÔÇó ',
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
          title: t.translate(
            'event_detail.section_invite_guests',
            fallback: 'Invite Guests',
          ),
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
                      SnackBar(
                        content: Text(
                          t.translate(
                            'event_detail.invite_link_copied',
                            fallback: 'Invite link copied.',
                          ),
                        ),
                      ),
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
                        SnackBar(
                          content: Text(
                            t.translate(
                              'event_detail.invite_link_update_failed',
                              fallback: 'Failed to update invite link.',
                            ),
                          ),
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
                            Expanded(
                              child: Text(
                                t.translate(
                                  'event_detail.invite_by_link',
                                  fallback: 'Invite by link',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
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
                            t.translate(
                              'event_detail.link_disabled',
                              fallback: 'Link is disabled.',
                            ),
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
                                child: Text(
                                  t.translate(
                                    'event_detail.copy_link',
                                    fallback: 'Copy link',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
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
                                child: Text(
                                  t.translate(
                                    'event_detail.share_link',
                                    fallback: 'Share',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
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
                hintText: t.translate(
                  'event_detail.email_required_hint',
                  fallback: 'Email (required)',
                ),
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
                  child: Text(
                    t.translate(
                      'event_detail.action_invite',
                      fallback: 'Invite',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.groups_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  t.translate(
                    'event_detail.guests',
                    fallback: 'Guests',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
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
                    t.translate(
                      'event_detail.error_load_guests',
                      fallback: 'Failed to load guests.',
                    ),
                    style: TextStyle(color: OnesColors.black.withOpacity(0.55)),
                  );
                }

                if (guests == null || guests.isEmpty) {
                  return Text(
                    t.translate(
                      'event_detail.no_guests_yet',
                      fallback: 'No guests yet.',
                    ),
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
                        ? t.translate(
                            'event_detail.guest_status_owner',
                            fallback: 'Owner',
                          )
                        : switch (g.status) {
                            'accepted' => t.translate(
                                'event_detail.guest_status_accepted',
                                fallback: 'Accepted',
                              ),
                            'rejected' => t.translate(
                                'event_detail.guest_status_rejected',
                                fallback: 'Rejected',
                              ),
                            'invited' => t.translate(
                                'event_detail.guest_status_invited',
                                fallback: 'Invited',
                              ),
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
        if (widget.isOwner) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: OnesColors.danger,
                  side: const BorderSide(color: OnesColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(
                  t.translate(
                    'event_detail.action_delete_event',
                    fallback: 'Eliminar evento',
                  ),
                ),
                onPressed: () => _confirmDeleteEvent(context),
              ),
            ),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> _confirmDeleteEvent(BuildContext context) async {
    final t = context.read<TranslationsService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          t.translate(
            'event_detail.delete_event_title',
            fallback: 'Eliminar evento',
          ),
        ),
        content: Text(
          t.translate(
            'event_detail.delete_event_body',
            fallback:
                'Se eliminar├ín todas las fotos, invitaciones y datos del evento. Esta acci├│n no se puede deshacer.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              t.translate('event_detail.action_cancel', fallback: 'Cancelar'),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: OnesColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t.translate(
                'event_detail.action_delete_event',
                fallback: 'Eliminar',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await context.read<EventsController>().deleteEvent(widget.eventId);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } on EventHasGuestPhotosException {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.translate(
              'event_detail.delete_event_error_guest_photos',
              fallback:
                  'No puedes eliminar el evento porque hay fotos de otros invitados.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.translate(
              'event_detail.delete_event_error_generic',
              fallback: 'Error al eliminar el evento. Intenta de nuevo.',
            ),
          ),
        ),
      );
    }
  }
}
