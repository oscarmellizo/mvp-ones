import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';

class EventComplementsApiRepository {
  final OnesApiFactory _apiFactory;
  String? _idToken;

  EventComplementsApiRepository(this._apiFactory);

  void setIdToken(String? token) => _idToken = token;

  Future<List<Map<String, dynamic>>> list(String eventId) async {
    final response = await _secureDio().get('/v1/events/$eventId/complements');
    return (response.data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Dio _secureDio() {
    final dio = _apiFactory.create(idToken: _idToken).dio;
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
