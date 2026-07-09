import 'dart:async';

import 'package:flutter/foundation.dart';

import '../adapters/api/event_photos_api.dart';
import '../domain/event_photo.dart';

enum PhotosGalleryFilter {
  all,
  mine,
  sharedByMe,
}

class PhotosGalleryController extends ChangeNotifier {
  final EventPhotosApi api;

  String? _idToken;
  bool _loading = false;
  bool _loadedOnce = false;
  Object? _error;
  List<EventPhoto> _items = const [];

  int _requestEpoch = 0;

  PhotosGalleryFilter _filter = PhotosGalleryFilter.all;
  Set<String> _guestIds = <String>{};
  String? _nextToken;
  bool _hasMore = true;

  String? _currentEventId;

  String? _pendingRefreshEventId;

  PhotosGalleryController({required this.api});

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

  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  Object? get error => _error;
  String? get currentEventId => _currentEventId;

  List<EventPhoto> get items => _items;

  PhotosGalleryFilter get filter => _filter;
  Set<String> get guestIds => _guestIds;
  bool get hasMore => _hasMore;

  void setIdToken(String? token) {
    if (_idToken == token) {
      api.setIdToken(token);
      return;
    }

    _idToken = token;
    api.setIdToken(token);

    final hasToken = token != null && token.isNotEmpty;
    if (!hasToken) {
      _loading = false;
      _loadedOnce = false;
      _error = null;
      _items = const [];
      _nextToken = null;
      _hasMore = true;
      _currentEventId = null;
      _pendingRefreshEventId = null;
      _requestEpoch++;
      notifyListeners();
      return;
    }

    // Token became available: if we were waiting to refresh for an event,
    // trigger it automatically.
    final pending = _pendingRefreshEventId;
    final current = _currentEventId;
    if (pending != null && pending.isNotEmpty && pending == current) {
      _pendingRefreshEventId = null;
      notifyListeners();
      unawaited(refresh(eventId: pending));
      return;
    }

    notifyListeners();
  }

  void prepare({required String eventId}) {
    final trimmedEventId = eventId.trim();
    if (trimmedEventId.isEmpty) return;

    _currentEventId = trimmedEventId;
    _nextToken = null;
    _hasMore = true;
    _error = null;
    _items = const [];

    _loadedOnce = false;
    _requestEpoch++;
    _loading = true;
    notifyListeners();
  }

  Future<void> setLike({
    required String eventId,
    required String photoId,
    required bool liked,
  }) async {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      _error = StateError('Missing idToken');
      notifyListeners();
      return;
    }

    final idx = _items.indexWhere((p) => p.photoId == photoId);
    if (idx < 0) return;

    final before = _items[idx];
    if (before.likedByMe == liked) return;

    final updated = EventPhoto(
      photoId: before.photoId,
      guestId: before.guestId,
      createdAt: before.createdAt,
      uploadedAt: before.uploadedAt,
      status: before.status,
      originalUrl: before.originalUrl,
      mediumUrl: before.mediumUrl,
      smallUrl: before.smallUrl,
      shared: before.shared,
      ownerName: before.ownerName,
      sharedByUserId: before.sharedByUserId,
      sharedByName: before.sharedByName,
      likedByMe: liked,
    );

    final list = [..._items];
    list[idx] = updated;
    _items = list;
    notifyListeners();

    try {
      _error = null;
      if (liked) {
        await api.like(eventId: eventId, photoId: photoId);
      } else {
        await api.unlike(eventId: eventId, photoId: photoId);
      }
    } catch (e) {
      _error = e;
      final reverted = [..._items];
      final ridx = reverted.indexWhere((p) => p.photoId == photoId);
      if (ridx >= 0) {
        reverted[ridx] = before;
        _items = reverted;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unsharePhotos({
    required String eventId,
    required List<String> photoIds,
  }) async {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      _error = StateError('Missing idToken');
      notifyListeners();
      return;
    }
    if (photoIds.isEmpty) return;

    _setLoading(true);
    try {
      _error = null;
      await api.unsharePhotos(eventId: eventId, photoIds: photoIds);
      await refresh(eventId: eventId);
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sharePhotos({
    required String eventId,
    required List<String> photoIds,
  }) async {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      _error = StateError('Missing idToken');
      notifyListeners();
      return;
    }
    if (photoIds.isEmpty) return;

    _setLoading(true);
    try {
      _error = null;
      await api.sharePhotos(eventId: eventId, photoIds: photoIds);
      await refresh(eventId: eventId);
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deletePhotos({
    required String eventId,
    required List<String> photoIds,
  }) async {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      _error = StateError('Missing idToken');
      notifyListeners();
      return;
    }
    if (photoIds.isEmpty) return;

    _setLoading(true);
    try {
      _error = null;
      await api.deletePhotos(eventId: eventId, photoIds: photoIds);
      final deletedSet = photoIds.toSet();
      _items = _items
          .where((it) => !deletedSet.contains(it.photoId))
          .toList(growable: false);
      notifyListeners();
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void setFilter(PhotosGalleryFilter value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  void setGuestIds(Set<String> value) {
    if (setEquals(_guestIds, value)) return;
    _guestIds = {...value};
    notifyListeners();
  }

  Future<void> refresh({required String eventId}) async {
    final trimmedEventId = eventId.trim();
    if (trimmedEventId.isEmpty) return;

    final eventChanged = _currentEventId != trimmedEventId;
    _currentEventId = trimmedEventId;
    _error = null;

    // Only wipe items when switching events; for same-event refresh keep
    // existing items visible until the new page arrives (no flicker).
    if (eventChanged) {
      _items = const [];
      _loadedOnce = false;
      _nextToken = null;
      _hasMore = true;
    }

    final epoch = ++_requestEpoch;
    _loading = true;
    notifyListeners();

    final token = _idToken;
    if (token == null || token.isEmpty) {
      if (epoch == _requestEpoch) {
        _error = StateError('Missing idToken');
        _items = const [];
        _nextToken = null;
        _hasMore = false;
        _loading = true;
        _loadedOnce = false;
        _pendingRefreshEventId = trimmedEventId;
        notifyListeners();
      }
      return;
    }

    try {
      final allowRetry =
          _filter == PhotosGalleryFilter.all && _guestIds.isEmpty;

      ListPhotosPage? res;
      final attempts = allowRetry ? 2 : 1;

      for (var attempt = 0; attempt < attempts; attempt++) {
        res = await api.list(
          eventId: trimmedEventId,
          limit: 24,
          filter: switch (_filter) {
            PhotosGalleryFilter.all => 'all',
            PhotosGalleryFilter.mine => 'mine',
            PhotosGalleryFilter.sharedByMe => 'shared_by_me',
          },
          guestIds: _filter == PhotosGalleryFilter.all && _guestIds.isNotEmpty
              ? _guestIds.toList(growable: false)
              : null,
        );

        if (epoch != _requestEpoch || _currentEventId != trimmedEventId) {
          return;
        }

        if (kDebugMode) {
          debugPrint(
            'gallery_list: eventId=$trimmedEventId attempt=${attempt + 1}/$attempts filter=$_filter guestIds=${_guestIds.length} items=${res.items.length} nextToken=${res.nextToken ?? '-'}',
          );
        }

        if (res.items.isNotEmpty || attempt == attempts - 1) {
          break;
        }

        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (epoch != _requestEpoch || _currentEventId != trimmedEventId) {
          return;
        }
      }

      final nonNullRes = res;
      if (nonNullRes == null) {
        throw StateError('Missing list response');
      }

      if (epoch != _requestEpoch || _currentEventId != trimmedEventId) {
        return;
      }

      final incoming = <String, EventPhoto>{
        for (final it in nonNullRes.items)
          if (_sanitizePhoto(it, trimmedEventId) case final sanitized?)
            sanitized.photoId: sanitized,
      };

      if (kDebugMode && nonNullRes.items.isNotEmpty) {
        final dropped = nonNullRes.items.length - incoming.length;
        if (dropped > 0) {
          debugPrint(
            'gallery_list: eventId=$trimmedEventId dropped=$dropped kept=${incoming.length}',
          );
        }
      }

      // Merge: incoming page-1 takes precedence; keep existing items not in
      // page-1 (they are from deeper pages already loaded).
      final merged = <String, EventPhoto>{
        for (final it in _items) it.photoId: it,
        ...incoming,
      };

      final list = merged.values.toList(growable: false);
      list.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      _items = list;
      _nextToken = nonNullRes.nextToken;
      _hasMore = _nextToken != null && _nextToken!.isNotEmpty;
    } catch (e) {
      if (epoch == _requestEpoch) {
        _error = e;
        if (eventChanged) {
          _items = const [];
        }
        _nextToken = null;
        _hasMore = false;
      }
    } finally {
      if (epoch == _requestEpoch) {
        _loading = false;
        _loadedOnce = true;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore({required String eventId}) async {
    if (_loading) return;
    if (!_hasMore) return;

    final trimmedEventId = eventId.trim();
    if (_currentEventId == null || _currentEventId != trimmedEventId) {
      return;
    }

    final token = _idToken;
    if (token == null || token.isEmpty) {
      _error = StateError('Missing idToken');
      notifyListeners();
      return;
    }

    final cursor = _nextToken;
    if (cursor == null || cursor.isEmpty) {
      _hasMore = false;
      notifyListeners();
      return;
    }

    final epoch = ++_requestEpoch;

    _setLoading(true);
    try {
      _error = null;
      final res = await api.list(
        eventId: trimmedEventId,
        limit: 24,
        nextToken: cursor,
        filter: switch (_filter) {
          PhotosGalleryFilter.all => 'all',
          PhotosGalleryFilter.mine => 'mine',
          PhotosGalleryFilter.sharedByMe => 'shared_by_me',
        },
        guestIds: _filter == PhotosGalleryFilter.all && _guestIds.isNotEmpty
            ? _guestIds.toList(growable: false)
            : null,
      );

      if (epoch != _requestEpoch || _currentEventId != trimmedEventId) {
        return;
      }

      final merged = <String, EventPhoto>{
        for (final it in _items) it.photoId: it,
      };
      for (final it in res.items) {
        final sanitized = _sanitizePhoto(it, trimmedEventId);
        if (sanitized != null) {
          merged[sanitized.photoId] = sanitized;
        }
      }

      final list = merged.values.toList(growable: false);
      list.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      _items = list;
      _nextToken = res.nextToken;
      _hasMore = _nextToken != null && _nextToken!.isNotEmpty;
    } catch (e) {
      if (epoch == _requestEpoch) {
        _error = e;
      }
    } finally {
      if (epoch == _requestEpoch) {
        _setLoading(false);
      }
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  EventPhoto? _sanitizePhoto(EventPhoto it, String eventId) {
    if (it.photoId.isEmpty) return null;
    final small = it.smallUrl;
    final medium = it.mediumUrl;
    final original = it.originalUrl;

    final smallOk = small == null || small.isEmpty
        ? true
        : _urlBelongsToEvent(small, eventId);
    final mediumOk = medium == null || medium.isEmpty
        ? true
        : _urlBelongsToEvent(medium, eventId);
    final originalOk = original == null || original.isEmpty
        ? true
        : _urlBelongsToEvent(original, eventId);

    // If any displayed url (small/medium) mismatches, drop.
    if (!smallOk || !mediumOk) {
      if (kDebugMode) {
        debugPrint(
          'gallery_event_guard: drop photoId=${it.photoId} eventId=$eventId smallOk=$smallOk mediumOk=$mediumOk originalOk=$originalOk',
        );
      }
      return null;
    }

    // If we only have original and it mismatches, drop.
    final hasSmall = small != null && small.isNotEmpty;
    final hasMedium = medium != null && medium.isNotEmpty;
    if (!hasSmall && !hasMedium && !originalOk) {
      if (kDebugMode) {
        debugPrint(
          'gallery_event_guard: drop photoId=${it.photoId} eventId=$eventId smallOk=$smallOk mediumOk=$mediumOk originalOk=$originalOk',
        );
      }
      return null;
    }

    // Keep the photo, but never keep a suspicious originalUrl.
    if (!originalOk) {
      return EventPhoto(
        photoId: it.photoId,
        guestId: it.guestId,
        createdAt: it.createdAt,
        uploadedAt: it.uploadedAt,
        status: it.status,
        originalUrl: null,
        mediumUrl: it.mediumUrl,
        smallUrl: it.smallUrl,
        shared: it.shared,
        ownerName: it.ownerName,
        sharedByUserId: it.sharedByUserId,
        sharedByName: it.sharedByName,
        likedByMe: it.likedByMe,
      );
    }

    return it;
  }
}
