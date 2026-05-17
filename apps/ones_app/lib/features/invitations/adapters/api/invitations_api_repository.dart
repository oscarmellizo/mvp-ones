import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/http/ones_api_factory.dart';

class InvitationsApiRepository {
  final api.DefaultApi Function(String? idToken) _defaultApi;
  final OnesApiFactory? _apiFactory;

  String? _idToken;

  InvitationsApiRepository(OnesApiFactory apiFactory)
      : _defaultApi =
            ((idToken) => apiFactory.create(idToken: idToken).getDefaultApi()),
        _apiFactory = apiFactory;

  InvitationsApiRepository.forTesting(
      api.DefaultApi Function(String? idToken) defaultApiFactory)
      : _defaultApi = defaultApiFactory,
        _apiFactory = null;

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<List<api.Invitation>> list() async {
    final response = await _defaultApi(_idToken).listInvitations();
    final BuiltList<api.Invitation>? items = response.data;
    return items?.toList() ?? const <api.Invitation>[];
  }

  Future<api.Invitation> resolve(String token) async {
    final apiFactory = _apiFactory;
    if (apiFactory == null) {
      throw StateError(
          'InvitationsApiRepository.resolve is not available in forTesting mode');
    }

    final dio = apiFactory.create(idToken: _idToken).dio;
    final res = await dio.get(
      '/v1/invitations/resolve',
      queryParameters: {'token': token},
      options: Options(
        extra: {
          'secure': [
            {
              'type': 'http',
              'scheme': 'bearer',
              'name': 'bearerAuth',
            }
          ],
        },
      ),
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid resolve invitation response');
    }
    return api.standardSerializers
        .deserializeWith(api.Invitation.serializer, data) as api.Invitation;
  }

  Future<api.Invitation> accept(String eventId) async {
    final response =
        await _defaultApi(_idToken).acceptInvitation(eventId: eventId);
    final api.Invitation? inv = response.data;
    if (inv == null) {
      throw StateError('Missing invitation in response');
    }
    return inv;
  }

  Future<api.Invitation> reject(String eventId) async {
    final response =
        await _defaultApi(_idToken).rejectInvitation(eventId: eventId);
    final api.Invitation? inv = response.data;
    if (inv == null) {
      throw StateError('Missing invitation in response');
    }
    return inv;
  }
}
