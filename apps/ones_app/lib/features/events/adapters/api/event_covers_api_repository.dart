import 'package:ones_api_client/ones_api_client.dart' as api;

import '../../../../core/http/ones_api_factory.dart';

class EventCoversApiRepository {
  final api.DefaultApi Function(String? idToken) _defaultApi;

  String? _idToken;

  EventCoversApiRepository(OnesApiFactory apiFactory)
      : _defaultApi =
            ((idToken) => apiFactory.create(idToken: idToken).getDefaultApi());

  EventCoversApiRepository.forTesting(
      api.DefaultApi Function(String? idToken) defaultApiFactory)
      : _defaultApi = defaultApiFactory;

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<api.GenerateEventCoverResponse> generate({
    required String eventName,
    required String categoryLabel,
    required String eventTypeLabel,
    required String location,
    String? size,
  }) async {
    final req = api.GenerateEventCoverRequest((b) => b
      ..eventName = eventName
      ..categoryLabel = categoryLabel
      ..eventTypeLabel = eventTypeLabel
      ..location = location
      ..size = size);

    final res = await _defaultApi(_idToken)
        .generateEventCover(generateEventCoverRequest: req);

    final data = res.data;
    if (data == null) {
      throw StateError('Missing generateEventCover response');
    }
    return data;
  }

  Future<String> accept(String coverId) async {
    final res = await _defaultApi(_idToken).acceptEventCover(coverId: coverId);
    final data = res.data;
    if (data == null) {
      throw StateError('Missing acceptEventCover response');
    }
    return data.reservationId;
  }

  Future<void> cancel(String coverId) async {
    await _defaultApi(_idToken).cancelEventCover(coverId: coverId);
  }
}
