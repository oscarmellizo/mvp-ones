import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../../core/http/ones_api_factory.dart';
import '../../domain/collection.dart';

class CollectionsApiRepository {
  final Dio Function(String? idToken) _dioFactory;
  String? _idToken;

  CollectionsApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((token) => apiFactory.create(idToken: token).dio);

  CollectionsApiRepository.forTesting(this._dioFactory);

  void setIdToken(String? token) => _idToken = token;

  Future<void> ensureLife() async {
    await _secureDio().post('/v1/collections/ensure-life');
  }

  Future<void> syncTimeZone() async {
    final timeZone = await FlutterTimezone.getLocalTimezone();
    await _secureDio().put(
      '/v1/users/time-zone',
      data: {'timeZone': timeZone.identifier},
    );
  }

  Future<List<OnesCollection>> list() async {
    final response = await _secureDio().get('/v1/collections');
    return (response.data as List)
        .whereType<Map>()
        .map((item) => OnesCollection.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<OnesCollection> create({
    required String name,
    required String type,
    String? description,
    String? coverKey,
    List<String> inviteeEmails = const [],
  }) async {
    final response = await _secureDio().post(
      '/v1/collections',
      data: {
        'name': name,
        'type': type,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (coverKey != null && coverKey.trim().isNotEmpty)
          'coverKey': coverKey.trim(),
        if (inviteeEmails.isNotEmpty) 'inviteeEmails': inviteeEmails,
      },
    );
    return OnesCollection.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<CollectionMember>> members(String collectionId) async {
    final response =
        await _secureDio().get('/v1/collections/$collectionId/members');
    final data = response.data as Map;
    return (data['items'] as List)
        .whereType<Map>()
        .map((item) =>
            CollectionMember.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<CollectionMember>> invite(
      String collectionId, List<String> inviteeEmails) async {
    final response = await _secureDio().post(
      '/v1/collections/$collectionId/invitees',
      data: {'inviteeEmails': inviteeEmails},
    );
    return (response.data as List)
        .whereType<Map>()
        .map((item) =>
            CollectionMember.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<String> rotateJoinQr(String collectionId) async {
    final response =
        await _secureDio().post('/v1/collections/$collectionId/join-qr/rotate');
    return (response.data as Map)['url'] as String;
  }

  Future<String?> setJoinQr(String collectionId, bool enabled) async {
    final response = await _secureDio().put(
      '/v1/collections/$collectionId/join-qr',
      data: {'enabled': enabled},
    );
    return (response.data as Map)['url'] as String?;
  }

  Future<void> joinByQr({
    required String collectionId,
    required String token,
  }) async {
    await _secureDio().post(
      '/v1/collections/join-qr/join',
      data: {'collectionId': collectionId, 'token': token},
    );
  }

  Future<CollectionMember> respondToInvitation(String token) async {
    final response = await _secureDio().post(
      '/v1/collections/invitations/respond',
      data: {'token': token},
    );
    return CollectionMember.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> leave(String collectionId) async {
    await _secureDio().post('/v1/collections/$collectionId/members/leave');
  }

  Future<void> delete(String collectionId) async {
    await _secureDio()
        .delete('/v1/collections/${Uri.encodeComponent(collectionId)}');
  }

  Future<void> removeMember(String collectionId, String memberKey) async {
    await _secureDio().delete(
      '/v1/collections/$collectionId/members/${Uri.encodeComponent(memberKey)}',
    );
  }

  Future<void> transferOwnership(String collectionId, String newOwnerId) async {
    await _secureDio().put(
      '/v1/collections/$collectionId/owner',
      data: {'newOwnerId': newOwnerId},
    );
  }

  Dio _secureDio() {
    final dio = _dioFactory(_idToken);
    dio.options.extra['secure'] = const [
      {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'}
    ];
    return dio;
  }
}
