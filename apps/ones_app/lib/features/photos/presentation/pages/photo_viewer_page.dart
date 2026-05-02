import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex < 0 ? 0 : widget.initialIndex;
    _currentIndex = initial;
    _pageController = PageController(initialPage: initial);
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      precacheImage(NetworkImage(url), context);
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
        return 'Compartida por $n';
      }
      return null;
    }

    final owner = item.ownerName;
    if (owner != null && owner.trim().isNotEmpty) {
      return owner;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<PhotosGalleryController>();
    final items = gallery.items;

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
                          return const Center(
                            child: Text(
                              'La foto aún se está procesando.',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return InteractiveViewer(
                          child: Center(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stack) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Error cargando imagen: $error',
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
                bottom: 78,
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
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.black.withOpacity(0.55),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                          'No se pudo actualizar el like: $e'),
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
                        likedByMe ? Icons.favorite : Icons.favorite_border,
                        color: likedByMe ? Colors.red : Colors.white,
                      ),
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
