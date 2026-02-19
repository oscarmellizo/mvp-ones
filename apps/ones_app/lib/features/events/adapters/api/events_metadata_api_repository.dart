import 'package:dio/dio.dart';

import '../../../../core/http/ones_api_factory.dart';
import '../../domain/events_metadata.dart';

class EventsMetadataApiRepository {
  final Dio Function(String? idToken) _dioFactory;

  EventsMetadataApiRepository(OnesApiFactory apiFactory)
      : _dioFactory = ((idToken) => apiFactory.create(idToken: idToken).dio);

  EventsMetadataApiRepository.forTesting(Dio Function(String? idToken) dioFactory)
      : _dioFactory = dioFactory;

  Future<EventsMetadata> getMetadata(String? idToken) async {
    final res = await _dioFactory(idToken).get(
      '/v1/events/metadata',
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
    if (data is Map<String, dynamic>) {
      return EventsMetadata.fromJson(data);
    }

    throw StateError('Invalid events metadata response');
  }
}
