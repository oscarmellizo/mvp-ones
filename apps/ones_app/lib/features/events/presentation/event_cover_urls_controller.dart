import 'package:flutter/foundation.dart';

import '../adapters/api/event_cover_urls_api_repository.dart';

class EventCoverUrlsController extends ChangeNotifier {
  final EventCoverUrlsApiRepository repository;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<String?>> _inFlight = {};

  EventCoverUrlsController({required this.repository});

  void setIdToken(String? token) {
    repository.setIdToken(token);
  }

  Future<String?> getUrlIfAny({required String eventId, required String? coverKey}) {
    if (coverKey == null || coverKey.trim().isEmpty) {
      return Future.value(null);
    }

    final now = DateTime.now().toUtc();
    final existing = _cache[eventId];
    if (existing != null && existing.expiresAt.isAfter(now.add(const Duration(seconds: 10)))) {
      return Future.value(existing.url);
    }

    final existingFlight = _inFlight[eventId];
    if (existingFlight != null) return existingFlight;

    final fut = () async {
      try {
        final res = await repository.getCoverUrl(eventId);
        final url = res.url;
        final expiresAt = res.expiresAt.toUtc();
        _cache[eventId] = _CacheEntry(url: url, expiresAt: expiresAt);
        return url;
      } catch (_) {
        return null;
      } finally {
        _inFlight.remove(eventId);
        notifyListeners();
      }
    }();

    _inFlight[eventId] = fut;
    return fut;
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
    notifyListeners();
  }

  void invalidate(String eventId) {
    if (eventId.trim().isEmpty) return;
    _cache.remove(eventId.trim());
    _inFlight.remove(eventId.trim());
    notifyListeners();
  }
}

class _CacheEntry {
  final String url;
  final DateTime expiresAt;

  _CacheEntry({required this.url, required this.expiresAt});
}
