import 'package:flutter/foundation.dart';

import '../adapters/api/event_photos_api.dart';
import '../domain/event_photo.dart';

class PhotosGalleryController extends ChangeNotifier {
  final EventPhotosApi api;

  String? _idToken;
  bool _loading = false;
  Object? _error;
  List<EventPhoto> _items = const [];

  PhotosGalleryController({required this.api});

  bool get loading => _loading;
  Object? get error => _error;
  List<EventPhoto> get items => _items;

  void setIdToken(String? token) {
    _idToken = token;
    api.setIdToken(token);
  }

  Future<void> refreshMerged({required String eventId}) async {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      _error = StateError('Missing idToken');
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      _error = null;

      final pages = await Future.wait([
        api.list(eventId: eventId, limit: 50, scope: 'guest'),
        api.list(eventId: eventId, limit: 50, scope: 'shared'),
      ]);

      if (kDebugMode) {
        debugPrint(
            '[PhotosGallery] guest=${pages[0].items.length} shared=${pages[1].items.length}');
      }

      final mergedById = <String, EventPhoto>{};
      for (final p in pages) {
        for (final item in p.items) {
          mergedById[item.photoId] = item;
        }
      }

      final merged = mergedById.values.toList(growable: false);
      merged.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      _items = merged;

      if (kDebugMode) {
        debugPrint('[PhotosGallery] merged=${_items.length}');
      }
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
