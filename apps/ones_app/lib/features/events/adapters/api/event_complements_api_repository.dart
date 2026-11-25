import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';

class EventComplementsApiRepository {
  final Dio Function(String? idToken) _dioFactory;
  String? _idToken;

  EventComplementsApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  EventComplementsApiRepository.forTesting(this._dioFactory);

  void setIdToken(String? token) => _idToken = token;

  Future<List<Map<String, dynamic>>> list(String eventId) async {
    final response = await _secureDio().get('/v1/events/$eventId/complements');
    return (response.data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> setEnabled({
    required String eventId,
    required String complementId,
    required bool enabled,
  }) async {
    await _secureDio().put(
      '/v1/events/$eventId/complements/$complementId',
      data: {'enabled': enabled},
    );
  }

  Dio _secureDio() {
    final dio = _dioFactory(_idToken);
    dio.options.extra['secure'] = const [
      {
        'type': 'http',
        'scheme': 'bearer',
        'name': 'bearerAuth',
      }
    ];
    return dio;
  }
}
