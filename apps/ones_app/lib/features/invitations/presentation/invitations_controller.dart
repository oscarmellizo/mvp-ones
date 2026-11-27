import 'package:flutter/foundation.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';

import '../adapters/api/invitations_api_repository.dart';
import '../../collections/adapters/api/collections_api_repository.dart';
import '../../collections/domain/collection_invitation.dart';

class InvitationsController extends ChangeNotifier {
  final InvitationsApiRepository repository;
  final CollectionsApiRepository? collectionsRepository;

  String? _idToken;

  bool _loading = false;
  Object? _error;

  List<api.Invitation> _items = const [];
  List<CollectionInvitation> _collectionItems = const [];
  String? _collectionNextToken;
  bool _collectionHasMore = false;
  Object? _collectionError;

  static const _seenKey = 'ones.invitations.seenEventIds';
  static const _seenCollectionKey =
      'ones.invitations.seenCollectionInvitationIds';
  Set<String> _seenEventIds = const {};
  Set<String> _seenCollectionInvitationIds = const {};
  bool _seenLoaded = false;

  InvitationsController({
    required this.repository,
    this.collectionsRepository,
  });

  bool get loading => _loading;
  Object? get error => _error;
  List<api.Invitation> get items => _items;
  List<CollectionInvitation> get collectionItems => _collectionItems;
  Object? get collectionError => _collectionError;
  bool get collectionHasMore => _collectionHasMore;

  int get unreadCount {
    final eventCount = _items
        .where((i) => i.status == api.InvitationStatusEnum.invited)
        .where((i) => !_seenEventIds.contains(i.eventId))
        .length;
    final collectionCount = _collectionItems
        .where((i) => !_seenCollectionInvitationIds.contains(i.seenId))
        .length;
    final count = eventCount + collectionCount;
    return _collectionHasMore && count < 100 ? 100 : count;
  }

  void setIdToken(String? token) {
    if (_idToken == token) {
      repository.setIdToken(token);
      collectionsRepository?.setIdToken(token);
      return;
    }
    _idToken = token;
    repository.setIdToken(token);
    collectionsRepository?.setIdToken(token);
    _items = const [];
    _collectionItems = const [];
    _collectionNextToken = null;
    _collectionHasMore = false;
    _collectionError = null;
    _error = null;
    notifyListeners();
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
      Object? eventError;
      Object? collectionError;
      try {
        _items = await repository.list();
      } catch (error) {
        eventError = error;
      }
      final collections = collectionsRepository;
      if (collections != null) {
        try {
          final page = await collections.pendingInvitations(limit: 100);
          _collectionItems = page.items;
          _collectionNextToken = page.nextToken;
          _collectionHasMore =
              page.nextToken != null && page.nextToken!.isNotEmpty;
        } catch (error) {
          collectionError = error;
        }
      } else {
        _collectionItems = const [];
        _collectionNextToken = null;
        _collectionHasMore = false;
      }
      _error = eventError;
      _collectionError = collectionError;
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAllSeen() async {
    await _ensureSeenLoaded();
    final next = <String>{..._seenEventIds};
    final nextCollections = <String>{..._seenCollectionInvitationIds};
    for (final i in _items) {
      next.add(i.eventId);
    }
    for (final invitation in _collectionItems) {
      nextCollections.add(invitation.seenId);
    }
    final eventsChanged = !setEquals(next, _seenEventIds);
    final collectionsChanged =
        !setEquals(nextCollections, _seenCollectionInvitationIds);
    if (!eventsChanged && !collectionsChanged) return;
    _seenEventIds = next;
    _seenCollectionInvitationIds = nextCollections;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_seenKey, next.toList(growable: false));
      await prefs.setStringList(
        _seenCollectionKey,
        nextCollections.toList(growable: false),
      );
    } catch (_) {
      // If SharedPreferences is not available (e.g. some Flutter web setups),
      // keep the in-memory seen set so the app doesn't crash.
    }
    notifyListeners();
  }

  Future<void> _ensureSeenLoaded() async {
    if (_seenLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_seenKey) ?? const <String>[];
      _seenEventIds = list.toSet();
      final collectionList =
          prefs.getStringList(_seenCollectionKey) ?? const <String>[];
      _seenCollectionInvitationIds = collectionList.toSet();
    } catch (_) {
      _seenEventIds = const {};
      _seenCollectionInvitationIds = const {};
    } finally {
      _seenLoaded = true;
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

  Future<void> loadMoreCollectionInvitations() async {
    final collections = collectionsRepository;
    final cursor = _collectionNextToken;
    if (_loading ||
        collections == null ||
        cursor == null ||
        cursor.isEmpty ||
        _idToken == null ||
        _idToken!.isEmpty) {
      return;
    }
    _setLoading(true);
    try {
      final page = await collections.pendingInvitations(
        limit: 100,
        nextToken: cursor,
      );
      final byId = <String, CollectionInvitation>{
        for (final item in _collectionItems) item.seenId: item,
        for (final item in page.items) item.seenId: item,
      };
      _collectionItems = byId.values.toList(growable: false);
      _collectionNextToken = page.nextToken;
      _collectionHasMore = page.nextToken != null && page.nextToken!.isNotEmpty;
      _collectionError = null;
    } catch (error) {
      _collectionError = error;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> acceptCollection(String collectionId) =>
      _respondToCollection(collectionId, 'accept');

  Future<void> rejectCollection(String collectionId) =>
      _respondToCollection(collectionId, 'reject');

  Future<void> _respondToCollection(String collectionId, String action) async {
    final collections = collectionsRepository;
    if (collections == null) {
      throw StateError('Collection invitations are unavailable');
    }
    _setLoading(true);
    try {
      _collectionError = null;
      final responded = _collectionItems
          .where((invitation) => invitation.collectionId == collectionId)
          .firstOrNull;
      await collections.respondToIncomingInvitation(
        collectionId: collectionId,
        action: action,
      );
      _collectionItems = _collectionItems
          .where((invitation) => invitation.collectionId != collectionId)
          .toList(growable: false);
      if (responded != null) {
        _seenCollectionInvitationIds = {
          ..._seenCollectionInvitationIds,
          responded.seenId,
        };
      }
      await _persistSeenCollections();
    } catch (error) {
      _collectionError = error;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _persistSeenCollections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _seenCollectionKey,
        _seenCollectionInvitationIds.toList(growable: false),
      );
    } catch (_) {
      // Keep the in-memory state if browser storage is unavailable.
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
