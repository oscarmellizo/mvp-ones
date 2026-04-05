import 'package:flutter/foundation.dart';

import '../adapters/api/admin_frames_api_repository.dart';

class AdminFramesController extends ChangeNotifier {
  final AdminFramesApiRepository repository;

  bool _loading = false;
  Object? _lastError;

  List<FrameDto> _items = const [];

  AdminFramesController({
    required this.repository,
  });

  bool get loading => _loading;
  Object? get lastError => _lastError;
  List<FrameDto> get items => _items;

  void setIdToken(String? token) {
    repository.setIdToken(token);
  }

  Future<void> load() async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      final res = await repository.list();
      _items = res.items;
    } catch (e) {
      _lastError = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> create({
    required String name,
    int? sortOrder,
  }) async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      await repository.upsert(
        name: name,
        status: 'active',
        sortOrder: sortOrder,
      );
      final res = await repository.list();
      _items = res.items;
    } catch (e) {
      _lastError = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateStatus({
    required String frameId,
    required bool active,
  }) async {
    final current = _items.where((e) => e.frameId == frameId).toList();
    if (current.isEmpty) return;

    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      final f = current.first;
      await repository.upsert(
        frameId: f.frameId,
        name: f.name,
        status: active ? 'active' : 'inactive',
        sortOrder: f.sortOrder,
      );
      final res = await repository.list();
      _items = res.items;
    } catch (e) {
      _lastError = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> delete({required String frameId}) async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      await repository.delete(frameId: frameId);
      final res = await repository.list();
      _items = res.items;
    } catch (e) {
      _lastError = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
