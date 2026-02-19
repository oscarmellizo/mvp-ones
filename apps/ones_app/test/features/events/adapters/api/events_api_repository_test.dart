import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_api_client/ones_api_client.dart' as api;
import 'package:ones_app/features/events/adapters/api/events_api_repository.dart';

class _MockDefaultApi extends Mock implements api.DefaultApi {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      api.CreateEventRequest(
        (b) => b
          ..title = 'fallback'
          ..eventTypeId = 'type-1'
          ..location = 'Somewhere'
          ..startAt = DateTime.utc(2025, 1, 1, 10)
          ..endAt = DateTime.utc(2025, 1, 1, 12),
      ),
    );
  });

  test('EventsApiRepository.listEvents maps API models to domain', () async {
    final defaultApi = _MockDefaultApi();

    final apiEvents = BuiltList<api.Event>([
      api.Event((b) => b
        ..id = 'e1'
        ..ownerId = 'u1'
        ..createdAt = DateTime.utc(2025, 1, 1)
        ..title = 'Hello'
        ..eventTypeId = 'type-1'
        ..location = 'Brooklyn, NY'
        ..startAt = DateTime.utc(2025, 1, 1, 10)
        ..endAt = DateTime.utc(2025, 1, 1, 12)),
    ]);

    when(() => defaultApi.listEvents()).thenAnswer(
      (_) async => Response<BuiltList<api.Event>>(
        data: apiEvents,
        requestOptions: RequestOptions(path: '/v1/events'),
        statusCode: 200,
      ),
    );

    final repo = EventsApiRepository.forTesting((_) => defaultApi);
    final events = await repo.listEvents();

    expect(events, hasLength(1));
    expect(events.first.id, 'e1');
    expect(events.first.title, 'Hello');
  });
}
