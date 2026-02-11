import '../domain/event.dart';
import '../domain/events_repository.dart';

class ListEventsUseCase {
  final EventsRepository repository;

  ListEventsUseCase(this.repository);

  Future<List<Event>> execute() {
    return repository.listEvents();
  }
}
