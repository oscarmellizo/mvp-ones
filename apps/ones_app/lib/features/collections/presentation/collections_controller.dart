import 'package:flutter/foundation.dart';

import '../adapters/api/collections_api_repository.dart';
import '../domain/collection.dart';

class CollectionsController extends ChangeNotifier {
  final CollectionsApiRepository repository;
  String? _idToken;
  String? _sessionUserId;
  bool _ensuredLife = false;
  bool _timeZoneSynced = false;
  bool _loading = false;
  Object? _error;
  List<OnesCollection> _collections = const [];

  CollectionsController(this.repository);

  bool get loading => _loading;
  Object? get error => _error;
  List<OnesCollection> get collections => _collections;

  void setIdToken(String? token, {String? userId}) {
    if (_idToken == token && _sessionUserId == userId) return;
    _idToken = token;
    _sessionUserId = userId;
    _ensuredLife = false;
    _timeZoneSynced = false;
    _collections = const [];
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_idToken == null || _idToken!.isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (!_timeZoneSynced) {
        try {
          await repository.syncTimeZone();
          _timeZoneSynced = true;
        } catch (_) {
          // Time-zone sync is retried on the next refresh without blocking collections.
        }
      }
      if (!_ensuredLife) {
        await repository.ensureLife();
        _ensuredLife = true;
      }
      _collections = await repository.list();
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<OnesCollection> create({
    required String name,
    required CollectionType type,
    String? description,
    List<String> inviteeEmails = const [],
  }) async {
    final collection = await repository.create(
      name: name,
      type: type.apiValue,
      description: description,
      inviteeEmails: inviteeEmails,
    );
    _collections = [collection, ..._collections];
    notifyListeners();
    return collection;
  }

  Future<List<CollectionMember>> members(String collectionId) =>
      repository.members(collectionId);

  Future<List<CollectionMember>> invite(
      String collectionId, List<String> emails) async {
    final members = await repository.invite(collectionId, emails);
    return members;
  }

  Future<String> rotateJoinQr(String collectionId) =>
      repository.rotateJoinQr(collectionId);

  Future<String?> setJoinQr(String collectionId, bool enabled) =>
      repository.setJoinQr(collectionId, enabled);

  Future<void> joinByQr({
    required String collectionId,
    required String token,
  }) async {
    await repository.joinByQr(collectionId: collectionId, token: token);
    await refresh();
  }

  Future<void> leave(String collectionId) async {
    await repository.leave(collectionId);
    _collections = _collections
        .where((collection) => collection.id != collectionId)
        .toList();
    notifyListeners();
  }

  Future<void> delete(String collectionId) async {
    await repository.delete(collectionId);
    _collections = _collections
        .where((collection) => collection.id != collectionId)
        .toList();
    notifyListeners();
  }

  Future<void> removeMember(String collectionId, String memberKey) =>
      repository.removeMember(collectionId, memberKey);

  Future<void> transferOwnership(String collectionId, String newOwnerId) async {
    await repository.transferOwnership(collectionId, newOwnerId);
    await refresh();
  }

  Future<CollectionMember> respondToInvitation(String token) =>
      repository.respondToInvitation(token);
}
