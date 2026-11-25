import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/events/adapters/api/event_complements_api_repository.dart';

void main() {
  test('setEnabled sends the selected complement state to its event route',
      () async {
    final dio = Dio(
      BaseOptions(baseUrl: 'https://appdev.ones.events/api'),
    );
    RequestOptions? request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<void>(
              requestOptions: options,
              statusCode: 204,
            ),
          );
        },
      ),
    );
    final repository = EventComplementsApiRepository.forTesting((_) => dio);

    await repository.setEnabled(
      eventId: 'event-1',
      complementId: 'tournament',
      enabled: true,
    );

    expect(request?.method, 'PUT');
    expect(request?.uri.path, '/api/v1/events/event-1/complements/tournament');
    expect(request?.data, {'enabled': true});
    dio.close();
  });
}
