import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/events/application/list_events_use_case.dart';
import 'package:ones_app/features/events/domain/event.dart';
import 'package:ones_app/features/events/domain/events_repository.dart';

class _FakeEventsRepository implements EventsRepository {
  final List<Event> events;

  _FakeEventsRepository(this.events);

  @override
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
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Event> getEvent(String id) {
    throw UnimplementedError();
  }

  @override
  Future<EventInviteLink> getInviteLink(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventInviteLinkPreview> previewInviteLink(String eventId, String sig) {
    throw UnimplementedError();
  }

  @override
  Future<void> acceptInviteLink(String eventId, String sig) {
    throw UnimplementedError();
  }

  @override
  Future<EventInviteLink> setInviteLinkEnabled(String eventId, bool enabled) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuest>> listEventGuests(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuest>> listEventGuestsV2(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuest>> inviteEventGuests(
      String eventId, List<String> inviteeEmails) {
    throw UnimplementedError();
  }

  @override
  Future<List<Event>> listEvents() async {
    return events;
  }

  @override
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
  }) {
    throw UnimplementedError();
  }
}

void main() {
  test('ListEventsUseCase returns events from repository', () async {
    final repo = _FakeEventsRepository([
      Event(
        id: '1',
        ownerId: 'u',
        createdAt: DateTime.utc(2025, 1, 1),
        title: 'A',
        objective: 'birthday',
        location: 'Somewhere',
        startAt: DateTime.utc(2025, 1, 1, 18),
        endAt: DateTime.utc(2025, 1, 1, 22),
        coverKey: null,
        allowGuestInvites: true,
      ),
      Event(
        id: '2',
        ownerId: 'u',
        createdAt: DateTime.utc(2025, 1, 2),
        title: 'B',
        objective: 'wedding',
        location: 'Somewhere',
        startAt: DateTime.utc(2025, 1, 2, 18),
        endAt: DateTime.utc(2025, 1, 2, 22),
        coverKey: null,
        allowGuestInvites: true,
      ),
    ]);

    final useCase = ListEventsUseCase(repo);
    final result = await useCase.execute();

    expect(result.length, 2);
    expect(result.first.title, 'A');
  });
}
