import 'event.dart';

abstract interface class EventsRepository {
  Future<List<Event>> listEvents();

  Future<Event> getEvent(String id);

  Future<Event> createEvent(String title);
}
