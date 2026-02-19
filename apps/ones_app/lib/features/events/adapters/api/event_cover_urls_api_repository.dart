import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/http/ones_api_factory.dart';

class EventCoverUrlsApiRepository {
  final api.DefaultApi Function(String? idToken) _defaultApi;

  String? _idToken;

  EventCoverUrlsApiRepository(OnesApiFactory apiFactory)
      : _defaultApi =
            ((idToken) => apiFactory.create(idToken: idToken).getDefaultApi());

  EventCoverUrlsApiRepository.forTesting(
      api.DefaultApi Function(String? idToken) defaultApiFactory)
      : _defaultApi = defaultApiFactory;

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<api.PresignedUrlResponse> getCoverUrl(String eventId) async {
    final res = await _defaultApi(_idToken).getEventCoverUrl(id: eventId);
    final data = res.data;
    if (data == null) {
      throw StateError('Missing getEventCoverUrl response');
    }
    return data;
  }
}
