import 'package:flutter/foundation.dart';

import '../adapters/api/admin_admins_api_repository.dart';

class AdminAdminsController extends ChangeNotifier {
  final AdminAdminsApiRepository repository;

  String? _idToken;

  bool _loading = false;
  Object? _error;

  List<AdminUserView> _items = const [];
  String? _nextToken;

  AdminAdminsController({required this.repository});

  bool get loading => _loading;
  Object? get error => _error;
  List<AdminUserView> get items => _items;
  String? get nextToken => _nextToken;

  void setIdToken(String? token) {
    _idToken = token;
    repository.setIdToken(token);
  }

  Future<void> refresh() async {
    if (_idToken == null || _idToken!.isEmpty) return;
    _setLoading(true);
    try {
      _error = null;
      final res = await repository.list(limit: 200);
      _items = res.items;
      _nextToken = res.nextToken;
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addAdmin(String email) async {
    if (_idToken == null || _idToken!.isEmpty) return;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;

    _setLoading(true);
    try {
      _error = null;
      final saved = await repository.upsert(email: normalized, status: 'active');
      _items = _merge(saved, _items);
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> setStatus(String email, bool active) async {
    if (_idToken == null || _idToken!.isEmpty) return;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return;

    _setLoading(true);
    try {
      _error = null;
      final saved = await repository.updateStatus(
        email: normalized,
        status: active ? 'active' : 'inactive',
      );
      _items = _merge(saved, _items);
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  List<AdminUserView> _merge(AdminUserView saved, List<AdminUserView> existing) {
    final next = <AdminUserView>[];
    bool replaced = false;
    for (final it in existing) {
      if (it.email.toLowerCase() == saved.email.toLowerCase()) {
        next.add(saved);
        replaced = true;
      } else {
        next.add(it);
      }
    }
    if (!replaced) {
      next.insert(0, saved);
    }
    next.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
    return next;
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
