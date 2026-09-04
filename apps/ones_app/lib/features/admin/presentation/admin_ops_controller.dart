import 'package:flutter/foundation.dart';

import '../../domain/admin_ops_repository.dart';

class AdminOpsController extends ChangeNotifier {
  final AdminOpsRepository repository;
  String? _idToken;

  Map<String, dynamic>? _queues;
  Map<String, dynamic>? _mappings;
  Object? _error;
  bool _isLoading = false;

  AdminOpsController({required this.repository});

  void setIdToken(String? idToken) {
    _idToken = idToken;
  }

  Map<String, dynamic>? get queues => _queues;
  Map<String, dynamic>? get mappings => _mappings;
  Object? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> loadQueues() async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    _setLoading(true);
    try {
      _error = null;
      _queues = await repository.getQueues(token);
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMappings() async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    _setLoading(true);
    try {
      _error = null;
      _mappings = await repository.getMappings(token);
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setRealtimeMapping(bool enabled) async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    _setLoading(true);
    try {
      _error = null;
      await repository.setRealtimeMapping(token, enabled);
      await loadMappings();
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
