import '../domain/event.dart';
import '../domain/events_repository.dart';

class CreateEventUseCase {
  final EventsRepository repository;

  CreateEventUseCase(this.repository);

  Future<Event> execute(String title) {
    return repository.createEvent(title);
  }
}
