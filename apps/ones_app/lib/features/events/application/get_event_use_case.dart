import '../domain/event.dart';
import '../domain/events_repository.dart';

class GetEventUseCase {
  final EventsRepository repository;

  GetEventUseCase(this.repository);

  Future<Event> execute(String id) {
    return repository.getEvent(id);
  }
}
