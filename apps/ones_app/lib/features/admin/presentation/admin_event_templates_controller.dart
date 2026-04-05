import 'package:flutter/foundation.dart';

import '../adapters/api/admin_event_templates_api_repository.dart';

class AdminEventTemplatesController extends ChangeNotifier {
  final AdminEventTemplatesApiRepository repository;
  List<EventTemplateDto> _items = [];
  bool _loading = false;
  String? _lastError;

  AdminEventTemplatesController({required this.repository});

  List<EventTemplateDto> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  String? get lastError => _lastError;

  Future<void> load({String? status}) async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      _items = await repository.list(status: status);
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) print(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> create({
    required String name,
    required String status,
    required int? sortOrder,
    required List<String> frameIds,
  }) async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      final created = await repository.create(
        name: name,
        status: status,
        sortOrder: sortOrder,
        frameIds: frameIds,
      );
      _items.add(created);
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) print(e);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> update({
    required String eventTemplateId,
    required String name,
    required String status,
    required int? sortOrder,
    required List<String> frameIds,
  }) async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      final updated = await repository.update(
        eventTemplateId: eventTemplateId,
        name: name,
        status: status,
        sortOrder: sortOrder,
        frameIds: frameIds,
      );
      final index =
          _items.indexWhere((e) => e.eventTemplateId == eventTemplateId);
      if (index != -1) {
        _items[index] = updated;
      }
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) print(e);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> delete({required String eventTemplateId}) async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      await repository.delete(eventTemplateId: eventTemplateId);
      _items.removeWhere((e) => e.eventTemplateId == eventTemplateId);
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) print(e);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus({
    required String eventTemplateId,
    required bool active,
  }) async {
    final et = _items.firstWhere((e) => e.eventTemplateId == eventTemplateId);
    await update(
      eventTemplateId: eventTemplateId,
      name: et.name,
      status: active ? 'active' : 'inactive',
      sortOrder: et.sortOrder,
      frameIds: et.frameIds,
    );
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}
