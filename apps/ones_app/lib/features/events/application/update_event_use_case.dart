import '../domain/event.dart';
import '../domain/events_repository.dart';

class UpdateEventUseCase {
  final EventsRepository repository;

  UpdateEventUseCase(this.repository);

  Future<Event> execute({
    required String eventId,
    required String title,
    required String objective,
    required String location,
    required DateTime startAt,
    required DateTime endAt,
    required bool allowGuestInvites,
    required List<String> frameIds,
    String? coverReservationId,
  }) {
    return repository.updateEvent(
      eventId: eventId,
      title: title,
      objective: objective,
      location: location,
      startAt: startAt,
      endAt: endAt,
      allowGuestInvites: allowGuestInvites,
      frameIds: frameIds,
      coverReservationId: coverReservationId,
    );
  }
}
