import 'event.dart';

abstract interface class EventsRepository {
  Future<List<Event>> listEvents();

  Future<Event> getEvent(String id);

  Future<List<EventGuest>> listEventGuests(String eventId);

  Future<List<EventGuest>> listEventGuestsV2(String eventId);

  Future<List<EventGuest>> inviteEventGuests(
      String eventId, List<String> inviteeEmails);

  Future<Event> createEvent(
    String title,
    String objective,
    String location,
    DateTime startAt,
    DateTime endAt,
    String? coverReservationId,
    List<String> inviteeEmails,
    bool allowGuestInvites,
    List<String> frameIds,
  );

  Future<Event> updateEvent({
    required String eventId,
    required String title,
    required String objective,
    required String location,
    required DateTime startAt,
    required DateTime endAt,
    required bool allowGuestInvites,
    required List<String> frameIds,
    String? coverReservationId,
  });
}

class EventGuest {
  final String? userId;
  final String? email;
  final String? displayName;
  final String role;
  final String status;

  const EventGuest({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
  });
}
