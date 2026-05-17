import 'package:flutter/foundation.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';

import '../adapters/api/invitations_api_repository.dart';

class InvitationsController extends ChangeNotifier {
  final InvitationsApiRepository repository;

  String? _idToken;

  bool _loading = false;
  Object? _error;

  List<api.Invitation> _items = const [];

  static const _seenKey = 'ones.invitations.seenEventIds';
  Set<String> _seenEventIds = const {};

  InvitationsController({required this.repository});

  bool get loading => _loading;
  Object? get error => _error;
  List<api.Invitation> get items => _items;

  int get unreadCount {
    if (_seenEventIds.isEmpty) {
      return _items
          .where((i) => i.status == api.InvitationStatusEnum.invited)
          .length;
    }
    return _items
        .where((i) => i.status == api.InvitationStatusEnum.invited)
        .where((i) => !_seenEventIds.contains(i.eventId))
        .length;
  }

  void setIdToken(String? token) {
    _idToken = token;
    repository.setIdToken(token);
  }

  api.Invitation? invitationForEvent(String eventId) {
    for (final i in _items) {
      if (i.eventId == eventId) return i;
    }
    return null;
  }

  Future<void> refresh() async {
    if (_idToken == null || _idToken!.isEmpty) return;
    _setLoading(true);
    try {
      _error = null;
      await _ensureSeenLoaded();
      _items = await repository.list();
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAllSeen() async {
    await _ensureSeenLoaded();
    final next = <String>{..._seenEventIds};
    for (final i in _items) {
      next.add(i.eventId);
    }
    if (setEquals(next, _seenEventIds)) return;
    _seenEventIds = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenKey, next.toList(growable: false));
    } catch (_) {
      // If SharedPreferences is not available (e.g. some Flutter web setups),
      // keep the in-memory seen set so the app doesn't crash.
    }
    notifyListeners();
  }

  Future<void> _ensureSeenLoaded() async {
    if (_seenEventIds.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_seenKey) ?? const <String>[];
      _seenEventIds = list.toSet();
    } catch (_) {
      _seenEventIds = const {};
    }
  }

  Future<void> accept(String eventId) async {
    _setLoading(true);
    try {
      _error = null;
      await repository.accept(eventId);
      _items =
          _items.where((i) => i.eventId != eventId).toList(growable: false);
      if (_seenEventIds.contains(eventId)) {
        _seenEventIds = {..._seenEventIds}..remove(eventId);
      }
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reject(String eventId) async {
    _setLoading(true);
    try {
      _error = null;
      await repository.reject(eventId);
      _items =
          _items.where((i) => i.eventId != eventId).toList(growable: false);
      if (_seenEventIds.contains(eventId)) {
        _seenEventIds = {..._seenEventIds}..remove(eventId);
      }
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
