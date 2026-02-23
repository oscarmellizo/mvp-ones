import '../domain/event.dart';
import '../domain/events_repository.dart';

class CreateEventUseCase {
  final EventsRepository repository;

  CreateEventUseCase(this.repository);

  Future<Event> execute(
    String title,
    String objective,
    String location,
    DateTime startAt,
    DateTime endAt,
    String? coverReservationId,
  ) {
    return repository.createEvent(
      title,
      objective,
      location,
      startAt,
      endAt,
      coverReservationId,
    );
  }
}
