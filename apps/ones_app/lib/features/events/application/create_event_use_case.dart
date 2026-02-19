import '../domain/event.dart';
import '../domain/events_repository.dart';

class CreateEventUseCase {
  final EventsRepository repository;

  CreateEventUseCase(this.repository);

  Future<Event> execute(
    String title,
    String eventTypeId,
    String location,
    DateTime startAt,
    DateTime endAt,
  ) {
    return repository.createEvent(title, eventTypeId, location, startAt, endAt);
  }
}
