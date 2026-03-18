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

  PhotosGalleryFilter _filter = PhotosGalleryFilter.all;
  Set<String> _guestIds = <String>{};
  String? _nextToken;
  bool _hasMore = true;

  PhotosGalleryController({required this.api});

  bool get loading => _loading;
  Object? get error => _error;
  List<EventPhoto> get items => _items;

  PhotosGalleryFilter get filter => _filter;
  Set<String> get guestIds => _guestIds;
  bool get hasMore => _hasMore;

  void setIdToken(String? token) {
    _idToken = token;
    api.setIdToken(token);
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

    _setLoading(true);
    try {
      _error = null;

      _nextToken = null;
      _hasMore = true;

      final res = await api.list(
        eventId: eventId,
        limit: 50,
        filter: switch (_filter) {
          PhotosGalleryFilter.all => 'all',
          PhotosGalleryFilter.mine => 'mine',
          PhotosGalleryFilter.sharedByMe => 'shared_by_me',
        },
        guestIds: _filter == PhotosGalleryFilter.all && _guestIds.isNotEmpty
            ? _guestIds.toList(growable: false)
            : null,
      );

      _items = res.items;
      _nextToken = res.nextToken;
      _hasMore = _nextToken != null && _nextToken!.isNotEmpty;
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMore({required String eventId}) async {
    if (_loading) return;
    if (!_hasMore) return;

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

    _setLoading(true);
    try {
      _error = null;
      final res = await api.list(
        eventId: eventId,
        limit: 50,
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
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
