import 'package:test/test.dart';
import 'package:ones_api_client/ones_api_client.dart';


/// tests for DefaultApi
void main() {
  final instance = OnesApiClient().getDefaultApi();

  group(DefaultApi, () {
    // Create event for authenticated user
    //
    //Future<Event> createEvent(CreateEventRequest createEventRequest) async
    test('test createEvent', () async {
      // TODO
    });

    // Get event by id (only if it belongs to authenticated user)
    //
    //Future<Event> getEvent(String id) async
    test('test getEvent', () async {
      // TODO
    });

    // Health check
    //
    //Future<HealthResponse> health() async
    test('test health', () async {
      // TODO
    });

    // List events for authenticated user
    //
    //Future<BuiltList<Event>> listEvents() async
    test('test listEvents', () async {
      // TODO
    });

  });
}
