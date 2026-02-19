import 'package:flutter/foundation.dart';

import '../adapters/api/events_metadata_api_repository.dart';
import '../domain/events_metadata.dart';

class EventsMetadataController extends ChangeNotifier {
  final EventsMetadataApiRepository repository;

  String? _idToken;
  bool _loading = false;
  Object? _error;
  EventsMetadata? _metadata;

  EventsMetadataController({required this.repository});

  bool get loading => _loading;
  Object? get error => _error;
  EventsMetadata? get metadata => _metadata;

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<void> ensureLoaded() async {
    if (_metadata != null) return;
    await refresh();
  }

  Future<void> refresh() async {
    _setLoading(true);
    try {
      _error = null;
      _metadata = await repository.getMetadata(_idToken);
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
