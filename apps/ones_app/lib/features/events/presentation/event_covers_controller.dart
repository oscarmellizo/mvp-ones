import 'package:flutter/foundation.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../adapters/api/event_covers_api_repository.dart';

class EventCoversController extends ChangeNotifier {
  final EventCoversApiRepository repository;

  bool _loading = false;
  Object? _error;

  api.GenerateEventCoverResponse? _preview;
  String? _reservationId;

  EventCoversController({required this.repository});

  bool get loading => _loading;
  Object? get error => _error;

  api.GenerateEventCoverResponse? get preview => _preview;
  String? get reservationId => _reservationId;

  void setIdToken(String? token) {
    repository.setIdToken(token);
    notifyListeners();
  }

  Future<void> generate({
    required String eventName,
    required String categoryLabel,
    required String eventTypeLabel,
    required String location,
    String? size,
  }) async {
    _setLoading(true);
    try {
      _error = null;
      _reservationId = null;
      _preview = await repository.generate(
        eventName: eventName,
        categoryLabel: categoryLabel,
        eventTypeLabel: eventTypeLabel,
        location: location,
        size: size,
      );
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> accept() async {
    final coverId = _preview?.coverId;
    if (coverId == null || coverId.isEmpty) return;

    _setLoading(true);
    try {
      _error = null;
      _reservationId = await repository.accept(coverId);
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cancel() async {
    final coverId = _preview?.coverId;
    _setLoading(true);
    try {
      _error = null;
      if (coverId != null && coverId.isNotEmpty) {
        await repository.cancel(coverId);
      }
      _preview = null;
      _reservationId = null;
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void clear() {
    _preview = null;
    _reservationId = null;
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
