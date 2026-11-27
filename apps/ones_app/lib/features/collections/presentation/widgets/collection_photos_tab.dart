import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../photos/adapters/api/event_photos_api.dart';
import '../../../photos/domain/event_photo.dart';
import '../../../photos/presentation/pages/photo_import_mobile_sheet.dart';
import '../../../photos/presentation/pages/photo_import_web_sheet.dart';
import '../../../photos/presentation/pages/photo_viewer_page.dart';
import '../../../photos/presentation/photos_gallery_controller.dart';
import '../../../photos/presentation/photos_upload_controller.dart';
import '../../../photos/presentation/photo_upload_status_badge.dart';
import '../../../photos/presentation/photos_ws_controller.dart';
import '../../../photos/domain/photo_upload_item.dart';
import '../../../events/presentation/pages/photo_capture_page.dart';
import '../../../events/presentation/pages/photo_capture_web_page.dart';
import 'collection_gallery_filters.dart';
import '../../domain/collection.dart';

class CollectionPhotosTab extends StatefulWidget {
  final OnesCollection collection;

  const CollectionPhotosTab({super.key, required this.collection});

  @override
  State<CollectionPhotosTab> createState() => _CollectionPhotosTabState();
}

class _CollectionPhotosTabState extends State<CollectionPhotosTab> {
  late final String _ownerRef;
  late final PhotosGalleryController _gallery;
  late final PhotosUploadController _uploader;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selected = <String>{};
  PhotosWsController? _ws;
  Timer? _processingRecheckTimer;

  @override
  void initState() {
    super.initState();
    _ownerRef = 'COLLECTION#${widget.collection.id}';
    _uploader = context.read<PhotosUploadController>();
    _gallery = PhotosGalleryController(api: context.read<EventPhotosApi>())
      ..setIdToken(context.read<AuthController>().idToken)
      ..prepare(eventId: _ownerRef);
    _scrollController.addListener(_loadMoreWhenNearEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ws = context.read<PhotosWsController>();
      _ws = ws;
      ws.onPhotoReady = (ownerRef, _) {
        if (mounted && ownerRef == _ownerRef) {
          unawaited(_gallery.refresh(eventId: _ownerRef));
        }
      };
      ws.subscribe(eventId: _ownerRef);
      unawaited(ws.connect());
      unawaited(_gallery.refresh(eventId: _ownerRef));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gallery.setIdToken(context.read<AuthController>().idToken);
  }

  @override
  void dispose() {
    _processingRecheckTimer?.cancel();
    _processingRecheckTimer = null;
    _ws?.unsubscribe(eventId: _ownerRef);
    _ws?.onPhotoReady = null;
    _scrollController
      ..removeListener(_loadMoreWhenNearEnd)
      ..dispose();
    _gallery.dispose();
    super.dispose();
  }

  void _loadMoreWhenNearEnd() {
    if (!_scrollController.hasClients ||
        _gallery.loading ||
        !_gallery.hasMore ||
        _scrollController.position.extentAfter > 900) {
      return;
    }
    unawaited(_gallery.loadMore(eventId: _ownerRef));
  }

  Future<void> _refresh() => _gallery.refresh(eventId: _ownerRef);

  Future<void> _importPhotos() async {
    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: kIsWeb
            ? PhotoImportWebSheet(eventId: _ownerRef)
            : PhotoImportMobileSheet(eventId: _ownerRef),
      ),
    );
    if (!mounted || uploaded != true) return;
    await context
        .read<PhotosUploadController>()
        .refreshActiveForEvent(eventId: _ownerRef);
    await _refresh();
  }

  Future<void> _takePhoto() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => kIsWeb
            ? PhotoCaptureWebPage(eventId: _ownerRef, frameIds: const [])
            : PhotoCapturePage(eventId: _ownerRef, frameIds: const []),
      ),
    );
    if (!mounted) return;
    await context
        .read<PhotosUploadController>()
        .refreshActiveForEvent(eventId: _ownerRef);
    await _refresh();
  }

  Future<void> _toggleShare() async {
    final ids = _selected.toList(growable: false);
    if (ids.isEmpty) return;
    final selectedPhotos =
        _gallery.items.where((photo) => ids.contains(photo.photoId));
    final sharedCount = selectedPhotos.where((photo) => photo.shared).length;
    if (sharedCount > 0 && sharedCount < ids.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona solo fotos compartidas o solo privadas.'),
        ),
      );
      return;
    }
    final shouldUnshare = selectedPhotos.any((photo) => photo.shared);
    try {
      if (shouldUnshare) {
        await _gallery.unsharePhotos(eventId: _ownerRef, photoIds: ids);
      } else {
        await _gallery.sharePhotos(eventId: _ownerRef, photoIds: ids);
      }
      if (mounted) setState(_selected.clear);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar fotos'),
        content: Text('Se eliminarán ${ids.length} fotos de esta colección.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _gallery.deletePhotos(eventId: _ownerRef, photoIds: ids);
      if (mounted) setState(_selected.clear);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  void _openPhoto(int index) {
    final currentUserId = context.read<AuthController>().user?.userId;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<PhotosGalleryController>.value(
          value: _gallery,
          child: PhotoViewerPage(
            eventId: _ownerRef,
            initialIndex: index,
            currentUserId: currentUserId,
          ),
        ),
      ),
    );
  }

  void _scheduleProcessingRecheck(List<EventPhoto> photos) {
    final hasProcessing = photos.any((photo) {
      final status = photo.status.trim().toLowerCase();
      final hasThumbnail =
          photo.smallUrl != null && photo.smallUrl!.trim().isNotEmpty;
      return !hasThumbnail &&
          const {'uploaded', 'processing', 'retrying'}.contains(status);
    });
    if (hasProcessing && _processingRecheckTimer == null) {
      _processingRecheckTimer = Timer(const Duration(seconds: 8), () {
        _processingRecheckTimer = null;
        if (!mounted || _gallery.loading) return;
        unawaited(_gallery.refresh(eventId: _ownerRef));
      });
    } else if (!hasProcessing) {
      _processingRecheckTimer?.cancel();
      _processingRecheckTimer = null;
    }
  }

  Widget _selectionActions(String? userId, TranslationsService t) {
    final selectedPhotos =
        _gallery.items.where((photo) => _selected.contains(photo.photoId));
    final canShare = widget.collection.type != CollectionType.private &&
        selectedPhotos.isNotEmpty &&
        selectedPhotos.every((photo) => photo.guestId == userId);
    final hasShared = selectedPhotos.any((photo) => photo.shared);

    return Material(
      color: OnesColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text('${_selected.length} seleccionadas'),
            const Spacer(),
            if (canShare)
              IconButton(
                tooltip: hasShared
                    ? 'Dejar de compartir'
                    : 'Compartir con la colección',
                onPressed: _toggleShare,
                icon: Icon(
                  hasShared ? Icons.people : Icons.people_alt_outlined,
                ),
              ),
            IconButton(
              tooltip: t.translate('common.delete', fallback: 'Eliminar'),
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip:
                  t.translate('common.cancel', fallback: 'Cancelar selección'),
              onPressed: () => setState(_selected.clear),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoTile(
    EventPhoto photo,
    int index,
    String? userId,
    PhotoUploadItem? upload,
    TranslationsService t,
  ) {
    final selected = _selected.contains(photo.photoId);
    final isMine = photo.guestId == userId;
    final isCollectionOwner = widget.collection.ownerId == userId;
    final imageUrl = photo.smallUrl ?? photo.mediumUrl ?? photo.originalUrl;
    return GestureDetector(
      onLongPress: isMine || isCollectionOwner
          ? () => setState(() {
                if (selected) {
                  _selected.remove(photo.photoId);
                } else {
                  _selected.add(photo.photoId);
                }
              })
          : null,
      onTap: _selected.isNotEmpty
          ? (isMine || isCollectionOwner
              ? () => setState(() {
                    selected
                        ? _selected.remove(photo.photoId)
                        : _selected.add(photo.photoId);
                  })
              : null)
          : () => _openPhoto(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: OnesColors.surfaceWarm,
            child: imageUrl == null
                ? const Center(
                    child: Icon(Icons.hourglass_top, color: OnesColors.inkSoft),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(
                      color: OnesColors.surfaceWarm,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
          if (photo.shared)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: OnesColors.yellow.withOpacity(0.72),
                child: Text(
                  photo.sharedByUserId == userId
                      ? t.translate('event_detail.shared',
                          fallback: 'Compartida')
                      : (photo.ownerName?.trim().isNotEmpty == true
                          ? photo.ownerName!.trim()
                          : t.translate('event_detail.guest',
                              fallback: 'Invitado')),
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
          if (photo.status.toLowerCase() == 'failed' &&
              photo.processingRetryable &&
              isMine)
            Positioned(
              bottom: 6,
              right: 6,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Reintentar procesamiento',
                  onPressed: () => _gallery.retryProcessing(
                      eventId: _ownerRef, photo: photo),
                  icon:
                      const Icon(Icons.refresh, color: Colors.white, size: 18),
                ),
              ),
            ),
          if (upload != null ||
              const {'uploaded', 'processing', 'retrying', 'uploading'}
                  .contains(photo.status.trim().toLowerCase()))
            Positioned(
              left: 6,
              bottom: 6,
              child: PhotoUploadStatusBadge(
                status: upload?.status ?? photo.status,
                progress: _uploader.uploadProgressByPhotoId(photo.photoId),
                onRetry: upload?.status == 'failed'
                    ? () => _uploader.retryFailedByPhotoId(
                          eventId: _ownerRef,
                          photoId: photo.photoId,
                        )
                    : null,
              ),
            ),
          if (_selected.isNotEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? OnesColors.purpleMid : Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return AnimatedBuilder(
      animation: Listenable.merge([_gallery, _uploader]),
      builder: (context, _) {
        final photos = _gallery.items;
        final userId = context.read<AuthController>().user?.userId;
        final translations = context.watch<TranslationsService>();
        final pendingUploads = _uploader.activeByEvent(_ownerRef);
        final localById = <String, PhotoUploadItem>{
          for (final upload in pendingUploads) upload.photoId: upload,
        };
        final remoteIds = photos.map((photo) => photo.photoId).toSet();
        final localOnlyUploads = pendingUploads
            .where((upload) => !remoteIds.contains(upload.photoId))
            .toList(growable: false);
        _scheduleProcessingRecheck(photos);
        if (!_gallery.loading &&
            photos.isNotEmpty &&
            pendingUploads.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_uploader.reconcileReadyPhotos(
              eventId: _ownerRef,
              photos: photos,
            ));
          });
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_selected.isNotEmpty)
                SliverToBoxAdapter(
                    child: _selectionActions(userId, translations))
              else
                SliverToBoxAdapter(
                  child: CollectionGalleryFilters(
                    privateCollection:
                        widget.collection.type == CollectionType.private,
                    selected: _gallery.filter,
                    allLabel: translations.translate(
                      'event_detail.filter_all',
                      fallback: 'Todas',
                    ),
                    sharedLabel: translations.translate(
                      'event_detail.filter_shared',
                      fallback: 'Compartidas',
                    ),
                    mineLabel: translations.translate(
                      'event_detail.filter_mine',
                      fallback: 'Mías',
                    ),
                    onSelected: (filter) {
                      if (filter == _gallery.filter) return;
                      _gallery.setFilter(filter);
                      unawaited(_gallery.refresh(eventId: _ownerRef));
                    },
                  ),
                ),
              if (localOnlyUploads.isNotEmpty)
                SliverToBoxAdapter(
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fotos pendientes',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          for (var i = 0; i < localOnlyUploads.length; i++)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Foto ${i + 1}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                PhotoUploadStatusBadge(
                                  status: localOnlyUploads[i].status,
                                  progress: _uploader.uploadProgressByPhotoId(
                                    localOnlyUploads[i].photoId,
                                  ),
                                  onRetry: localOnlyUploads[i].status ==
                                          'failed'
                                      ? () => _uploader.retryFailedByPhotoId(
                                            eventId: _ownerRef,
                                            photoId:
                                                localOnlyUploads[i].photoId,
                                          )
                                      : null,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_gallery.error != null && photos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 44),
                        const SizedBox(height: 8),
                        const Text('No se pudo cargar la galería.'),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (photos.isEmpty && _gallery.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (photos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_library_outlined,
                            size: 60,
                            color: OnesColors.purpleMid,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Aún no hay fotos',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Agrega recuerdos o comparte una foto con las personas de esta colección.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _importPhotos,
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Agregar fotos'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(2),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _photoTile(
                        photos[index],
                        index,
                        userId,
                        localById[photos[index].photoId],
                        translations,
                      ),
                      childCount: photos.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                      childAspectRatio: .8,
                    ),
                  ),
                ),
              if (_gallery.loading && photos.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PhotosGalleryController>.value(
      value: _gallery,
      child: Scaffold(
        backgroundColor: OnesColors.surfaceWarm,
        body: _buildBody(),
        floatingActionButton: _selected.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'collection-photo-import-${widget.collection.id}',
                    onPressed: _importPhotos,
                    tooltip: 'Agregar fotos',
                    child: const Icon(Icons.file_upload_outlined),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'collection-photo-camera-${widget.collection.id}',
                    onPressed: _takePhoto,
                    tooltip: 'Tomar foto',
                    child: const Icon(Icons.photo_camera),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
