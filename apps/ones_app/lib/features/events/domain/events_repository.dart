import 'event.dart';

abstract interface class EventsRepository {
  Future<List<Event>> listEvents();

  Future<Event> getEvent(String id);

  Future<EventInviteLink> getInviteLink(String eventId);

  Future<EventInviteLinkPreview> previewInviteLink(String eventId, String sig);

  Future<void> acceptInviteLink(String eventId, String sig);

  Future<EventInviteLink> setInviteLinkEnabled(String eventId, bool enabled);

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

  Future<void> deleteEvent(String eventId);

  Future<EventQrInfo> getEventQr(String eventId);
  Future<EventQrInfo> ensureEventQr(String eventId);
}

class EventInviteLink {
  final String url;
  final bool enabled;

  const EventInviteLink({
    required this.url,
    required this.enabled,
  });
}

class EventInviteLinkPreview {
  final String id;
  final String title;
  final String objective;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final String? coverKey;

  const EventInviteLinkPreview({
    required this.id,
    required this.title,
    required this.objective,
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.coverKey,
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

class EventQrInfo {
  final String urlLarge;
  final String? urlSmall;
  final String urlLatest;
  final String? hash;

  const EventQrInfo({
    required this.urlLarge,
    required this.urlSmall,
    required this.urlLatest,
    required this.hash,
  });
}
