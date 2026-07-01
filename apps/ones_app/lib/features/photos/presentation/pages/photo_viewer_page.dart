import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/i18n/translations_service.dart';
import '../photos_gallery_controller.dart';
import '../../domain/event_photo.dart';

class PhotoViewerPage extends StatefulWidget {
  final String eventId;
  final int initialIndex;
  final String? currentUserId;

  const PhotoViewerPage({
    super.key,
    required this.eventId,
    required this.initialIndex,
    this.currentUserId,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _likeBusy = false;
  bool _shareBusy = false;

  CacheManager? _mediaCache;

  String? _lastLanguage;

  static const Set<String> _photoViewerRequiredKeys = {
    'photo_viewer.shared_by',
    'photo_viewer.photo_processing',
    'photo_viewer.error_loading_image',
    'photo_viewer.error_like_update_failed',
    'photo_viewer.error_share_failed',
  };

  @override
  void initState() {
    super.initState();
    _lastLanguage = context.read<TranslationsService>().getCurrentLanguage();
    _mediaCache = CacheManager(
      Config(
        'ones_viewer_media_${widget.eventId}',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
      ),
    );
    final initial = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    _currentIndex = initial;
    _pageController = PageController(initialPage: initial);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'photo_viewer',
            requiredKeys: _photoViewerRequiredKeys,
          );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mediaCache?.dispose();
    super.dispose();
  }

  void _maybePrecacheAround(
    BuildContext context,
    List<EventPhoto> items,
    int index,
  ) {
    for (final i in <int>[index - 1, index, index + 1]) {
      if (i < 0 || i >= items.length) continue;
      final it = items[i];
      final url = it.mediumUrl;
      if (url == null || url.trim().isEmpty) continue;
      precacheImage(
        CachedNetworkImageProvider(
          url,
          cacheKey: '${widget.eventId}:${it.photoId}:m',
          cacheManager: _mediaCache,
        ),
        context,
      );
    }
  }

  String? _labelFor(EventPhoto item) {
    final shared = item.shared;
    if (!shared) return null;
    final me = widget.currentUserId;
    final sharedByUserId = item.sharedByUserId;

    final isSharedByMe = me != null &&
        me.isNotEmpty &&
        sharedByUserId != null &&
        sharedByUserId.isNotEmpty &&
        sharedByUserId == me;

    if (isSharedByMe) {
      final n = item.sharedByName;
      if (n != null && n.trim().isNotEmpty) {
        final t = context.read<TranslationsService>();
        final template = t.translate(
          'photo_viewer.shared_by',
          fallback: 'Compartida por {name}',
        );
        return template.replaceAll('{name}', n);
      }
      return null;
    }

    final owner = item.ownerName;
    if (owner != null && owner.trim().isNotEmpty) {
      return owner;
    }
    return null;
  }

  Future<XFile?> _downloadToTempXFile(String url,
      {required String name}) async {
    final http = HttpClient();
    final req = await http.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final bytes =
        await res.fold<List<int>>(<int>[], (prev, el) => prev..addAll(el));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }

  Future<void> _shareCurrentPhoto(BuildContext context,
      PhotosGalleryController gallery, EventPhoto currentItem) async {
    final t = context.read<TranslationsService>();
    final url = currentItem.originalUrl ??
        currentItem.mediumUrl ??
        currentItem.smallUrl;
    if (url == null || url.trim().isEmpty) {
      throw Exception(
        t.translate(
          'photo_viewer.photo_processing',
          fallback: 'La foto aún se está procesando',
        ),
      );
    }

    final link = await gallery.api.createSocialShareLink(
      eventId: widget.eventId,
      photoId: currentItem.photoId,
      variant: 'medium',
    );

    final safePhotoId =
        currentItem.photoId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'ones_$safePhotoId.jpg';
    final xf = await _downloadToTempXFile(url.trim(), name: fileName);
    if (xf == null) return;
    await Share.shareXFiles(
      [xf],
      text: link.shortUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<PhotosGalleryController>();
    final items = gallery.items;
    final t = context.watch<TranslationsService>();

    final lang = t.getCurrentLanguage();
    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TranslationsService>().ensurePageTranslations(
              page: 'photo_viewer',
              requiredKeys: _photoViewerRequiredKeys,
            );
      });
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const floatingBarHeight = 52.0;
    final floatingBarBottom = 12.0 + bottomInset;

    final maxIndex = items.isEmpty ? 0 : (items.length - 1);
    final clampedIndex = _currentIndex.clamp(0, maxIndex);
    if (clampedIndex != _currentIndex) {
      _currentIndex = clampedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }

    final currentItem = items.isEmpty ? null : items[_currentIndex];
    final label = currentItem == null ? null : _labelFor(currentItem);
    final likedByMe = currentItem?.likedByMe ?? false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybePrecacheAround(context, items, _currentIndex);
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: items.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        if (index >= items.length - 4) {
                          gallery.loadMore(eventId: widget.eventId);
                        }
                        _maybePrecacheAround(context, items, index);
                      },
                      itemBuilder: (context, index) {
                        final it = items[index];
                        final url = it.mediumUrl;
                        if (url == null || url.trim().isEmpty) {
                          return Center(
                            child: Text(
                              t.translate(
                                'photo_viewer.photo_processing',
                                fallback: 'La foto aún se está procesando.',
                              ),
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return InteractiveViewer(
                          child: Center(
                            child: Image(
                              image: CachedNetworkImageProvider(
                                url.trim(),
                                cacheKey: '${widget.eventId}:${it.photoId}:m',
                                cacheManager: _mediaCache,
                              ),
                              fit: BoxFit.contain,
                              gaplessPlayback: false,
                              frameBuilder: (context, child, frame, _) {
                                if (frame != null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stack) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      '${t.translate('photo_viewer.error_loading_image', fallback: 'Error cargando imagen')}: $error',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (label != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: floatingBarBottom + floatingBarHeight + 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: Colors.black.withOpacity(0.55),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: currentItem == null,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: floatingBarBottom),
                    child: Material(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: floatingBarHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: (currentItem == null || _likeBusy)
                                    ? null
                                    : () async {
                                        setState(() {
                                          _likeBusy = true;
                                        });
                                        final next = !likedByMe;
                                        try {
                                          await gallery.setLike(
                                            eventId: widget.eventId,
                                            photoId: currentItem.photoId,
                                            liked: next,
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                            ..clearSnackBars()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '${t.translate('photo_viewer.error_like_update_failed', fallback: 'No se pudo actualizar el like')}: $e'),
                                              ),
                                            );
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _likeBusy = false;
                                            });
                                          }
                                        }
                                      },
                                icon: Icon(
                                  likedByMe
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: likedByMe ? Colors.red : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: (currentItem == null || _shareBusy)
                                    ? null
                                    : () async {
                                        setState(() {
                                          _shareBusy = true;
                                        });
                                        try {
                                          await _shareCurrentPhoto(
                                              context, gallery, currentItem);
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                            ..clearSnackBars()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '${t.translate('photo_viewer.error_share_failed', fallback: 'No se pudo compartir la foto')}: $e'),
                                              ),
                                            );
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _shareBusy = false;
                                            });
                                          }
                                        }
                                      },
                                icon: const Icon(
                                  Icons.share_outlined,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
