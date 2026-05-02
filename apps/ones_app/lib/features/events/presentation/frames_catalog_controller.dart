import 'package:flutter/foundation.dart';

import '../adapters/api/frames_api_repository.dart';

class FramesCatalogController extends ChangeNotifier {
  final FramesApiRepository repository;

  bool _loading = false;
  Object? _error;
  List<FrameCatalogItem> _items = const [];

  String? _nextToken;
  bool _hasMore = true;

  FramesCatalogController({required this.repository});

  bool get loading => _loading;
  Object? get error => _error;
  List<FrameCatalogItem> get items => _items;
  bool get hasMore => _hasMore;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _nextToken = null;
      _hasMore = true;

      final res = await repository.listFrames(limit: 50);
      _items = res.items;
      _nextToken = res.nextToken;
      _hasMore = _nextToken != null && _nextToken!.isNotEmpty;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loading) return;
    if (!_hasMore) return;

    final cursor = _nextToken;
    if (cursor == null || cursor.isEmpty) {
      _hasMore = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await repository.listFrames(limit: 50, nextToken: cursor);
      final merged = <String, FrameCatalogItem>{
        for (final it in _items) it.frameId: it,
      };
      for (final it in res.items) {
        merged[it.frameId] = it;
      }

      final list = merged.values.toList(growable: false);
      list.sort((a, b) {
        final ao = a.name ?? '';
        final bo = b.name ?? '';
        return ao.toLowerCase().compareTo(bo.toLowerCase());
      });

      _items = list;
      _nextToken = res.nextToken;
      _hasMore = _nextToken != null && _nextToken!.isNotEmpty;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
