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
  Object? _error;
  List<EventPhoto> _items = const [];

  int _requestEpoch = 0;

  PhotosGalleryFilter _filter = PhotosGalleryFilter.all;
  Set<String> _guestIds = <String>{};
  String? _nextToken;
  bool _hasMore = true;

  String? _currentEventId;

  PhotosGalleryController({required this.api});

  bool get loading => _loading;
  Object? get error => _error;
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

    _loading = false;
    _error = null;
    _items = const [];
    _nextToken = null;
    _hasMore = true;
    _currentEventId = null;
    _requestEpoch++;
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
    final token = _idToken;
    if (token == null || token.isEmpty) {
      _error = StateError('Missing idToken');
      notifyListeners();
      return;
    }

    final trimmedEventId = eventId.trim();
    if (trimmedEventId.isEmpty) return;

    if (_currentEventId != trimmedEventId) {
      _currentEventId = trimmedEventId;
      _items = const [];
      _nextToken = null;
      _hasMore = true;
      _error = null;
      _requestEpoch++;
      notifyListeners();
    }

    final epoch = ++_requestEpoch;

    _setLoading(true);
    try {
      _error = null;

      _nextToken = null;
      _hasMore = true;

      final res = await api.list(
        eventId: trimmedEventId,
        limit: 9,
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
        for (final it in res.items) it.photoId: it,
      };

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
        _items = const [];
        _nextToken = null;
        _hasMore = false;
      }
    } finally {
      if (epoch == _requestEpoch) {
        _setLoading(false);
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
        limit: 9,
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
        merged[it.photoId] = it;
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
}
